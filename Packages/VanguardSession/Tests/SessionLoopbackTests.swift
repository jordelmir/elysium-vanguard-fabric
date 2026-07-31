import XCTest
import Foundation
import CoreVideo
@testable import VanguardSession
@testable import VanguardDomain
@testable import VanguardProtocol
@testable import VanguardTransport
@testable import VanguardDiscovery
@testable import VanguardIdentity
@testable import VanguardCapture
@testable import VanguardVideo
@testable import VanguardInput
@testable import VanguardTerminal
@testable import VanguardPermissions

@available(macOS 12.3, *)
final class SessionLoopbackTests: XCTestCase {

    func testNodeStartAndStopsCleanly() async throws {
        let transport = InMemoryTransport()
        let identity = MockIdentityService()
        let permissionService = MockPermissionService()
        let captureService = MockCaptureService()
        let encoderService = MockEncoderService()
        let inputService = MockInputService()
        let terminalService = MockTerminalService()

        let coordinator = NodeSessionCoordinator(
            discoveryService: MockDiscoveryService(),
            transport: transport,
            identityService: identity,
            permissionService: permissionService,
            captureService: captureService,
            encoderService: encoderService,
            inputService: inputService,
            terminalService: terminalService
        )

        let collector = StateCollector<NodeSessionCoordinator.NodeState>()
        let task = Task {
            for await state in await coordinator.stateUpdates {
                collector.add(state)
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        try await coordinator.start()
        try await Task.sleep(nanoseconds: 500_000_000)
        task.cancel()
        try await Task.sleep(nanoseconds: 200_000_000)

        let states = collector.states
        XCTAssertTrue(states.contains(.advertising), "Node should reach advertising state, got: \(states)")
    }

    func testNodeHandlesHelloAndSendsChallenge() async throws {
        let transport = InMemoryTransport()
        let identity = MockIdentityService()
        let permissionService = MockPermissionService()
        let captureService = MockCaptureService()
        let encoderService = MockEncoderService()
        let inputService = MockInputService()
        let terminalService = MockTerminalService()

        let coordinator = NodeSessionCoordinator(
            discoveryService: MockDiscoveryService(),
            transport: transport,
            identityService: identity,
            permissionService: permissionService,
            captureService: captureService,
            encoderService: encoderService,
            inputService: inputService,
            terminalService: terminalService
        )

        let collector = StateCollector<String>()
        let task = Task {
            for await state in await coordinator.stateUpdates {
                if case .pairing(let code) = state {
                    collector.add(code)
                }
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        try await coordinator.start()
        try await Task.sleep(nanoseconds: 500_000_000)

        let consoleIdentity = try await MockIdentityService().getOrCreateIdentity()
        let helloPayload = HelloPayload(
            protocolVersion: .v1,
            nodeID: consoleIdentity.nodeID,
            displayName: "TestConsole",
            architecture: .arm64,
            osFamily: .macOS,
            osVersion: "14.0"
        )
        let data = try JSONEncoder().encode(helloPayload)
        let helloMsg = InboundMessage(
            header: ProtocolHeader(messageType: .hello, streamChannel: .control),
            payload: data
        )
        transport.simulateIncoming(helloMsg)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        task.cancel()

        let codes = collector.states
        XCTAssertFalse(codes.isEmpty, "Node should emit a pairing code")
        XCTAssertFalse(codes[0].isEmpty, "Pairing code should not be empty")

        let sentMessages = await transport.getSentMessages()
        let hasHelloAck = sentMessages.contains { $0.messageType == .helloAck }
        let hasPairingRequest = sentMessages.contains { $0.messageType == .pairingRequest }
        XCTAssertTrue(hasHelloAck, "Node should send helloAck")
        XCTAssertTrue(hasPairingRequest, "Node should send pairingRequest with challenge")
    }

    func testPairingCodeValidationTransitionsToCodeValidated() async throws {
        let transport = InMemoryTransport()
        let identity = MockIdentityService()
        let permissionService = MockPermissionService()
        let captureService = MockCaptureService()
        let encoderService = MockEncoderService()
        let inputService = MockInputService()
        let terminalService = MockTerminalService()

        let coordinator = NodeSessionCoordinator(
            discoveryService: MockDiscoveryService(),
            transport: transport,
            identityService: identity,
            permissionService: permissionService,
            captureService: captureService,
            encoderService: encoderService,
            inputService: inputService,
            terminalService: terminalService
        )

        let stateCollector = StateCollector<NodeSessionCoordinator.NodeState>()
        let stateTask = Task {
            for await state in await coordinator.stateUpdates {
                stateCollector.add(state)
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        try await coordinator.start()
        try await Task.sleep(nanoseconds: 500_000_000)

        let consoleIdentity = try await MockIdentityService().getOrCreateIdentity()

        let helloPayload = HelloPayload(
            protocolVersion: .v1,
            nodeID: consoleIdentity.nodeID,
            displayName: "TestConsole",
            architecture: .arm64,
            osFamily: .macOS,
            osVersion: "14.0"
        )
        let helloData = try JSONEncoder().encode(helloPayload)
        transport.simulateIncoming(InboundMessage(
            header: ProtocolHeader(messageType: .hello, streamChannel: .control),
            payload: helloData
        ))

        try await Task.sleep(nanoseconds: 1_000_000_000)

        let allStates = stateCollector.states
        let pairingStates = allStates.compactMap { state -> String? in
            if case .pairing(let code) = state { return code }
            return nil
        }
        guard let code = pairingStates.first else {
            XCTFail("No pairing code received, states: \(allStates)")
            stateTask.cancel()
            return
        }

        let responsePayload = PairingResponsePayload(
            consoleID: consoleIdentity.nodeID,
            challengeCode: code,
            signingPublicKey: consoleIdentity.signingPublicKey,
            agreementPublicKey: consoleIdentity.agreementPublicKey,
            transcriptHash: Data()
        )
        let responseData = try JSONEncoder().encode(responsePayload)
        transport.simulateIncoming(InboundMessage(
            header: ProtocolHeader(messageType: .pairingResponse, streamChannel: .control),
            payload: responseData
        ))

        try await Task.sleep(nanoseconds: 1_000_000_000)
        stateTask.cancel()

        let finalStates = stateCollector.states
        let gotCodeValidated = finalStates.contains { if case .codeValidated = $0 { return true }; return false }
        XCTAssertTrue(gotCodeValidated, "Pairing should transition to codeValidated, got: \(finalStates)")
    }

    func testWrongPairingCodeProducesError() async throws {
        let transport = InMemoryTransport()
        let identity = MockIdentityService()
        let permissionService = MockPermissionService()
        let captureService = MockCaptureService()
        let encoderService = MockEncoderService()
        let inputService = MockInputService()
        let terminalService = MockTerminalService()

        let coordinator = NodeSessionCoordinator(
            discoveryService: MockDiscoveryService(),
            transport: transport,
            identityService: identity,
            permissionService: permissionService,
            captureService: captureService,
            encoderService: encoderService,
            inputService: inputService,
            terminalService: terminalService
        )

        nonisolated(unsafe) var gotError = false
        let task = Task { @Sendable in
            for await state in await coordinator.stateUpdates {
                if case .error = state {
                    gotError = true
                    break
                }
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        try await coordinator.start()
        try await Task.sleep(nanoseconds: 500_000_000)

        let consoleIdentity = try await MockIdentityService().getOrCreateIdentity()
        let helloPayload = HelloPayload(
            protocolVersion: .v1,
            nodeID: consoleIdentity.nodeID,
            displayName: "TestConsole",
            architecture: .arm64,
            osFamily: .macOS,
            osVersion: "14.0"
        )
        let helloData = try JSONEncoder().encode(helloPayload)
        transport.simulateIncoming(InboundMessage(
            header: ProtocolHeader(messageType: .hello, streamChannel: .control),
            payload: helloData
        ))
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let wrongResponse = PairingResponsePayload(
            consoleID: consoleIdentity.nodeID,
            challengeCode: "WRONG0",
            signingPublicKey: consoleIdentity.signingPublicKey,
            agreementPublicKey: consoleIdentity.agreementPublicKey,
            transcriptHash: Data()
        )
        let wrongData = try JSONEncoder().encode(wrongResponse)
        transport.simulateIncoming(InboundMessage(
            header: ProtocolHeader(messageType: .pairingResponse, streamChannel: .control),
            payload: wrongData
        ))

        try await Task.sleep(nanoseconds: 1_000_000_000)
        task.cancel()

        XCTAssertTrue(gotError, "Wrong code should produce error state")
    }

    func testTerminalSessionIDPassThrough() async throws {
        let service = POSIXTerminalService()
        let sessionID = TerminalSessionID()
        let config = TerminalConfiguration(shell: "/bin/zsh", columns: 80, rows: 24)

        let handle = try await service.open(sessionID: sessionID, configuration: config)
        XCTAssertEqual(handle.sessionID, sessionID, "POSIXTerminalService must use the provided sessionID")
        XCTAssertEqual(handle.state, .open)
        XCTAssertGreaterThan(handle.pid, 0)

        await service.close(sessionID: handle.sessionID, signal: .hangup)
    }
}

private final class StateCollector<T>: @unchecked Sendable {
    private(set) var states: [T] = []
    private let lock = NSLock()

    func add(_ state: T) {
        lock.withLock {
            states.append(state)
        }
    }
}

private final class MockIdentityService: IdentityService, @unchecked Sendable {
    func generateDeviceIdentity() async throws -> DeviceIdentity {
        DeviceIdentity(
            nodeID: NodeID(),
            signingPublicKey: Data(),
            signingPrivateKeyRef: "test",
            agreementPublicKey: Data(),
            agreementPrivateKeyRef: "test",
            certificateFingerprint: Data()
        )
    }

    func getOrCreateIdentity() async throws -> DeviceIdentity {
        try await generateDeviceIdentity()
    }

    func signData(_ data: Data, identity: DeviceIdentity) async throws -> Data { data }
    func verifySignature(_ signature: Data, data: Data, publicKey: Data) async throws -> Bool { true }
    func saveTrustedPeer(_ peer: TrustedPeer) async throws {}
    func loadTrustedPeer(nodeID: NodeID) async throws -> TrustedPeer? { nil }
    func loadAllTrustedPeers() async throws -> [TrustedPeer] { [] }
    func revokePeer(nodeID: NodeID) async throws {}
    func generateChallenge() async throws -> PairingChallenge {
        PairingChallenge(code: "123456", expiresAt: Date().addingTimeInterval(300), fingerprint: Data())
    }
    func validateChallengeCode(_ code: String, challenge: PairingChallenge) async throws -> Bool { true }
}

private final class MockDiscoveryService: DiscoveryService, @unchecked Sendable {
    func startBrowsing() async throws {}
    func stopBrowsing() async {}
    func publishAdvertisement(_ ad: NodeAdvertisement) async throws {}
    func unpublish() async {}
    var stateUpdates: AsyncThrowingStream<DiscoveryState, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private final class MockCaptureService: ScreenCaptureService, @unchecked Sendable {
    var stateUpdates: AsyncStream<CaptureState> { AsyncStream { $0.yield(.idle) } }
    var currentDisplayID: UInt32 { 0 }
    var currentCaptureMode: WindowCaptureMode { .display }
    func availableSources() async throws -> [CaptureSource] { [] }
    func availableWindows() async throws -> [RemoteWindowDescriptor] { [] }
    func availableDisplays() async throws -> [DisplayDescriptor] { [] }
    func startCapture(source: CaptureSource, configuration: CaptureConfiguration) async throws -> AsyncThrowingStream<CapturedVideoFrame, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func startWindowCapture(windowID: UInt32, configuration: CaptureConfiguration) async throws -> AsyncThrowingStream<CapturedVideoFrame, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func switchDisplay(displayID: UInt32, configuration: CaptureConfiguration) async throws -> AsyncThrowingStream<CapturedVideoFrame, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func stopCapture() async {}
}

private final class MockEncoderService: VideoEncoderService, @unchecked Sendable {
    func configure(width: Int, height: Int, fps: Int, bitrate: Int) async throws {}
    func encode(_ frame: CapturedVideoFrame) async throws -> EncodedVideoOutput {
        .accessUnit(EncodedVideoAccessUnit(
            frameID: 0, presentationTimestampNanos: 0, durationNanos: 33_333_333,
            isKeyframe: true, configurationRevision: 1, avccPayload: Data()
        ))
    }
    func requestKeyframe() {}
    func updateBitrate(_ bitrate: Int) async throws {}
    func reset() async {}
}

private final class MockInputService: InputDispatchService, @unchecked Sendable {
    func dispatch(_ event: RemoteInputEvent) async throws {}
    func releaseAllKeys() async {}
    func isAccessibilityAuthorized() async -> Bool { true }
    func requestAccessibility() async -> Bool { true }
    func setCapturedDisplayID(_ displayID: CGDirectDisplayID) {}
    func setPointerContext(_ context: RemotePointerContext) {}
    func setWindowGeometryMapper(_ mapper: WindowGeometryMapper) {}
}

private final class MockTerminalService: TerminalService, @unchecked Sendable {
    func open(sessionID: TerminalSessionID, configuration: TerminalConfiguration) async throws -> TerminalSessionHandle {
        TerminalSessionHandle(sessionID: sessionID, pid: 1234, state: .open)
    }
    func write(sessionID: TerminalSessionID, data: Data) async throws {}
    func resize(sessionID: TerminalSessionID, columns: UInt16, rows: UInt16) async throws {}
    func close(sessionID: TerminalSessionID, signal: TerminalCloseSignal) async {}
    func getOutput(sessionID: TerminalSessionID, fromOffset: UInt64) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private final class MockDecoderService: VideoDecoderService, @unchecked Sendable {
    func configure(sps: Data, pps: Data, width: Int, height: Int) async throws {}
    func decode(_ accessUnit: EncodedVideoAccessUnit) async throws -> DecodedVideoFrame {
        let attrs: [String: Any] = [
            kCVPixelBufferWidthKey as String: 1920,
            kCVPixelBufferHeightKey as String: 1080,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 1920, 1080, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)
        return DecodedVideoFrame(
            frameID: accessUnit.frameID,
            presentationTimestampNanos: accessUnit.presentationTimestampNanos,
            pixelBuffer: pixelBuffer!
        )
    }
    func reset() async {}
}

private final class MockPermissionService: PermissionService, @unchecked Sendable {
    func checkAllPermissions() async -> [PermissionDescriptor] { [] }
    func checkPermission(kind: PermissionKind) async -> PermissionState { .granted }
    func requestPermission(kind: PermissionKind) async -> PermissionState { .granted }
    func openSystemSettings(for kind: PermissionKind) async {}
}

// MARK: - Network Integration Tests

@available(macOS 12.3, *)
extension SessionLoopbackTests {

    func testEmergencyStopMessageType() async throws {
        XCTAssertEqual(MessageType.emergencyStop.rawValue, 0x0060)
    }

    func testClipboardDataPayloadRoundTrip() async throws {
        let payload = ClipboardDataPayload(content: "hello world", changeCount: 42)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ClipboardDataPayload.self, from: data)
        XCTAssertEqual(decoded.content, "hello world")
        XCTAssertEqual(decoded.changeCount, 42)
        XCTAssertEqual(decoded.contentType, "public.utf8-plain-text")
    }

    func testAgentSubmitPayloadRoundTrip() async throws {
        let payload = AgentSubmitPayload(planID: "plan-1", objective: "test plan", steps: ["echo hello", "ls -la"])
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(AgentSubmitPayload.self, from: data)
        XCTAssertEqual(decoded.planID, "plan-1")
        XCTAssertEqual(decoded.objective, "test plan")
        XCTAssertEqual(decoded.steps.count, 2)
        XCTAssertEqual(decoded.steps[0], "echo hello")
    }

    func testAgentProgressAndCompletedPayloads() async throws {
        let progress = AgentProgressPayload(planID: "p1", stepIndex: 0, output: "step done")
        let progressData = try JSONEncoder().encode(progress)
        let decodedProgress = try JSONDecoder().decode(AgentProgressPayload.self, from: progressData)
        XCTAssertEqual(decodedProgress.stepIndex, 0)
        XCTAssertEqual(decodedProgress.output, "step done")

        let completed = AgentCompletedPayload(planID: "p1", outputs: ["out1", "out2"])
        let completedData = try JSONEncoder().encode(completed)
        let decodedCompleted = try JSONDecoder().decode(AgentCompletedPayload.self, from: completedData)
        XCTAssertEqual(decodedCompleted.outputs.count, 2)

        let failed = AgentFailedPayload(planID: "p1", error: "step failed")
        let failedData = try JSONEncoder().encode(failed)
        let decodedFailed = try JSONDecoder().decode(AgentFailedPayload.self, from: failedData)
        XCTAssertEqual(decodedFailed.error, "step failed")
    }

    func testWorkspaceRequestResponsePayloads() async throws {
        let request = WorkspaceRequestPayload(workspaceID: "ws-1")
        let reqData = try JSONEncoder().encode(request)
        let decodedReq = try JSONDecoder().decode(WorkspaceRequestPayload.self, from: reqData)
        XCTAssertEqual(decodedReq.workspaceID, "ws-1")

        let response = WorkspaceResponsePayload(workspaceID: "ws-1", files: ["a.txt": "hash1", "b.txt": "hash2"], stateHash: Data("test".utf8))
        let resData = try JSONEncoder().encode(response)
        let decodedRes = try JSONDecoder().decode(WorkspaceResponsePayload.self, from: resData)
        XCTAssertEqual(decodedRes.files.count, 2)
        XCTAssertEqual(decodedRes.files["a.txt"], "hash1")
    }

    func testJobDispatchPayloadRoundTrip() async throws {
        let submit = JobSubmitPayload(jobID: "job-1", name: "test job", command: ["/bin/echo", "hello"])
        let data = try JSONEncoder().encode(submit)
        let decoded = try JSONDecoder().decode(JobSubmitPayload.self, from: data)
        XCTAssertEqual(decoded.jobID, "job-1")
        XCTAssertEqual(decoded.name, "test job")
        XCTAssertEqual(decoded.command, ["/bin/echo", "hello"])

        let assigned = JobAssignedPayload(jobID: "job-1", nodeID: "node-1")
        let assignedData = try JSONEncoder().encode(assigned)
        let decodedAssigned = try JSONDecoder().decode(JobAssignedPayload.self, from: assignedData)
        XCTAssertEqual(decodedAssigned.nodeID, "node-1")

        let completed = JobCompletedPayload(jobID: "job-1", exitCode: 0, stdout: "hello\n", duration: 0.5)
        let completedData = try JSONEncoder().encode(completed)
        let decodedCompleted = try JSONDecoder().decode(JobCompletedPayload.self, from: completedData)
        XCTAssertEqual(decodedCompleted.exitCode, 0)
        XCTAssertEqual(decodedCompleted.duration, 0.5)

        let jobFailed = JobFailedPayload(jobID: "job-1", error: "not found")
        let failedData = try JSONEncoder().encode(jobFailed)
        let decodedFailed = try JSONDecoder().decode(JobFailedPayload.self, from: failedData)
        XCTAssertEqual(decodedFailed.error, "not found")
    }

    func testAllNewMessageTypesExist() async throws {
        XCTAssertNotNil(MessageType(rawValue: 0x0060))
        XCTAssertNotNil(MessageType(rawValue: 0x0A02))
        XCTAssertNotNil(MessageType(rawValue: 0x0A03))
        XCTAssertNotNil(MessageType(rawValue: 0x0C00))
        XCTAssertNotNil(MessageType(rawValue: 0x0D00))
        XCTAssertNotNil(MessageType(rawValue: 0x0D01))
        XCTAssertNotNil(MessageType(rawValue: 0x0D02))
        XCTAssertNotNil(MessageType(rawValue: 0x0D03))
    }
}
