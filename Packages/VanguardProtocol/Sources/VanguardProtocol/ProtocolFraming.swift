import Foundation
import VanguardDomain

// MARK: - Protocol Header

public struct ProtocolHeader: Sendable {
    public let magic: [UInt8]
    public let protocolVersion: UInt16
    public let messageType: MessageType
    public let flags: MessageFlags
    public let reserved: UInt16
    public let streamChannel: StreamChannel
    public let sequenceNumber: UInt64
    public let payloadLength: UInt32

    public init(
        protocolVersion: UInt16 = 1,
        messageType: MessageType,
        flags: MessageFlags = .none,
        streamChannel: StreamChannel = .control,
        sequenceNumber: UInt64 = 0,
        payloadLength: UInt32 = 0
    ) {
        self.magic = VanguardProtocolConstants.magic
        self.protocolVersion = protocolVersion
        self.messageType = messageType
        self.flags = flags
        self.reserved = 0
        self.streamChannel = streamChannel
        self.sequenceNumber = sequenceNumber
        self.payloadLength = payloadLength
    }

    public var headerData: Data {
        var data = Data(capacity: VanguardProtocolConstants.headerSize)
        data.append(contentsOf: magic)
        data.appendUInt16(protocolVersion)
        data.appendUInt16(messageType.rawValue)
        data.appendUInt16(flags.rawValue)
        data.appendUInt16(reserved)
        data.appendUInt8(streamChannel.rawValue)
        data.appendUInt64(sequenceNumber)
        data.appendUInt32(payloadLength)
        return data
    }

    public static func parse(from data: Data) -> Result<ProtocolHeader, ProtocolError> {
        guard data.count >= VanguardProtocolConstants.headerSize else {
            return .failure(.invalidPayload(reason: "Header too short: \(data.count) bytes"))
        }

        let magicBytes = [UInt8](data[0..<4])
        guard magicBytes == VanguardProtocolConstants.magic else {
            return .failure(.invalidMagic)
        }

        let version = data.readUInt16(at: 4)
        guard version <= 1 else {
            return .failure(.unsupportedVersion(major: version))
        }

        let msgTypeRaw = data.readUInt16(at: 6)
        guard let msgType = MessageType(rawValue: msgTypeRaw) else {
            return .failure(.unknownMessageType(rawValue: msgTypeRaw))
        }

        let flags = MessageFlags(rawValue: data.readUInt16(at: 8))
        let reserved = data.readUInt16(at: 10)
        guard let channel = StreamChannel(rawValue: data[12]) else {
            return .failure(.invalidPayload(reason: "Invalid stream channel: \(data[12])"))
        }
        let seqNum = data.readUInt64(at: 13)
        let payloadLen = data.readUInt32(at: 21)

        let header = ProtocolHeader(
            protocolVersion: version,
            messageType: msgType,
            flags: flags,
            streamChannel: channel,
            sequenceNumber: seqNum,
            payloadLength: payloadLen
        )
        return .success(header)
    }
}

// MARK: - Frame

public struct ProtocolFrame: Sendable {
    public let header: ProtocolHeader
    public let payload: Data

    public init(header: ProtocolHeader, payload: Data = Data()) {
        self.header = header
        self.payload = payload
    }

    public var totalData: Data {
        var data = header.headerData
        data.append(payload)
        return data
    }

    public static func parse(from data: Data) -> Result<ProtocolFrame, ProtocolError> {
        let headerResult = ProtocolHeader.parse(from: data)
        switch headerResult {
        case .failure(let error):
            return .failure(error)
        case .success(let header):
            let expectedTotal = VanguardProtocolConstants.headerSize + Int(header.payloadLength)
            guard data.count >= expectedTotal else {
                return .failure(.invalidPayload(reason: "Frame too short: \(data.count), expected \(expectedTotal)"))
            }
            let payload = data[VanguardProtocolConstants.headerSize..<expectedTotal]
            return .success(ProtocolFrame(header: header, payload: Data(payload)))
        }
    }
}
