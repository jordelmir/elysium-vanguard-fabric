import XCTest
@testable import VanguardDomain
import VanguardTestSupport

final class ErrorsTests: XCTestCase {
    func testDiscoveryErrorDescriptions() {
        let error = DiscoveryError.serviceBrowserFailed(reason: "test")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("test"))
    }

    func testPairingErrorDescriptions() {
        XCTAssertNotNil(PairingError.challengeExpired.errorDescription)
        XCTAssertNotNil(PairingError.maxAttemptsExceeded.errorDescription)
        XCTAssertNotNil(PairingError.invalidCode.errorDescription)
    }

    func testTransportErrorDescriptions() {
        XCTAssertNotNil(TransportError.connectionRefused.errorDescription)
        XCTAssertNotNil(TransportError.messageTooLarge(size: 1000, limit: 500).errorDescription)
    }

    func testProtocolErrorDescriptions() {
        XCTAssertNotNil(ProtocolError.invalidMagic.errorDescription)
        XCTAssertNotNil(ProtocolError.unsupportedVersion(major: 99).errorDescription)
        XCTAssertNotNil(ProtocolError.unknownMessageType(rawValue: 0xFFFF).errorDescription)
    }

    func testCaptureErrorDescriptions() {
        XCTAssertNotNil(CaptureError.permissionDenied.errorDescription)
        XCTAssertNotNil(CaptureError.noDisplayAvailable.errorDescription)
    }

    func testTerminalErrorDescriptions() {
        XCTAssertNotNil(TerminalError.ptyAllocationFailed.errorDescription)
        XCTAssertNotNil(TerminalError.shellNotFound.errorDescription)
    }

    func testAuthorizationErrorDescriptions() {
        XCTAssertNotNil(AuthorizationError.capabilityRequired(.screenView).errorDescription)
        XCTAssertNotNil(AuthorizationError.sessionInvalid.errorDescription)
    }
}
