import Foundation
import Network
import os.log
import VanguardDomain

private let stunLogger = Logger(subsystem: "ElysiumVanguard", category: "STUN")

// MARK: - STUN Message Types (RFC 5389)

public enum STUNMethod: UInt16, Sendable {
    case binding = 0x0001
}

public enum STUNClass: UInt8, Sendable {
    case request = 0x00
    case indication = 0x10
    case successResponse = 0x01
    case errorResponse = 0x11
}

// MARK: - STUN Attribute

public enum STUNAttribute: Sendable, Equatable {
    case mappedAddress(STUNAddress)
    case xorMappedAddress(STUNAddress)
    case username(String)
    case software(String)
    case errorCode(UInt16, String)
    case fingerprint(UInt32)
    case unknown(UInt16, Data)

    public var typeValue: UInt16 {
        switch self {
        case .mappedAddress: return 0x0001
        case .xorMappedAddress: return 0x8020
        case .username: return 0x0006
        case .software: return 0x8022
        case .errorCode: return 0x0009
        case .fingerprint: return 0x8028
        case .unknown(let type, _): return type
        }
    }

    public var serializedLength: Int {
        switch self {
        case .mappedAddress, .xorMappedAddress:
            return 4 + 8
        case .username(let name):
            let nameLen = name.utf8.count
            return 4 + ((nameLen + 3) & ~3)
        case .software(let sw):
            let swLen = sw.utf8.count
            return 4 + ((swLen + 3) & ~3)
        case .errorCode(_, let msg):
            let msgLen = msg.utf8.count
            return 4 + 4 + ((msgLen + 3) & ~3)
        case .fingerprint:
            return 4 + 4
        case .unknown(_, let data):
            return 4 + data.count
        }
    }

    public func serialize() -> Data {
        var data = Data()
        let typeBytes = typeValue.bigEndianBytes
        data.append(typeBytes[0])
        data.append(typeBytes[1])

        switch self {
        case .mappedAddress(let addr), .xorMappedAddress(let addr):
            let body = serializeAddress(addr)
            let lenBytes = UInt16(body.count).bigEndianBytes
            data.append(lenBytes[0])
            data.append(lenBytes[1])
            data.append(body)
        case .username(let name):
            var nameData = Data(name.utf8)
            let paddedLen = (nameData.count + 3) & ~3
            nameData.append(contentsOf: [UInt8](repeating: 0, count: paddedLen - nameData.count))
            let lenBytes = UInt16(nameData.count).bigEndianBytes
            data.append(lenBytes[0])
            data.append(lenBytes[1])
            data.append(nameData)
        case .software(let sw):
            var swData = Data(sw.utf8)
            let paddedLen = (swData.count + 3) & ~3
            swData.append(contentsOf: [UInt8](repeating: 0, count: paddedLen - swData.count))
            let lenBytes = UInt16(swData.count).bigEndianBytes
            data.append(lenBytes[0])
            data.append(lenBytes[1])
            data.append(swData)
        case .errorCode(let code, let msg):
            var body = Data()
            let reservedBytes = UInt16(0).bigEndianBytes
            body.append(reservedBytes[0])
            body.append(reservedBytes[1])
            body.append(UInt8(code >> 8))
            body.append(UInt8(code & 0xFF))
            var msgData = Data(msg.utf8)
            let paddedLen = (msgData.count + 3) & ~3
            msgData.append(contentsOf: [UInt8](repeating: 0, count: paddedLen - msgData.count))
            body.append(msgData)
            let lenBytes = UInt16(body.count).bigEndianBytes
            data.append(lenBytes[0])
            data.append(lenBytes[1])
            data.append(body)
        case .fingerprint(let crc):
            let lenBytes = UInt16(4).bigEndianBytes
            data.append(lenBytes[0])
            data.append(lenBytes[1])
            let crcBytes = crc.bigEndianBytes
            data.append(crcBytes[0])
            data.append(crcBytes[1])
            data.append(crcBytes[2])
            data.append(crcBytes[3])
        case .unknown(_, let unknownData):
            let lenBytes = UInt16(unknownData.count).bigEndianBytes
            data.append(lenBytes[0])
            data.append(lenBytes[1])
            data.append(unknownData)
        }
        return data
    }

    private func serializeAddress(_ addr: STUNAddress) -> Data {
        var body = Data()
        body.append(0x00)
        body.append(0x01)
        let portBytes = addr.port.bigEndianBytes
        body.append(portBytes[0])
        body.append(portBytes[1])
        let parts = addr.ip.split(separator: ".")
        for part in parts {
            body.append(UInt8(part) ?? 0)
        }
        if parts.count < 4 {
            body.append(contentsOf: [UInt8](repeating: 0, count: 4 - parts.count))
        }
        return body
    }

    public static func parse(type: UInt16, data: Data) -> STUNAttribute? {
        switch type {
        case 0x0001:
            guard data.count >= 8 else { return nil }
            let port = UInt16(data[2]) << 8 | UInt16(data[3])
            let ip = "\(data[4]).\(data[5]).\(data[6]).\(data[7])"
            return .mappedAddress(STUNAddress(ip: ip, port: port))
        case 0x8020:
            guard data.count >= 8 else { return nil }
            let port = UInt16(data[2]) << 8 | UInt16(data[3])
            let ip = "\(data[4]).\(data[5]).\(data[6]).\(data[7])"
            return .xorMappedAddress(STUNAddress(ip: ip, port: port))
        case 0x0006:
            let name = String(data: data, encoding: .utf8) ?? ""
            return .username(name.trimmingCharacters(in: CharacterSet(charactersIn: "\0")))
        case 0x8022:
            let sw = String(data: data, encoding: .utf8) ?? ""
            return .software(sw.trimmingCharacters(in: CharacterSet(charactersIn: "\0")))
        case 0x0009:
            guard data.count >= 4 else { return nil }
            let code = UInt16(data[2]) << 8 | UInt16(data[3])
            let msg = String(data: data[4...], encoding: .utf8) ?? ""
            return .errorCode(code, msg.trimmingCharacters(in: CharacterSet(charactersIn: "\0")))
        case 0x8028:
            guard data.count >= 4 else { return nil }
            let crc = UInt32(data[0]) << 24 | UInt32(data[1]) << 16 | UInt32(data[2]) << 8 | UInt32(data[3])
            return .fingerprint(crc)
        default:
            return .unknown(type, data)
        }
    }
}

// MARK: - STUN Message

public struct STUNMessage: Sendable, Equatable {
    public let stunClass: STUNClass
    public let method: STUNMethod
    public let transactionID: Data
    public let attributes: [STUNAttribute]

    public init(stunClass: STUNClass, method: STUNMethod, transactionID: Data, attributes: [STUNAttribute] = []) {
        self.stunClass = stunClass
        self.method = method
        self.transactionID = transactionID
        self.attributes = attributes
    }

    public static func bindingRequest() -> STUNMessage {
        var txID = Data(count: 12)
        _ = txID.withUnsafeMutableBytes { ptr in
            if let base = ptr.baseAddress {
                SecRandomCopyBytes(kSecRandomDefault, 12, base)
            }
        }
        return STUNMessage(stunClass: .request, method: .binding, transactionID: txID)
    }

    public func toData() -> Data {
        var data = Data()
        let typeRaw: UInt16 = (UInt16(stunClass.rawValue) << 14) | method.rawValue
        let typeBytes = typeRaw.bigEndianBytes
        data.append(typeBytes[0])
        data.append(typeBytes[1])

        let bodyLength = attributes.reduce(0) { $0 + $1.serializedLength }
        let paddedLength = (bodyLength + 3) & ~3
        let lenBytes = UInt16(paddedLength).bigEndianBytes
        data.append(lenBytes[0])
        data.append(lenBytes[1])

        data.append(contentsOf: [0x21, 0x12, 0xA4, 0x42])
        data.append(transactionID)

        for attr in attributes {
            data.append(attr.serialize())
        }
        let paddingNeeded = paddedLength - bodyLength
        if paddingNeeded > 0 {
            data.append(contentsOf: [UInt8](repeating: 0, count: paddingNeeded))
        }
        return data
    }

    public static func parse(from data: Data) -> STUNMessage? {
        guard data.count >= 20 else { return nil }
        let firstWord = UInt16(data[data.startIndex]) << 8 | UInt16(data[data.startIndex + 1])
        let stunClassRaw = UInt8((firstWord >> 14) & 0x03)
        let methodRaw = UInt16(firstWord & 0x3FFF)
        guard let stunClass = STUNClass(rawValue: stunClassRaw),
              let method = STUNMethod(rawValue: methodRaw) else { return nil }
        let magicCookie = data[(data.startIndex + 4)...(data.startIndex + 7)]
        guard magicCookie == Data([0x21, 0x12, 0xA4, 0x42]) else { return nil }
        let txID = Data(data[(data.startIndex + 8)...(data.startIndex + 19)])
        let bodyLength = Int(UInt16(data[data.startIndex + 2]) << 8 | UInt16(data[data.startIndex + 3]))
        var attributes: [STUNAttribute] = []
        var offset = data.startIndex + 20
        let endIndex = data.startIndex + 20 + bodyLength
        while offset < endIndex, offset + 4 <= data.endIndex {
            let attrType = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
            let attrLength = Int(UInt16(data[offset + 2]) << 8 | UInt16(data[offset + 3]))
            offset += 4
            guard offset + attrLength <= data.endIndex else { break }
            let attrData = data[offset..<(offset + attrLength)]
            if let attr = STUNAttribute.parse(type: attrType, data: Data(attrData)) {
                attributes.append(attr)
            }
            let paddedLen = (attrLength + 3) & ~3
            offset += paddedLen
        }
        return STUNMessage(stunClass: stunClass, method: method, transactionID: txID, attributes: attributes)
    }

    public func getMappedAddress() -> STUNAddress? {
        for attr in attributes {
            switch attr {
            case .mappedAddress(let addr), .xorMappedAddress(let addr):
                return addr
            default:
                continue
            }
        }
        return nil
    }
}

// MARK: - Helpers

extension UInt16 {
    var bigEndianBytes: [UInt8] {
        [UInt8(self >> 8), UInt8(self & 0xFF)]
    }
}

extension UInt32 {
    var bigEndianBytes: [UInt8] {
        [UInt8((self >> 24) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 8) & 0xFF), UInt8(self & 0xFF)]
    }
}

extension UInt64 {
    var bigEndianBytes: [UInt8] {
        [
            UInt8((self >> 56) & 0xFF), UInt8((self >> 48) & 0xFF),
            UInt8((self >> 40) & 0xFF), UInt8((self >> 32) & 0xFF),
            UInt8((self >> 24) & 0xFF), UInt8((self >> 16) & 0xFF),
            UInt8((self >> 8) & 0xFF), UInt8(self & 0xFF)
        ]
    }
}
