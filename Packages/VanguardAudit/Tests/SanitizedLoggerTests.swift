import Foundation
import XCTest
@testable import VanguardAudit

final class SanitizedLoggerTests: XCTestCase {
    func testRedactsBase64Strings() {
        let input = "Token: SGVsbG9Xb3JsZFRoaXNTaXh0eUZvdXJUd2VudHlPaG5laXJl"
        let result = SanitizedLogger.sanitize(input)
        XCTAssertFalse(result.contains("SGVsbG9Xb3JsZFRoaXNTaXh0eUZvdXJUd2VudHlPaG5naXJl"))
        XCTAssertTrue(result.contains("[REDACTED]"))
    }

    func testRedactsPasswordPatterns() {
        let input = "password: \"mysecret123\""
        let result = SanitizedLogger.sanitize(input)
        XCTAssertFalse(result.contains("mysecret123"))
        XCTAssertTrue(result.contains("[REDACTED]"))
    }

    func testRedactsTokenPatterns() {
        let input = "token=\"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U\""
        let result = SanitizedLogger.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED]"))
    }

    func testRedactsPrivateKeyHeaders() {
        let input = "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA..."
        let result = SanitizedLogger.sanitize(input)
        XCTAssertTrue(result.contains("[REDACTED KEY]"))
        XCTAssertFalse(result.contains("PRIVATE KEY"))
    }

    func testLeavesNormalTextUntouched() {
        let input = "Node connected successfully at 10.0.0.1"
        let result = SanitizedLogger.sanitize(input)
        XCTAssertEqual(result, input)
    }
}
