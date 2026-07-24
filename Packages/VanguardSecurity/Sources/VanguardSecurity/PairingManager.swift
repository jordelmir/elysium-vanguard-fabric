import Foundation
import CryptoKit
import VanguardDomain
import VanguardIdentity

public actor PairingManager {
    private let identityService: any IdentityService
    private var currentState: PairingState = .idle
    private var currentChallenge: PairingChallenge?
    private var attemptCount: Int = 0
    private var cooldownExpiry: Date?
    private var transcriptMessages: [Data] = []

    public init(identityService: any IdentityService) {
        self.identityService = identityService
    }

    public var state: PairingState {
        currentState
    }

    public func generateCode() async throws -> PairingChallenge {
        if let cooldown = cooldownExpiry, Date() < cooldown {
            currentState = .cooldown(expiresAt: cooldown)
            throw PairingError.cooldownActive(expiresAt: cooldown)
        }

        let challenge = try await identityService.generateChallenge()
        currentChallenge = challenge
        attemptCount = 0
        transcriptMessages = []
        currentState = .codeGenerated(code: challenge.code, expiresAt: challenge.expiresAt, attemptCount: 0)
        return challenge
    }

    public func submitCode(_ code: String) async throws -> Bool {
        guard let challenge = currentChallenge else {
            throw PairingError.invalidState
        }

        guard Date() < challenge.expiresAt else {
            currentState = .failed(reason: .expired)
            throw PairingError.expired
        }

        guard attemptCount < challenge.maxAttempts else {
            let cooldown = computeCooldown(attempt: attemptCount)
            cooldownExpiry = Date().addingTimeInterval(cooldown)
            currentState = .failed(reason: .maxAttemptsExceeded)
            throw PairingError.maxAttemptsExceeded
        }

        attemptCount += 1

        if code == challenge.code {
            let transcriptHash = computeTranscriptHash(messages: transcriptMessages)
            guard transcriptHash == challenge.fingerprint else {
                currentState = .failed(reason: .transcriptMismatch)
                throw PairingError.transcriptMismatch
            }
            currentState = .validating
            return true
        } else {
            let remaining = challenge.maxAttempts - attemptCount
            currentState = .failed(reason: .incorrectCode(attemptsRemaining: remaining))
            return false
        }
    }

    public func addTranscriptMessage(_ data: Data) async {
        transcriptMessages.append(data)
    }

    public func completePairing(peerNodeID: NodeID, peerPublicKey: Data) async throws {
        try await identityService.saveTrustedPeer(TrustedPeer(
            nodeID: peerNodeID,
            signingPublicKey: peerPublicKey,
            agreementPublicKey: peerPublicKey,
            certificateFingerprint: Data(SHA256.hash(data: peerPublicKey)),
            grantedCapabilities: [.screenView, .screenControl, .terminalOpen, .clipboardRead, .clipboardWrite, .fileRead, .fileWrite],
            pairedAt: Date()
        ))
        currentState = .paired(trustedPeer: TrustedPeer(
            nodeID: peerNodeID,
            signingPublicKey: peerPublicKey,
            agreementPublicKey: peerPublicKey,
            certificateFingerprint: Data(SHA256.hash(data: peerPublicKey)),
            grantedCapabilities: [.screenView, .screenControl, .terminalOpen, .clipboardRead, .clipboardWrite, .fileRead, .fileWrite],
            pairedAt: Date()
        ))
    }

    public func revokePeer(_ nodeID: NodeID) async throws {
        try await identityService.revokePeer(nodeID: nodeID)
        currentState = .idle
    }

    public func reset() async {
        currentState = .idle
        currentChallenge = nil
        attemptCount = 0
        cooldownExpiry = nil
        transcriptMessages = []
    }

    public func computeTranscriptHash(messages: [Data]) -> Data {
        var hasher = SHA256()
        for msg in messages {
            hasher.update(data: msg)
        }
        return Data(hasher.finalize())
    }

    private func computeCooldown(attempt: Int) -> TimeInterval {
        let base: TimeInterval = 30
        let multiplier = pow(2.0, Double(min(attempt, 5)))
        return min(base * multiplier, 480)
    }
}

public enum PairingState: Sendable {
    case idle
    case codeGenerated(code: String, expiresAt: Date, attemptCount: Int)
    case waitingForResponse
    case validating
    case paired(trustedPeer: TrustedPeer)
    case failed(reason: PairingFailure)
    case cooldown(expiresAt: Date)
}

public enum PairingFailure: Sendable {
    case expired
    case incorrectCode(attemptsRemaining: Int)
    case maxAttemptsExceeded
    case identityChanged
    case transcriptMismatch
}

public enum PairingError: Error, LocalizedError {
    case expired
    case maxAttemptsExceeded
    case cooldownActive(expiresAt: Date)
    case transcriptMismatch
    case invalidState

    public var errorDescription: String? {
        switch self {
        case .expired: return "Pairing code expired"
        case .maxAttemptsExceeded: return "Maximum attempts exceeded"
        case .cooldownActive(let date): return "Cooldown active until \(date)"
        case .transcriptMismatch: return "Transcript hash mismatch"
        case .invalidState: return "Invalid pairing state"
        }
    }
}
