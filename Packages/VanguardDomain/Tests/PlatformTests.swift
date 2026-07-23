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
}
