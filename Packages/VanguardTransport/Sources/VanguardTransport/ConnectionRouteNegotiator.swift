import Foundation
import os.log
import VanguardDomain

private let routeLogger = Logger(subsystem: "ElysiumVanguard", category: "RouteNegotiator")

public actor ConnectionRouteNegotiator {
    private var localNATMapping: NATMapping?
    private var discoveredRoutes: [String: NetworkPath] = [:]
    private var relayConfig: RelayConfiguration?

    public init(relayConfiguration: RelayConfiguration? = nil) {
        self.relayConfig = relayConfiguration
    }

    public func updateLocalNAT(_ mapping: NATMapping) {
        localNATMapping = mapping
        routeLogger.info("Local NAT updated: \(mapping.natType.rawValue)")
    }

    public func setRelayConfiguration(_ config: RelayConfiguration) {
        relayConfig = config
    }

    public func negotiateRoute(
        targetNodeID: UUID,
        targetExternalAddress: STUNAddress?,
        targetNATType: NATType?,
        preferRelay: Bool = false
    ) -> ConnectionRoute {
        let localNAT = localNATMapping?.natType ?? .unknown

        if preferRelay, let config = relayConfig {
            routeLogger.info("Route: relay (preferred)")
            return .relay(config)
        }

        if localNAT.requiresRelay {
            if let config = relayConfig {
                routeLogger.info("Route: relay (local NAT: \(localNAT.rawValue))")
                return .relay(config)
            }
            routeLogger.warning("No relay available, local NAT requires relay")
        }

        if let targetNATType, targetNATType.requiresRelay {
            if let config = relayConfig {
                routeLogger.info("Route: relay (target NAT: \(targetNATType.rawValue))")
                return .relay(config)
            }
            routeLogger.warning("Target NAT requires relay, no relay available")
        }

        if let target = targetExternalAddress {
            routeLogger.info("Route: direct to \(target.hostPort)")
            return .direct(host: target.ip, port: target.port)
        }

        if let config = relayConfig {
            routeLogger.info("Route: relay (no target address)")
            return .relay(config)
        }

        return .direct(host: "127.0.0.1", port: 49494)
    }

    public func probeRoute(_ route: ConnectionRoute) -> NetworkPath {
        let start = Date()
        let reachable = checkReachability(route: route)
        let latency = reachable ? Date().timeIntervalSince(start) * 1000 : -1

        let path = NetworkPath(
            route: route,
            natMapping: localNATMapping,
            estimatedLatencyMs: latency,
            estimatedBandwidthMbps: reachable ? 100.0 : 0,
            isEncrypted: true,
            lastProbedAt: Date()
        )

        if case .direct(let host, _) = route {
            discoveredRoutes[host] = path
        }

        return path
    }

    public func getBestRoute(for targetNodeID: UUID) -> ConnectionRoute? {
        return relayConfig.map { .relay($0) }
    }

    private func checkReachability(route: ConnectionRoute) -> Bool {
        switch route {
        case .direct(let host, let port):
            return checkTCPReachability(host: host, port: port)
        case .relay:
            return true
        case .vpn(let host, let port):
            return checkTCPReachability(host: host, port: port)
        }
    }

    private func checkTCPReachability(host: String, port: UInt16) -> Bool {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        let converted = host.withCString { cHost in
            inet_pton(AF_INET, cHost, &addr.sin_addr)
        }
        guard converted == 1 else { return false }

        let sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }
}
