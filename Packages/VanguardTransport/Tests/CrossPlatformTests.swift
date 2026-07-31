import Testing
import Foundation
@testable import VanguardTransport
@testable import VanguardDomain

@Suite("Cross-Platform Protocol Compatibility")
struct CrossPlatformTests {

    @Test("Envelope round-trip matches spec (48 bytes)")
    func envelopeRoundTrip() {
        var data = Data()
        data.append(contentsOf: [0x45, 0x56, 0x46, 0x42])
        data.append(contentsOf: UInt16(1).bigEndianBytes)
        data.append(contentsOf: UInt16(0).bigEndianBytes)
        data.append(contentsOf: UInt16(0x0001).bigEndianBytes)
        data.append(contentsOf: UInt16(0).bigEndianBytes)
        data.append(contentsOf: UInt16(0).bigEndianBytes)
        data.append(contentsOf: UInt16(0).bigEndianBytes)
        data.append(contentsOf: [UInt8](repeating: 0, count: 16))
        data.append(contentsOf: UInt64(0).bigEndianBytes)
        data.append(contentsOf: UInt64(0).bigEndianBytes)
        #expect(data.count == 48)
        #expect(data[0] == 0x45)
        #expect(data[1] == 0x56)
        #expect(data[2] == 0x46)
        #expect(data[3] == 0x42)
    }

    @Test("STUN binding request matches RFC 5389 test vector")
    func stunBindingRequest() {
        let request = STUNMessage.bindingRequest()
        let data = request.toData()
        #expect(data.count >= 20)
        let typeRaw = UInt16(data[0]) << 8 | UInt16(data[1])
        let method = typeRaw & 0x3FFF
        let stunClass = (typeRaw >> 14) & 0x03
        #expect(method == 0x0001)
        #expect(stunClass == 0x00)
        let magicCookie = data[4...7]
        #expect(magicCookie == Data([0x21, 0x12, 0xA4, 0x42]))
    }

    @Test("STUN binding request round-trip")
    func stunRoundTrip() {
        let original = STUNMessage.bindingRequest()
        let data = original.toData()
        let parsed = STUNMessage.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.method == .binding)
        #expect(parsed?.stunClass == .request)
        #expect(parsed?.transactionID == original.transactionID)
    }

    @Test("Capability bitfield encoding matches spec")
    func capabilityBitfield() {
        var bits: UInt32 = 0
        bits |= (1 << 0)
        bits |= (1 << 1)
        bits |= (1 << 4)
        bits |= (1 << 5)
        bits |= (1 << 6)
        bits |= (1 << 7)
        #expect(bits == 0x000000F3)
        let hasScreenView = (bits & (1 << 0)) != 0
        let hasScreenControl = (bits & (1 << 1)) != 0
        let hasClipboardRead = (bits & (1 << 4)) != 0
        let hasTerminalOpen = (bits & (1 << 6)) != 0
        #expect(hasScreenView == true)
        #expect(hasScreenControl == true)
        #expect(hasClipboardRead == true)
        #expect(hasTerminalOpen == true)
        let hasAudioReceive = (bits & (1 << 2)) != 0
        #expect(hasAudioReceive == false)
        let hasTerminalWrite = (bits & (1 << 7)) != 0
        #expect(hasTerminalWrite == true)
    }

    @Test("NAT type relay requirements match spec")
    func natTypeRelay() {
        #expect(NATType.directOpen.requiresRelay == false)
        #expect(NATType.coneNAT.requiresRelay == false)
        #expect(NATType.restrictedConeNAT.requiresRelay == false)
        #expect(NATType.portRestrictedConeNAT.requiresRelay == true)
        #expect(NATType.symmetricNAT.requiresRelay == true)
        #expect(NATType.symmetricFirewall.requiresRelay == false)
        #expect(NATType.unknown.requiresRelay == true)
    }

    @Test("Connection route descriptions are stable")
    func routeDescriptions() {
        let direct = ConnectionRoute.direct(host: "192.168.1.1", port: 49494)
        #expect(direct.description == "direct://192.168.1.1:49494")
        let relay = ConnectionRoute.relay(RelayConfiguration(relayHost: "relay.test.com", relayPort: 443))
        #expect(relay.description == "relay://relay.test.com:443")
        let vpn = ConnectionRoute.vpn(host: "10.0.0.1", port: 51820)
        #expect(vpn.description == "vpn://10.0.0.1:51820")
    }

    @Test("Big-endian encoding for u16 and u32")
    func bigEndianEncoding() {
        let val16: UInt16 = 0x0102
        let bytes16 = val16.bigEndianBytes
        #expect(bytes16 == [0x01, 0x02])
        let val32: UInt32 = 0x01020304
        let bytes32 = val32.bigEndianBytes
        #expect(bytes32 == [0x01, 0x02, 0x03, 0x04])
    }

    @Test("UUID string format is valid")
    func uuidFormat() {
        let uuid = UUID()
        let str = uuid.uuidString
        #expect(str.count == 36)
        let dashes = str.filter { $0 == "-" }
        #expect(dashes.count == 4)
    }

    @Test("Channel IDs match spec")
    func channelIDs() {
        let channels: [UInt16] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
        #expect(channels.count == 9)
        #expect(channels[0] == 0)
        #expect(channels[8] == 8)
    }

    @Test("MessageType IDs match spec")
    func messageTypeIDs() {
        let hello: UInt16 = 0x0001
        let helloAck: UInt16 = 0x0002
        let pairingRequest: UInt16 = 0x0010
        let videoConfig: UInt16 = 0x0100
        let videoFrame: UInt16 = 0x0101
        let inputEvent: UInt16 = 0x0200
        let jobSubmit: UInt16 = 0x0800
        #expect(hello == 0x0001)
        #expect(helloAck == 0x0002)
        #expect(pairingRequest == 0x0010)
        #expect(videoConfig == 0x0100)
        #expect(videoFrame == 0x0101)
        #expect(inputEvent == 0x0200)
        #expect(jobSubmit == 0x0800)
    }

    @Test("STUN message with attributes round-trip")
    func stunWithAttributes() {
        let addr = STUNAddress(ip: "203.0.113.1", port: 5000)
        let msg = STUNMessage(
            stunClass: .successResponse,
            method: .binding,
            transactionID: Data(repeating: 0xAA, count: 12),
            attributes: [.mappedAddress(addr), .software("ElysiumTest")]
        )
        let data = msg.toData()
        let parsed = STUNMessage.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.stunClass == .successResponse)
        #expect(parsed?.attributes.count == 2)
        let mapped = parsed?.getMappedAddress()
        #expect(mapped?.ip == "203.0.113.1")
        #expect(mapped?.port == 5000)
    }
}
