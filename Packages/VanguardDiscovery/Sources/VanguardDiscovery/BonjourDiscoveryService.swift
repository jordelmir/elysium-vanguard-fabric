import Foundation
import Network
import VanguardDomain

// MARK: - Discovered Node Endpoint (wraps NWEndpoint for transport)

public struct DiscoveredNodeEndpoint: @unchecked Sendable {
    public let advertisement: NodeAdvertisement
    public let networkEndpoint: NWEndpoint

    public init(advertisement: NodeAdvertisement, networkEndpoint: NWEndpoint) {
        self.advertisement = advertisement
        self.networkEndpoint = networkEndpoint
    }
}

// MARK: - Bonjour Discovery Service

public final class BonjourDiscoveryService: DiscoveryService, @unchecked Sendable {
    private var browser: NWBrowser?
    private let configuration: DiscoveryConfiguration
    private var isBrowsing = false
    private let state: ManagedState

    private var resolvedEndpoints: [Data: NWEndpoint] = [:]
    private var discoveredNodes: [Data: NodeAdvertisement] = [:]

    public init(configuration: DiscoveryConfiguration = .default) {
        self.configuration = configuration
        self.state = ManagedState()
    }

    public var stateUpdates: AsyncThrowingStream<DiscoveryState, Error> {
        let stateRef = self.state
        return AsyncThrowingStream { continuation in
            Task { await stateRef.setContinuation(continuation) }
            continuation.onTermination = { @Sendable _ in
                Task { await stateRef.continuationFinished() }
            }
        }
    }

    // MARK: - Browse

    public func startBrowsing() async throws {
        guard !isBrowsing else { throw DiscoveryError.alreadyDiscovering }

        let params = NWParameters()
        params.includePeerToPeer = true

        let browser = NWBrowser(
            for: .bonjour(type: configuration.serviceType, domain: nil),
            using: params
        )

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self else { return }
            Task { @Sendable in
                await self.handleBrowseResults(results, changes: changes)
            }
        }

        self.browser = browser
        self.isBrowsing = true
        browser.start(queue: .global(qos: .userInitiated))
        await state.emit(.browsing)
    }

    public func stopBrowsing() async {
        browser?.cancel()
        browser = nil
        isBrowsing = false
        discoveredNodes.removeAll()
        resolvedEndpoints.removeAll()
    }

    // MARK: - Publish (Node uses transport for Bonjour, stub for protocol conformance)

    public func publishAdvertisement(_ advertisement: NodeAdvertisement) async throws {
        // Node publishes Bonjour via the transport's listener, not here.
        // This is a no-op. The transport handles Bonjour advertisement.
    }

    public func unpublish() async {
        // No-op — transport owns the listener lifecycle.
    }

    // MARK: - Results

    private func handleBrowseResults(
        _ results: Set<NWBrowser.Result>,
        changes: Set<NWBrowser.Result.Change>
    ) async {
        for change in changes {
            switch change {
            case .added(let result):
                await processResult(result, isUpdate: false)
            case .removed(let result):
                if case .service(let name, _, _, _) = result.endpoint {
                    let hashData = Data(name.utf8)
                    discoveredNodes.removeValue(forKey: hashData)
                    resolvedEndpoints.removeValue(forKey: hashData)
                    await state.emit(.nodeLost(nodeIDHash: hashData))
                }
            case .identical:
                break
            @unknown default:
                break
            }
        }

        for result in results {
            await processResult(result, isUpdate: true)
        }
    }

    private func processResult(_ result: NWBrowser.Result, isUpdate: Bool) async {
        guard let ad = parseAdvertisement(from: result) else { return }
        let nodeIDHash = ad.nodeIDHash

        if let existing = discoveredNodes[nodeIDHash] {
            if existing != ad {
                discoveredNodes[nodeIDHash] = ad
                resolvedEndpoints[nodeIDHash] = result.endpoint
                await state.emit(.nodeUpdated(ad))
            }
        } else {
            discoveredNodes[nodeIDHash] = ad
            resolvedEndpoints[nodeIDHash] = result.endpoint
            await state.emit(.nodeFound(ad))
        }
    }

    // MARK: - Get Resolved Endpoint

    public func getResolvedEndpoint(for nodeIDHash: Data) -> NWEndpoint? {
        resolvedEndpoints[nodeIDHash]
    }

    public func getDiscoveredNodeEndpoint(for nodeIDHash: Data) -> DiscoveredNodeEndpoint? {
        guard let ad = discoveredNodes[nodeIDHash],
              let endpoint = resolvedEndpoints[nodeIDHash] else { return nil }
        return DiscoveredNodeEndpoint(advertisement: ad, networkEndpoint: endpoint)
    }

    // MARK: - TXT Record Parsing

    private func parseAdvertisement(from result: NWBrowser.Result) -> NodeAdvertisement? {
        guard case .bonjour(let txtRecord) = result.metadata else { return nil }

        let pv = txtRecord["pv"] ?? "1.0"
        let archRaw = txtRecord["arch"] ?? "unknown"
        let osRaw = txtRecord["os"] ?? "unknown"
        let osv = txtRecord["osv"] ?? "0.0"
        let pairRaw = txtRecord["pair"] ?? "untrusted"
        let nhBase64 = txtRecord["nh"] ?? ""
        let displayName = resolveName(from: result.endpoint)

        guard let port = resolvePort(from: result.endpoint) else { return nil }

        let components = pv.split(separator: ".")
        let major = UInt16(components.first.map(String.init) ?? "1") ?? 1
        let minor = UInt16(components.dropFirst().first.map(String.init) ?? "0") ?? 0

        return NodeAdvertisement(
            nodeIDHash: Data(base64Encoded: nhBase64) ?? Data(),
            displayName: displayName,
            architecture: CPUArchitecture(rawValue: archRaw) ?? .unknown,
            osFamily: OSFamily(rawValue: osRaw) ?? .unknown,
            osVersion: osv,
            protocolVersion: ProtocolVersion(major: major, minor: minor),
            pairingState: TrustState(rawValue: pairRaw) ?? .untrusted,
            endpoint: NodeEndpoint(host: displayName, port: port)
        )
    }

    private func resolvePort(from endpoint: NWEndpoint) -> UInt16? {
        switch endpoint {
        case .hostPort(_, let port):
            return port.rawValue
        case .service:
            return nil
        default:
            return nil
        }
    }

    private func resolveName(from endpoint: NWEndpoint) -> String {
        switch endpoint {
        case .service(let name, _, _, _):
            return name
        case .hostPort(let host, _):
            switch host {
            case .name(let name, _): return name
            default: return host.debugDescription
            }
        default:
            return "Unknown"
        }
    }
}

// MARK: - Managed State

private actor ManagedState {
    private var continuation: AsyncThrowingStream<DiscoveryState, Error>.Continuation?

    func setContinuation(_ cont: AsyncThrowingStream<DiscoveryState, Error>.Continuation) {
        self.continuation = cont
    }

    func continuationFinished() { continuation = nil }

    func emit(_ state: DiscoveryState) { continuation?.yield(state) }
}
