import Foundation
import VanguardDomain
import VanguardProtocol

public enum FrameDecoderError: Error, Sendable {
    case invalidMagic([UInt8])
    case unsupportedVersion(UInt16)
    case unknownMessageType(UInt16)
    case invalidChannel(UInt8)
    case payloadTooLarge(channel: UInt8, size: UInt32, max: Int)
    case frameTruncated(needed: Int, available: Int)
    case invalidFrame(reason: String)
}

public final class FrameDecoder: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    public init() {}

    public func append(data: Data) {
        lock.withLock { buffer.append(data) }
    }

    public func nextFrame() -> Result<ProtocolFrame, FrameDecoderError>? {
        lock.withLock {
            guard buffer.count >= VanguardProtocolConstants.headerSize else { return nil }

            let magicBytes = [UInt8](buffer[0..<4])
            guard magicBytes == VanguardProtocolConstants.magic else {
                buffer.removeAll(keepingCapacity: true)
                return .failure(.invalidMagic(magicBytes))
            }

            let version = (UInt16(buffer[4]) << 8) | UInt16(buffer[5])
            guard version <= 1 else {
                buffer.removeAll(keepingCapacity: true)
                return .failure(.unsupportedVersion(version))
            }

            let msgTypeRaw = (UInt16(buffer[6]) << 8) | UInt16(buffer[7])
            guard MessageType(rawValue: msgTypeRaw) != nil else {
                buffer.removeFirst(min(VanguardProtocolConstants.headerSize, buffer.count))
                return .failure(.unknownMessageType(msgTypeRaw))
            }

            let channelRaw = buffer[12]
            guard StreamChannel(rawValue: channelRaw) != nil else {
                buffer.removeFirst(min(VanguardProtocolConstants.headerSize, buffer.count))
                return .failure(.invalidChannel(channelRaw))
            }

            let payloadLength = (UInt32(buffer[21]) << 24) |
                                 (UInt32(buffer[22]) << 16) |
                                 (UInt32(buffer[23]) << 8) |
                                 UInt32(buffer[24])

            let maxPayload = Int(StreamChannel(rawValue: channelRaw)?.maxPayloadSize ?? VanguardProtocolConstants.maxControlPayload)
            guard Int(payloadLength) <= maxPayload else {
                buffer.removeFirst(min(VanguardProtocolConstants.headerSize, buffer.count))
                return .failure(.payloadTooLarge(channel: channelRaw, size: payloadLength, max: maxPayload))
            }

            let totalFrameSize = VanguardProtocolConstants.headerSize + Int(payloadLength)
            guard buffer.count >= totalFrameSize else {
                return nil
            }

            let frameData = buffer[0..<totalFrameSize]
            buffer.removeFirst(totalFrameSize)

            let headerResult = ProtocolHeader.parse(from: frameData)
            switch headerResult {
            case .failure:
                return .failure(.invalidFrame(reason: "Header parse failed"))
            case .success(let header):
                let payload = frameData[VanguardProtocolConstants.headerSize..<totalFrameSize]
                return .success(ProtocolFrame(header: header, payload: Data(payload)))
            }
        }
    }

    public func reset() {
        lock.withLock { buffer.removeAll(keepingCapacity: true) }
    }
}
