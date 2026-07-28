import XCTest
@testable import VanguardDomain
import VanguardTestSupport

final class PlatformTests: XCTestCase {
    func testCPUArchitectureDisplayNames() {
        XCTAssertEqual(CPUArchitecture.arm64.displayName, "Apple Silicon (arm64)")
        XCTAssertEqual(CPUArchitecture.x86_64.displayName, "Intel (x86_64)")
        XCTAssertEqual(CPUArchitecture.arm64e.displayName, "Apple Silicon Enhanced (arm64e)")
        XCTAssertEqual(CPUArchitecture.unknown.displayName, "Unknown")
    }

    func testOSFamilyDisplayNames() {
        XCTAssertEqual(OSFamily.macOS.displayName, "macOS")
        XCTAssertEqual(OSFamily.linux.displayName, "Linux")
        XCTAssertEqual(OSFamily.windows.displayName, "Windows")
        XCTAssertEqual(OSFamily.android.displayName, "Android")
    }

    func testOperatingSystemDescriptor() {
        let os = OperatingSystemDescriptor(family: .macOS, version: "14.0", build: "23A344")
        XCTAssertEqual(os.displayName, "macOS 14.0")
    }

    func testProtocolVersionComparison() {
        let v1 = ProtocolVersion(major: 1, minor: 0)
        let v2 = ProtocolVersion(major: 2, minor: 0)
        let v1_1 = ProtocolVersion(major: 1, minor: 1)
        XCTAssertTrue(v1 < v2)
        XCTAssertTrue(v1 < v1_1)
        XCTAssertFalse(v2 < v1)
    }

    func testNodeCapabilityAllCases() {
        XCTAssertEqual(NodeCapability.allCases.count, 12)
    }

    func testNodeCapabilityDisplayNames() {
        XCTAssertEqual(NodeCapability.screenView.displayName, "Screen View")
        XCTAssertEqual(NodeCapability.terminalOpen.displayName, "Terminal Open")
        XCTAssertEqual(NodeCapability.nodeShutdown.displayName, "Node Shutdown")
    }

    func testTrustStateCodable() throws {
        let state = TrustState.trusted
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(TrustState.self, from: data)
        XCTAssertEqual(state, decoded)
    }

    func testSessionIdentity() {
        let id = SessionIdentity(sessionID: SessionID(), nodeID: NodeID())
        XCTAssertTrue(id.isValid)
        let expired = SessionIdentity(sessionID: SessionID(), nodeID: NodeID(), createdAt: Date().addingTimeInterval(-7200), expiresAt: Date().addingTimeInterval(-3600))
        XCTAssertFalse(expired.isValid)
    }

    func testJobIdentity() {
        let id = JobIdentity(jobID: JobID(), ownerNodeID: NodeID(), signedBy: NodeID())
        XCTAssertEqual(id.ownerNodeID, id.ownerNodeID)
        XCTAssertNil(id.executorNodeID)
    }

    func testArtifactIdentityCodable() throws {
        let id = ArtifactIdentity(producerNodeID: NodeID(), sha256: Data(repeating: 0xAA, count: 32), sizeBytes: 1024)
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(ArtifactIdentity.self, from: data)
        XCTAssertEqual(id.artifactID, decoded.artifactID)
        XCTAssertEqual(id.sizeBytes, decoded.sizeBytes)
    }

    func testAgentIdentity() {
        let id = AgentIdentity(ownerNodeID: NodeID(), agentType: "planner", riskLevel: .low, authorizedActions: ["inspectRepository", "readFile"])
        XCTAssertEqual(id.authorizedActions.count, 2)
        XCTAssertEqual(id.agentType, "planner")
    }

    func testApplicationIdentity() {
        let id = ApplicationIdentity(appBundleID: "com.test.app", appVersion: "1.0", signedBy: NodeID(), capabilities: [.screenView, .terminalOpen])
        XCTAssertEqual(id.appBundleID, "com.test.app")
        XCTAssertEqual(id.capabilities.count, 2)
    }

    func testJobIDRawRepresentable() {
        let jid = JobID()
        let same = JobID(rawValue: jid.rawValue)
        XCTAssertEqual(jid, same)
    }

    func testJobIDCodable() throws {
        let jid = JobID()
        let data = try JSONEncoder().encode(jid)
        let decoded = try JSONDecoder().decode(JobID.self, from: data)
        XCTAssertEqual(jid, decoded)
    }
}
