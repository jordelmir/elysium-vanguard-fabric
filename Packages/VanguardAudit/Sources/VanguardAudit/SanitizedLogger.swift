import Foundation
import os

public struct SanitizedLogger {
    private static let logger = Logger(subsystem: "ElysiumVanguard", category: "Sanitized")
    private static let sensitivePatterns: [String] = [
        "[A-Za-z0-9+/]{40,}={0,2}",
        "eyJ[A-Za-z0-9_-]+\\.eyJ[A-Za-z0-9_-]+",
        "sk-[A-Za-z0-9]{32,}",
        "password[\"':\\s]*[=:]\\s*[\"']?[^\\s\"']{4,}",
        "token[\"':\\s]*[=:]\\s*[\"']?[^\\s\"']{4,}",
        "key[\"':\\s]*[=:]\\s*[\"']?[^\\s\"']{4,}",
        "secret[\"':\\s]*[=:]\\s*[\"']?[^\\s\"']{4,}",
        "private[\"':\\s]*[=:]\\s*[\"']?[^\\s\"']{4,}",
    ]

    public static func info(_ message: String, category: String = "General") {
        logger.info("[\(category)] \(sanitize(message))")
    }

    public static func warning(_ message: String, category: String = "General") {
        logger.warning("[\(category)] \(sanitize(message))")
    }

    public static func error(_ message: String, category: String = "General") {
        logger.error("[\(category)] \(sanitize(message))")
    }

    public static func debug(_ message: String, category: String = "General") {
        logger.debug("[\(category)] \(sanitize(message))")
    }

    public static func sanitize(_ input: String) -> String {
        var result = input
        for pattern in sensitivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "[REDACTED]")
            }
        }
        result = result.replacingOccurrences(of: "-----BEGIN .* KEY-----", with: "[REDACTED KEY]", options: .regularExpression)
        result = result.replacingOccurrences(of: "-----END .* KEY-----", with: "[REDACTED KEY]", options: .regularExpression)
        return result
    }
}
