import Testing
import Foundation
@testable import VanguardDomain
@testable import VanguardTransport

@Suite("STUN Message Parsing")
struct STUNMessageTests {

    @Test("Create binding request with valid structure")
    func bindingRequest() {
        let request = STUNMessage.bindingRequest()
        #expect(request.method == .binding)
        #expect(request.stunClass == .request)
        #expect(request.transactionID.count == 12)
    }

    @Test("Binding request serializes to valid data")
    func serialization() {
        let request = STUNMessage.bindingRequest()
        let data = request.toData()
        #expect(data.count >= 20)
        let magicCookie = data[4...7]
        #expect(magicCookie == Data([0x21, 0x12, 0xA4, 0x42]))
    }

    @Test("Round-trip serialization and parsing")
    func roundTrip() {
        let original = STUNMessage.bindingRequest()
        let data = original.toData()
        let parsed = STUNMessage.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.method == .binding)
        #expect(parsed?.stunClass == .request)
        #expect(parsed?.transactionID == original.transactionID)
    }

    @Test("Parse too-short data returns nil")
    func tooShortData() {
        let data = Data([0x00, 0x01, 0x00, 0x00])
        #expect(STUNMessage.parse(from: data) == nil)
    }

    @Test("Parse data with wrong magic cookie returns nil")
    func wrongMagicCookie() {
        var data = Data(repeating: 0, count: 24)
        data[4] = 0xFF
        data[5] = 0xFF
        data[6] = 0xFF
        data[7] = 0xFF
        #expect(STUNMessage.parse(from: data) == nil)
    }

    @Test("STUN address creation")
    func stunAddress() {
        let addr = STUNAddress(ip: "192.168.1.1", port: 12345)
        #expect(addr.ip == "192.168.1.1")
        #expect(addr.port == 12345)
        #expect(addr.hostPort == "192.168.1.1:12345")
    }

    @Test("STUN method values")
    func methodValues() {
        #expect(STUNMethod.binding.rawValue == 0x0001)
    }

    @Test("STUN class values")
    func classValues() {
        #expect(STUNClass.request.rawValue == 0x00)
        #expect(STUNClass.successResponse.rawValue == 0x01)
        #expect(STUNClass.errorResponse.rawValue == 0x11)
        #expect(STUNClass.indication.rawValue == 0x10)
    }
}

@Suite("NAT Type")
struct NATTypeTests {

    @Test("Direct open allows direct connection")
    func directOpen() {
        #expect(NATType.directOpen.allowsDirectConnection == true)
        #expect(NATType.directOpen.requiresRelay == false)
    }

    @Test("Symmetric NAT requires relay")
    func symmetricNAT() {
        #expect(NATType.symmetricNAT.requiresRelay == true)
        #expect(NATType.symmetricNAT.allowsDirectConnection == false)
    }

    @Test("Port restricted cone NAT requires relay")
    func portRestricted() {
        #expect(NATType.portRestrictedConeNAT.requiresRelay == true)
    }

    @Test("Cone NAT allows direct connection")
    func coneNAT() {
        #expect(NATType.coneNAT.allowsDirectConnection == true)
    }

    @Test("Unknown NAT type requires relay")
    func unknownNAT() {
        #expect(NATType.unknown.requiresRelay == true)
    }
}

@Suite("Connection Route")
struct ConnectionRouteTests {

    @Test("Direct route description")
    func directRoute() {
        let route = ConnectionRoute.direct(host: "192.168.1.100", port: 49494)
        #expect(route.description == "direct://192.168.1.100:49494")
    }

    @Test("Relay route description")
    func relayRoute() {
        let config = RelayConfiguration(relayHost: "relay.example.com", relayPort: 443)
        let route = ConnectionRoute.relay(config)
        #expect(route.description == "relay://relay.example.com:443")
    }

    @Test("VPN route description")
    func vpnRoute() {
        let route = ConnectionRoute.vpn(host: "10.0.0.1", port: 51820)
        #expect(route.description == "vpn://10.0.0.1:51820")
    }

    @Test("Relay configuration")
    func relayConfig() {
        let config = RelayConfiguration(relayHost: "relay.example.com", relayPort: 443, maxBandwidthMbps: 50.0, requireEncryption: true)
        #expect(config.relayHost == "relay.example.com")
        #expect(config.relayPort == 443)
        #expect(config.maxBandwidthMbps == 50.0)
        #expect(config.requireEncryption == true)
    }

    @Test("NAT mapping creation")
    func natMapping() {
        let mapping = NATMapping(
            externalAddress: STUNAddress(ip: "203.0.113.1", port: 5000),
            localAddress: STUNAddress(ip: "192.168.1.100", port: 49494),
            natType: .coneNAT
        )
        #expect(mapping.natType == .coneNAT)
        #expect(mapping.externalAddress.ip == "203.0.113.1")
    }

    @Test("NetworkPath creation")
    func networkPath() {
        let path = NetworkPath(
            route: .direct(host: "192.168.1.1", port: 49494),
            estimatedLatencyMs: 15.0,
            estimatedBandwidthMbps: 100.0,
            isEncrypted: true
        )
        #expect(path.estimatedLatencyMs == 15.0)
        #expect(path.isEncrypted == true)
    }

    @Test("Relay session creation")
    func relaySession() {
        let session = RelaySession(
            relayHost: "relay.example.com",
            relayPort: 443,
            sourceNodeID: UUID(),
            targetNodeID: UUID()
        )
        #expect(session.isActive == true)
        #expect(session.bytesRelayed == 0)
    }
}

@Suite("Connection Route Negotiator")
struct RouteNegotiatorTests {

    @Test("Negotiate direct when both sides have direct NAT")
    func directRouteNegotiation() async {
        let negotiator = ConnectionRouteNegotiator()
        await negotiator.updateLocalNAT(NATMapping(
            externalAddress: STUNAddress(ip: "203.0.113.1", port: 5000),
            localAddress: STUNAddress(ip: "192.168.1.100", port: 49494),
            natType: .coneNAT
        ))
        let route = await negotiator.negotiateRoute(
            targetNodeID: UUID(),
            targetExternalAddress: STUNAddress(ip: "203.0.113.2", port: 6000),
            targetNATType: .coneNAT
        )
        if case .direct(let host, let port) = route {
            #expect(host == "203.0.113.2")
            #expect(port == 6000)
        } else {
            Issue.record("Expected direct route")
        }
    }

    @Test("Negotiate relay when local NAT requires relay")
    func relayRouteNegotiation() async {
        let config = RelayConfiguration(relayHost: "relay.example.com", relayPort: 443)
        let negotiator = ConnectionRouteNegotiator(relayConfiguration: config)
        await negotiator.updateLocalNAT(NATMapping(
            externalAddress: STUNAddress(ip: "203.0.113.1", port: 5000),
            localAddress: STUNAddress(ip: "192.168.1.100", port: 49494),
            natType: .symmetricNAT
        ))
        let route = await negotiator.negotiateRoute(
            targetNodeID: UUID(),
            targetExternalAddress: STUNAddress(ip: "203.0.113.2", port: 6000),
            targetNATType: .coneNAT
        )
        if case .relay(let relayConfig) = route {
            #expect(relayConfig.relayHost == "relay.example.com")
        } else {
            Issue.record("Expected relay route")
        }
    }

    @Test("Negotiate relay when target NAT requires relay")
    func targetRequiresRelay() async {
        let config = RelayConfiguration(relayHost: "relay.example.com", relayPort: 443)
        let negotiator = ConnectionRouteNegotiator(relayConfiguration: config)
        await negotiator.updateLocalNAT(NATMapping(
            externalAddress: STUNAddress(ip: "203.0.113.1", port: 5000),
            localAddress: STUNAddress(ip: "192.168.1.100", port: 49494),
            natType: .coneNAT
        ))
        let route = await negotiator.negotiateRoute(
            targetNodeID: UUID(),
            targetExternalAddress: STUNAddress(ip: "203.0.113.2", port: 6000),
            targetNATType: .symmetricNAT
        )
        if case .relay(let relayConfig) = route {
            #expect(relayConfig.relayHost == "relay.example.com")
        } else {
            Issue.record("Expected relay route")
        }
    }

    @Test("Prefer relay flag forces relay")
    func preferRelay() async {
        let config = RelayConfiguration(relayHost: "relay.example.com", relayPort: 443)
        let negotiator = ConnectionRouteNegotiator(relayConfiguration: config)
        await negotiator.updateLocalNAT(NATMapping(
            externalAddress: STUNAddress(ip: "203.0.113.1", port: 5000),
            localAddress: STUNAddress(ip: "192.168.1.100", port: 49494),
            natType: .coneNAT
        ))
        let route = await negotiator.negotiateRoute(
            targetNodeID: UUID(),
            targetExternalAddress: STUNAddress(ip: "203.0.113.2", port: 6000),
            targetNATType: .coneNAT,
            preferRelay: true
        )
        if case .relay = route {
            // OK
        } else {
            Issue.record("Expected relay route when preferRelay is true")
        }
    }

    @Test("Fallback to direct when no relay available and both sides open")
    func fallbackDirect() async {
        let negotiator = ConnectionRouteNegotiator()
        let route = await negotiator.negotiateRoute(
            targetNodeID: UUID(),
            targetExternalAddress: STUNAddress(ip: "203.0.113.2", port: 6000),
            targetNATType: .coneNAT
        )
        if case .direct(let host, let port) = route {
            #expect(host == "203.0.113.2")
            #expect(port == 6000)
        } else {
            Issue.record("Expected direct route when no relay available")
        }
    }
}
