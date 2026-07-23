import Foundation
import Network
import VanguardDomain

// MARK: - Bonjour Discovery Service (macOS implementation)

public final class BonjourDiscoveryService: DiscoveryService, @unchecked Sendable {
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var discoveredNodes: [Data: NodeAdvertisement] = [:]
    private let configuration: DiscoveryConfiguration
    private var isPublishing = false
    private var isBrowsing = false
    private let state: ManagedState

    public init(configuration: DiscoveryConfiguration = .default) {
        self.configuration = configuration
        self.state = ManagedState()
    }

    public var stateUpdates: AsyncThrowingStream<DiscoveryState, Error> {
        let stateRef = self.state
        return AsyncThrowingStream { continuation in
            Task {
                await stateRef.setContinuation(continuation)
            }
            continuation.onTermination = { @Sendable _ in
                Task {
                    await stateRef.continuationFinished()
                }
            }
        }
    }

    // MARK: - Browse for nodes

    public func startBrowsing() async throws {
        guard !isBrowsing else {
            throw DiscoveryError.alreadyDiscovering
        }

        let params = NWParameters()
        params.includePeerToPeer = true

        let browser = NWBrowser(
            for: .bonjour(type: configuration.serviceType, domain: nil),
            using: params
        )

        browser.stateUpdateHandler = { [weak self] browserState in
            guard self != nil else { return }
            Task { @Sendable in
            }
        }

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
    }

    // MARK: - Publish node

    public func publishAdvertisement(_ advertisement: NodeAdvertisement) async throws {
        guard let port = NWEndpoint.Port(rawValue: advertisement.endpoint.port) else {
            throw DiscoveryError.advertisementMalformed
        }

        let listener = try NWListener(using: NWParameters(tls: .none), on: port)

        listener.service = NWListener.Service(
            name: advertisement.displayName,
            type: configuration.serviceType
        )

        listener.stateUpdateHandler = { [weak self] listenerState in
            guard self != nil else { return }
            Task { @Sendable in
            }
        }

        self.listener = listener
        self.isPublishing = true
        listener.start(queue: .global(qos: .userInitiated))
    }

    public func unpublish() async {
        listener?.cancel()
        listener = nil
        isPublishing = false
    }

    // MARK: - Handle results

    private func handleBrowseResults(
        _ results: Set<NWBrowser.Result>,
        changes: Set<NWBrowser.Result.Change>
    ) async {
        for change in changes {
            switch change {
            case .added(let result):
                if let ad = parseAdvertisement(from: result) {
                    let nodeIDHash = ad.nodeIDHash
                    discoveredNodes[nodeIDHash] = ad
                    await state.emit(.nodeFound(ad))
                }
            case .removed(let result):
                let endpoint = result.endpoint
                if case .service(let name, _, _, _) = endpoint {
                    let hashData = Data(name.utf8)
                    discoveredNodes.removeValue(forKey: hashData)
                    await state.emit(.nodeLost(nodeIDHash: hashData))
                }
            case .identical:
                break
            @unknown default:
                break
            }
        }

        for result in results {
            if let ad = parseAdvertisement(from: result) {
                let nodeIDHash = ad.nodeIDHash
                if let existing = discoveredNodes[nodeIDHash] {
                    if existing != ad {
                        discoveredNodes[nodeIDHash] = ad
                        await state.emit(.nodeUpdated(ad))
                    }
                } else {
                    discoveredNodes[nodeIDHash] = ad
                    await state.emit(.nodeFound(ad))
                }
            }
        }
    }

    // MARK: - TXT Record

    private func buildTXTRecord(from ad: NodeAdvertisement) throws -> NWTXTRecord {
        var record = NWTXTRecord()
        record["pv"] = ad.protocolVersion.description
        record["arch"] = ad.architecture.rawValue
        record["os"] = ad.osFamily.rawValue
        record["osv"] = ad.osVersion
        record["pair"] = ad.pairingState.rawValue
        record["nh"] = ad.nodeIDHash.base64EncodedString()
        return record
    }

    private func parseAdvertisement(from result: NWBrowser.Result) -> NodeAdvertisement? {
        guard case .bonjour(let txtRecord) = result.metadata else { return nil }

        let pv = txtRecord["pv"] ?? "1.0"
        let archRaw = txtRecord["arch"] ?? "unknown"
        let osRaw = txtRecord["os"] ?? "unknown"
        let osv = txtRecord["osv"] ?? "0.0"
        let pairRaw = txtRecord["pair"] ?? "untrusted"
        let nhBase64 = txtRecord["nh"] ?? ""

        guard let host = resolveHost(from: result.endpoint),
              let port = resolvePort(from: result.endpoint) else {
            return nil
        }

        let components = pv.split(separator: ".")
        let major = UInt16(components.first.map(String.init) ?? "1") ?? 1
        let minor = UInt16(components.dropFirst().first.map(String.init) ?? "0") ?? 0

        return NodeAdvertisement(
            nodeIDHash: Data(base64Encoded: nhBase64) ?? Data(),
            displayName: resolveName(from: result.endpoint),
            architecture: CPUArchitecture(rawValue: archRaw) ?? .unknown,
            osFamily: OSFamily(rawValue: osRaw) ?? .unknown,
            osVersion: osv,
            protocolVersion: ProtocolVersion(major: major, minor: minor),
            pairingState: TrustState(rawValue: pairRaw) ?? .untrusted,
            endpoint: NodeEndpoint(host: host, port: port)
        )
    }

    private func resolveHost(from endpoint: NWEndpoint) -> String? {
        switch endpoint {
        case .hostPort(let host, _):
            switch host {
            case .ipv4(let addr):
                return addr.debugDescription
            case .ipv6(let addr):
                return addr.debugDescription
            case .name(let name, _):
                return name
            @unknown default:
                return nil
            }
        case .service(let name, _, _, _):
            return name
        default:
            return nil
        }
    }

    private func resolvePort(from endpoint: NWEndpoint) -> UInt16? {
        switch endpoint {
        case .hostPort(_, let port):
            return port.rawValue
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
            case .name(let name, _):
                return name
            default:
                return host.debugDescription
            }
        default:
            return "Unknown"
        }
    }
}

// MARK: - Managed State (actor for safe continuation access)

private actor ManagedState {
    private var continuation: AsyncThrowingStream<DiscoveryState, Error>.Continuation?

    func setContinuation(_ cont: AsyncThrowingStream<DiscoveryState, Error>.Continuation) {
        self.continuation = cont
    }

    func continuationFinished() {
        continuation = nil
    }

    func emit(_ state: DiscoveryState) {
        continuation?.yield(state)
    }
}
