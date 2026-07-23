import Foundation

// MARK: - Discovery Errors

public enum DiscoveryError: Error, Sendable, Equatable, LocalizedError {
    case serviceBrowserFailed(reason: String)
    case advertisementMalformed
    case nodeExpired(nodeID: NodeID)
    case alreadyDiscovering
    case notDiscovering

    public var errorDescription: String? {
        switch self {
        case .serviceBrowserFailed(let reason): return "Service browser failed: \(reason)"
        case .advertisementMalformed: return "Node advertisement is malformed"
        case .nodeExpired(let id): return "Node \(id.rawValue.uuidString) expired"
        case .alreadyDiscovering: return "Discovery is already active"
        case .notDiscovering: return "Discovery is not active"
        }
    }
}

// MARK: - Pairing Errors

public enum PairingError: Error, Sendable, Equatable, LocalizedError {
    case challengeExpired
    case maxAttemptsExceeded
    case invalidCode
    case peerAlreadyPaired
    case peerNotFound
    case keyExchangeFailed
    case signatureVerificationFailed
    case keychainFailure(reason: String)

    public var errorDescription: String? {
        switch self {
        case .challengeExpired: return "Pairing challenge has expired"
        case .maxAttemptsExceeded: return "Maximum pairing attempts exceeded"
        case .invalidCode: return "Invalid pairing code"
        case .peerAlreadyPaired: return "Peer is already paired"
        case .peerNotFound: return "Peer not found"
        case .keyExchangeFailed: return "Key exchange failed"
        case .signatureVerificationFailed: return "Signature verification failed"
        case .keychainFailure(let reason): return "Keychain error: \(reason)"
        }
    }
}

// MARK: - Authentication Errors

public enum AuthenticationError: Error, Sendable, Equatable, LocalizedError {
    case peerUnknown
    case peerRevoked
    case certificateMismatch
    case signatureInvalid
    case transcriptMismatch
    case keychainFailure(reason: String)

    public var errorDescription: String? {
        switch self {
        case .peerUnknown: return "Unknown peer"
        case .peerRevoked: return "Peer trust has been revoked"
        case .certificateMismatch: return "Certificate does not match"
        case .signatureInvalid: return "Invalid signature"
        case .transcriptMismatch: return "Transcript verification failed"
        case .keychainFailure(let reason): return "Keychain error: \(reason)"
        }
    }
}

// MARK: - Transport Errors

public enum TransportError: Error, Sendable, Equatable, LocalizedError {
    case connectionRefused
    case connectionReset
    case connectFailed
    case notConnected
    case tlsFailure(reason: String)
    case messageTooLarge(size: Int, limit: Int)
    case encodingFailed(reason: String)
    case decodingFailed(reason: String)
    case sendFailed(reason: String)
    case receiveFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .connectionRefused: return "Connection refused"
        case .connectionReset: return "Connection reset"
        case .connectFailed: return "Connection failed"
        case .notConnected: return "Not connected"
        case .tlsFailure(let reason): return "TLS error: \(reason)"
        case .messageTooLarge(let size, let limit): return "Message size \(size) exceeds limit \(limit)"
        case .encodingFailed(let reason): return "Encoding failed: \(reason)"
        case .decodingFailed(let reason): return "Decoding failed: \(reason)"
        case .sendFailed(let reason): return "Send failed: \(reason)"
        case .receiveFailed(let reason): return "Receive failed: \(reason)"
        }
    }
}

// MARK: - Protocol Errors

public enum ProtocolError: Error, Sendable, Equatable, LocalizedError {
    case invalidMagic
    case unsupportedVersion(major: UInt16)
    case unknownMessageType(rawValue: UInt16)
    case payloadTooLarge(length: UInt32, limit: UInt32)
    case invalidPayload(reason: String)
    case sequenceGap(expected: UInt64, received: UInt64)
    case duplicateOperation(OperationID)

    public var errorDescription: String? {
        switch self {
        case .invalidMagic: return "Invalid protocol magic"
        case .unsupportedVersion(let major): return "Unsupported protocol version: \(major)"
        case .unknownMessageType(let raw): return "Unknown message type: \(raw)"
        case .payloadTooLarge(let len, let lim): return "Payload \(len) exceeds limit \(lim)"
        case .invalidPayload(let reason): return "Invalid payload: \(reason)"
        case .sequenceGap(let exp, let rec): return "Sequence gap: expected \(exp), received \(rec)"
        case .duplicateOperation(let id): return "Duplicate operation: \(id.rawValue.uuidString)"
        }
    }
}

// MARK: - Capture Errors

public enum CaptureError: Error, Sendable, Equatable, LocalizedError {
    case permissionDenied
    case noDisplayAvailable
    case streamInitializationFailed(reason: String)
    case streamStoppedUnexpectedly(reason: String)
    case unsupportedOperatingSystem

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Screen capture permission denied"
        case .noDisplayAvailable: return "No display available for capture"
        case .streamInitializationFailed(let reason): return "Stream init failed: \(reason)"
        case .streamStoppedUnexpectedly(let reason): return "Stream stopped: \(reason)"
        case .unsupportedOperatingSystem: return "Screen capture not supported on this OS"
        }
    }
}

// MARK: - Encoder Errors

public enum EncoderError: Error, Sendable, Equatable, LocalizedError {
    case encoderSessionCreationFailed
    case encodingFailed(status: OSStatus)
    case invalidPixelBuffer
    case unsupportedConfiguration

    public var errorDescription: String? {
        switch self {
        case .encoderSessionCreationFailed: return "Failed to create encoder session"
        case .encodingFailed(let status): return "Encoding failed with status: \(status)"
        case .invalidPixelBuffer: return "Invalid pixel buffer"
        case .unsupportedConfiguration: return "Unsupported encoder configuration"
        }
    }
}

// MARK: - Decoder Errors

public enum DecoderError: Error, Sendable, Equatable, LocalizedError {
    case decoderSessionCreationFailed
    case decodingFailed(status: OSStatus)
    case invalidFrameData
    case keyframeRequired

    public var errorDescription: String? {
        switch self {
        case .decoderSessionCreationFailed: return "Failed to create decoder session"
        case .decodingFailed(let status): return "Decoding failed with status: \(status)"
        case .invalidFrameData: return "Invalid frame data"
        case .keyframeRequired: return "Keyframe required to recover"
        }
    }
}

// MARK: - Input Errors

public enum InputError: Error, Sendable, Equatable, LocalizedError {
    case accessibilityPermissionDenied
    case invalidCoordinates(x: Double, y: Double)
    case invalidKeyCode(UInt16)
    case rateLimited
    case eventQueueFull

    public var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied: return "Accessibility permission denied"
        case .invalidCoordinates(let x, let y): return "Invalid coordinates: (\(x), \(y))"
        case .invalidKeyCode(let code): return "Invalid key code: \(code)"
        case .rateLimited: return "Input rate limited"
        case .eventQueueFull: return "Event queue is full"
        }
    }
}

// MARK: - Terminal Errors

public enum TerminalError: Error, Sendable, Equatable, LocalizedError {
    case ptyAllocationFailed
    case processSpawnFailed(reason: String)
    case sessionNotFound(TerminalSessionID)
    case writeFailed(reason: String)
    case resizeFailed(reason: String)
    case shellNotFound

    public var errorDescription: String? {
        switch self {
        case .ptyAllocationFailed: return "PTY allocation failed"
        case .processSpawnFailed(let reason): return "Process spawn failed: \(reason)"
        case .sessionNotFound(let id): return "Terminal session not found: \(id.rawValue.uuidString)"
        case .writeFailed(let reason): return "Write failed: \(reason)"
        case .resizeFailed(let reason): return "Resize failed: \(reason)"
        case .shellNotFound: return "Default shell not found"
        }
    }
}

// MARK: - Telemetry Errors

public enum TelemetryError: Error, Sendable, Equatable, LocalizedError {
    case collectionFailed(reason: String)
    case serializationFailed

    public var errorDescription: String? {
        switch self {
        case .collectionFailed(let reason): return "Telemetry collection failed: \(reason)"
        case .serializationFailed: return "Telemetry serialization failed"
        }
    }
}

// MARK: - Persistence Errors

public enum PersistenceError: Error, Sendable, Equatable, LocalizedError {
    case databaseOpenFailed(reason: String)
    case migrationFailed(version: Int)
    case queryFailed(reason: String)
    case notFound

    public var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let reason): return "Database open failed: \(reason)"
        case .migrationFailed(let ver): return "Migration to version \(ver) failed"
        case .queryFailed(let reason): return "Query failed: \(reason)"
        case .notFound: return "Record not found"
        }
    }
}

// MARK: - Authorization Errors

public enum AuthorizationError: Error, Sendable, Equatable, LocalizedError {
    case capabilityRequired(NodeCapability)
    case sessionInvalid
    case actionForbidden(String)
    case confirmationRequired

    public var errorDescription: String? {
        switch self {
        case .capabilityRequired(let cap): return "Capability required: \(cap.displayName)"
        case .sessionInvalid: return "Session is invalid"
        case .actionForbidden(let action): return "Action forbidden: \(action)"
        case .confirmationRequired: return "Local confirmation required"
        }
    }
}
