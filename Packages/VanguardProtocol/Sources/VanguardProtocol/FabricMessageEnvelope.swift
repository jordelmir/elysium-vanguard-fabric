import Foundation
import VanguardDomain

public struct FabricMessageEnvelope: Codable, Sendable {
    public let magic: UInt32
    public let protocolMajor: UInt16
    public let protocolMinor: UInt16
    public let messageType: UInt16
    public let channel: UInt16
    public let flags: UInt16
    public let reserved: UInt16
    public let sessionID: UUID
    public let sequence: UInt64
    public let payloadLength: UInt64

    public init(
        protocolVersion: ProtocolVersion = .v1,
        messageType: UInt16,
        channel: UInt16,
        flags: UInt16 = 0,
        sessionID: UUID,
        sequence: UInt64,
        payloadLength: UInt64
    ) {
        self.magic = 0x45564642
        self.protocolMajor = protocolVersion.major
        self.protocolMinor = protocolVersion.minor
        self.messageType = messageType
        self.channel = channel
        self.flags = flags
        self.reserved = 0
        self.sessionID = sessionID
        self.sequence = sequence
        self.payloadLength = payloadLength
    }

    public var headerData: Data {
        var data = Data(capacity: 32)
        var m = magic.bigEndian; data.append(Data(bytes: &m, count: 4))
        var maj = protocolMajor.bigEndian; data.append(Data(bytes: &maj, count: 2))
        var mn = protocolMinor.bigEndian; data.append(Data(bytes: &mn, count: 2))
        var mt = messageType.bigEndian; data.append(Data(bytes: &mt, count: 2))
        var ch = channel.bigEndian; data.append(Data(bytes: &ch, count: 2))
        var fl = flags.bigEndian; data.append(Data(bytes: &fl, count: 2))
        var rv = reserved.bigEndian; data.append(Data(bytes: &rv, count: 2))
        var uuidBytes = sessionID.uuid; data.append(Data(bytes: &uuidBytes, count: 16))
        var seq = sequence.bigEndian; data.append(Data(bytes: &seq, count: 8))
        var pl = payloadLength.bigEndian; data.append(Data(bytes: &pl, count: 8))
        return data
    }

    public static func parse(from data: Data) -> Result<FabricMessageEnvelope, ProtocolError> {
        guard data.count >= 48 else {
            return .failure(.invalidPayload(reason: "Envelope too short: \(data.count) bytes"))
        }

        let magic = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }.bigEndian
        guard magic == 0x45564642 else {
            return .failure(.invalidMagic)
        }

        let major = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt16.self) }.bigEndian
        let minor = data.withUnsafeBytes { $0.load(fromByteOffset: 6, as: UInt16.self) }.bigEndian
        let msgType = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt16.self) }.bigEndian
        let channel = data.withUnsafeBytes { $0.load(fromByteOffset: 10, as: UInt16.self) }.bigEndian
        let flags = data.withUnsafeBytes { $0.load(fromByteOffset: 12, as: UInt16.self) }.bigEndian

        let sessionID = data.withUnsafeBytes { ptr -> UUID in
            let bytes = ptr.load(fromByteOffset: 16, as: (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8).self)
            return UUID(uuid: uuid_t(bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5, bytes.6, bytes.7, bytes.8, bytes.9, bytes.10, bytes.11, bytes.12, bytes.13, bytes.14, bytes.15))
        }

        let sequence = data.withUnsafeBytes { $0.load(fromByteOffset: 32, as: UInt64.self) }.bigEndian
        let payloadLength = data.withUnsafeBytes { $0.load(fromByteOffset: 40, as: UInt64.self) }.bigEndian

        let envelope = FabricMessageEnvelope(
            protocolVersion: ProtocolVersion(major: major, minor: minor),
            messageType: msgType,
            channel: channel,
            flags: flags,
            sessionID: sessionID,
            sequence: sequence,
            payloadLength: payloadLength
        )
        return .success(envelope)
    }
}
