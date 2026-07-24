import XCTest
import Foundation
import CoreVideo
@testable import VanguardSession
@testable import VanguardDomain
@testable import VanguardProtocol
@testable import VanguardTransport
@testable import VanguardDiscovery
@testable import VanguardIdentity
@testable import VanguardPermissions
@testable import VanguardCapture
@testable import VanguardVideo
@testable import VanguardInput
@testable import VanguardTerminal

@available(macOS 12.3, *)
final class SessionCoordinatorTests: XCTestCase {
    func testNodeStateTransitions() async {
        let discoveryService = BonjourDiscoveryService()
        let transport = InMemoryTransport()
        let identityService = MockIdentityService()
        let permissionService = MockPermissionService()
        let captureService = MockCaptureService()
        let encoderService = MockEncoderService()
        let inputService = MockInputService()
        let terminalService = MockTerminalService()

        let coordinator = NodeSessionCoordinator(
            discoveryService: discoveryService,
            transport: transport,
            identityService: identityService,
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

        try? await Task.sleep(nanoseconds: 50_000_000)
        try? await coordinator.start()
        try? await Task.sleep(nanoseconds: 300_000_000)
        task.cancel()

        let states = collector.states
        XCTAssertFalse(states.isEmpty, "Expected at least one state, got: \(states)")
        XCTAssertEqual(states.first, .advertising)
    }

    func testConsoleStateTransitions() async {
        let discoveryService = BonjourDiscoveryService()
        let transport = InMemoryTransport()
        let identityService = MockIdentityService()
        let permissionService = MockPermissionService()
        let terminalService = MockTerminalService()
        let decoderService = MockDecoderService()

        let coordinator = ConsoleSessionCoordinator(
            discoveryService: discoveryService,
            transport: transport,
            identityService: identityService,
            permissionService: permissionService,
            terminalService: terminalService,
            decoderService: decoderService
        )

        let collector = StateCollector<ConsoleSessionCoordinator.ConsoleState>()

        let task = Task {
            for await state in await coordinator.stateUpdates {
                collector.add(state)
            }
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        try? await coordinator.startScan()
        try? await Task.sleep(nanoseconds: 300_000_000)
        task.cancel()

        let states = collector.states
        XCTAssertFalse(states.isEmpty, "Expected at least one state, got: \(states)")
        XCTAssertEqual(states.first, .scanning)
    }

    func testNodeStop() async {
        let discoveryService = BonjourDiscoveryService()
        let transport = InMemoryTransport()
        let identityService = MockIdentityService()
        let permissionService = MockPermissionService()
        let captureService = MockCaptureService()
        let encoderService = MockEncoderService()
        let inputService = MockInputService()
        let terminalService = MockTerminalService()

        let coordinator = NodeSessionCoordinator(
            discoveryService: discoveryService,
            transport: transport,
            identityService: identityService,
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

        try? await Task.sleep(nanoseconds: 50_000_000)
        try? await coordinator.start()
        try? await Task.sleep(nanoseconds: 300_000_000)
        await coordinator.stop()
        try? await Task.sleep(nanoseconds: 300_000_000)
        task.cancel()

        let states = collector.states
        XCTAssertEqual(states.last, .idle)
    }
}

// MARK: - State Collector (thread-safe)

private final class StateCollector<T>: @unchecked Sendable {
    private(set) var states: [T] = []
    private let lock = NSLock()

    func add(_ state: T) {
        lock.withLock {
            states.append(state)
        }
    }
}

// MARK: - Mock Services

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

private final class MockPermissionService: PermissionService, @unchecked Sendable {
    func checkAllPermissions() async -> [PermissionDescriptor] { [] }
    func checkPermission(kind: PermissionKind) async -> PermissionState { .granted }
    func requestPermission(kind: PermissionKind) async -> PermissionState { .granted }
    func openSystemSettings(for kind: PermissionKind) async {}
}

private final class MockCaptureService: ScreenCaptureService, @unchecked Sendable {
    var stateUpdates: AsyncStream<CaptureState> { AsyncStream { $0.yield(.idle) } }
    func availableSources() async throws -> [CaptureSource] { [] }
    func startCapture(source: CaptureSource, configuration: CaptureConfiguration) async throws -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func stopCapture() async {}
}

private final class MockEncoderService: VideoEncoderService, @unchecked Sendable {
    func configure(width: Int, height: Int, fps: Int, bitrate: Int) async throws {}
    func encodeFrame(_ frame: Data, width: Int, height: Int) async throws -> EncodedVideoFrame {
        EncodedVideoFrame(frameID: 0, presentationTimestampNanos: 0, isKeyframe: true, codecConfigurationRevision: 1, payload: Data())
    }
    func requestKeyframe() async {}
    func reset() async {}
}

private final class MockInputService: InputDispatchService, @unchecked Sendable {
    func dispatch(_ event: RemoteInputEvent) async throws {}
    func releaseAllKeys() async {}
    func isAccessibilityAuthorized() async -> Bool { true }
    func requestAccessibility() async -> Bool { true }
}

private final class MockTerminalService: TerminalService, @unchecked Sendable {
    func open(configuration: TerminalConfiguration) async throws -> TerminalSessionHandle {
        TerminalSessionHandle(sessionID: TerminalSessionID(), pid: 1234, state: .open)
    }
    func write(sessionID: TerminalSessionID, data: Data) async throws {}
    func resize(sessionID: TerminalSessionID, columns: UInt16, rows: UInt16) async throws {}
    func close(sessionID: TerminalSessionID, signal: TerminalCloseSignal) async {}
    func getOutput(sessionID: TerminalSessionID, fromOffset: UInt64) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private final class MockDecoderService: VideoDecoderService, @unchecked Sendable {
    func configure(codecConfiguration: Data) async throws {}
    func decodeFrame(_ frame: EncodedVideoFrame) async throws -> DecodedVideoFrame {
        DecodedVideoFrame(frameID: frame.frameID, width: 1920, height: 1080)
    }
    func getLastDecodedPixelBuffer() async -> CVPixelBuffer? { nil }
    func reset() async {}
}
