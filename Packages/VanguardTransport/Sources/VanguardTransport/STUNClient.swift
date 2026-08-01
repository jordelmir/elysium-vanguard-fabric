import Foundation
import Network
import os.log
import VanguardDomain

private let stunClientLogger = Logger(subsystem: "ElysiumVanguard", category: "STUNClient")

public enum STUNError: Error, Sendable, LocalizedError {
    case connectionFailed(String)
    case sendFailed(String)
    case receiveFailed(String)
    case timeout
    case cancelled
    case noResponse
    case invalidResponse
    case serverError
    case noMappedAddress

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let r): return "STUN connection failed: \(r)"
        case .sendFailed(let r): return "STUN send failed: \(r)"
        case .receiveFailed(let r): return "STUN receive failed: \(r)"
        case .timeout: return "STUN request timed out"
        case .cancelled: return "STUN request cancelled"
        case .noResponse: return "STUN server did not respond"
        case .invalidResponse: return "STUN response could not be parsed"
        case .serverError: return "STUN server returned error"
        case .noMappedAddress: return "STUN response contained no mapped address"
        }
    }
}

public actor STUNClient {
    private var connection: NWConnection?

    public init() {}

    public func discoverNATType(
        stunHost: String,
        stunPort: UInt16,
        timeoutSeconds: TimeInterval = 5.0
    ) async throws -> NATMapping {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(stunHost),
            port: NWEndpoint.Port(rawValue: stunPort) ?? .any
        )
        let params = NWParameters()
        params.defaultProtocolStack.transportProtocol = NWProtocolUDP.Options()
        let conn = NWConnection(to: endpoint, using: params)
        self.connection = conn

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NATMapping, Error>) in
            let state = SharedState(continuation: continuation)
            var resumed = false

            conn.stateUpdateHandler = { connState in
                switch connState {
                case .ready:
                    let request = STUNMessage.bindingRequest()
                    let data = request.toData()
                    conn.send(content: data, completion: .contentProcessed { sendError in
                        if let sendError {
                            state.complete(.failure(STUNError.sendFailed(sendError.localizedDescription)))
                            return
                        }
                        conn.receive(minimumIncompleteLength: 1, maximumLength: 1024) { rxData, _, _, rxError in
                            if let rxError {
                                state.complete(.failure(STUNError.receiveFailed(rxError.localizedDescription)))
                                return
                            }
                            guard let rxData, !rxData.isEmpty else {
                                state.complete(.failure(STUNError.noResponse))
                                return
                            }
                            guard let response = STUNMessage.parse(from: rxData) else {
                                state.complete(.failure(STUNError.invalidResponse))
                                return
                            }
                            guard response.stunClass == .successResponse else {
                                state.complete(.failure(STUNError.serverError))
                                return
                            }
                            guard let mapped = response.getMappedAddress() else {
                                state.complete(.failure(STUNError.noMappedAddress))
                                return
                            }
                            let mapping = NATMapping(
                                externalAddress: mapped,
                                localAddress: STUNAddress(ip: "0.0.0.0", port: 0),
                                natType: .unknown,
                                mappedAt: Date()
                            )
                            state.complete(.success(mapping))
                        }
                    })
                case .failed(let error):
                    state.complete(.failure(STUNError.connectionFailed(error.localizedDescription)))
                case .cancelled:
                    state.complete(.failure(STUNError.cancelled))
                default:
                    break
                }
            }

            conn.start(queue: .global(qos: .userInitiated))

            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                conn.cancel()
                state.complete(.failure(STUNError.timeout))
            }
        }
    }

    public func cancel() {
        connection?.cancel()
        connection = nil
    }
}

private final class SharedState: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private let continuation: CheckedContinuation<NATMapping, Error>

    init(continuation: CheckedContinuation<NATMapping, Error>) {
        self.continuation = continuation
    }

    func complete(_ result: Result<NATMapping, Error>) {
        lock.withLock {
            guard !completed else { return }
            completed = true
        }
        switch result {
        case .success(let v): continuation.resume(returning: v)
        case .failure(let e): continuation.resume(throwing: e)
        }
    }
}
