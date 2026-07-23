import Foundation

extension Data {
    mutating func appendUInt8(_ value: UInt8) {
        append(value)
    }

    mutating func appendUInt16(_ value: UInt16) {
        var big = value.bigEndian
        Swift.withUnsafeBytes(of: &big) { rawPtr in
            append(contentsOf: rawPtr)
        }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var big = value.bigEndian
        Swift.withUnsafeBytes(of: &big) { rawPtr in
            append(contentsOf: rawPtr)
        }
    }

    mutating func appendUInt64(_ value: UInt64) {
        var big = value.bigEndian
        Swift.withUnsafeBytes(of: &big) { rawPtr in
            append(contentsOf: rawPtr)
        }
    }

    mutating func writeUInt16(_ value: UInt16, at offset: Int) {
        var big = value.bigEndian
        Swift.withUnsafeBytes(of: &big) { rawPtr in
            for i in 0..<2 {
                self[offset + i] = rawPtr[i]
            }
        }
    }

    func readUInt8(at offset: Int) -> UInt8 {
        return self[offset]
    }

    func readUInt16(at offset: Int) -> UInt16 {
        return (UInt16(self[offset]) << 8) | UInt16(self[offset + 1])
    }

    func readUInt32(at offset: Int) -> UInt32 {
        return (UInt32(self[offset]) << 24) |
               (UInt32(self[offset + 1]) << 16) |
               (UInt32(self[offset + 2]) << 8) |
               UInt32(self[offset + 3])
    }

    func readUInt64(at offset: Int) -> UInt64 {
        return (UInt64(self[offset]) << 56) |
               (UInt64(self[offset + 1]) << 48) |
               (UInt64(self[offset + 2]) << 40) |
               (UInt64(self[offset + 3]) << 32) |
               (UInt64(self[offset + 4]) << 24) |
               (UInt64(self[offset + 5]) << 16) |
               (UInt64(self[offset + 6]) << 8) |
               UInt64(self[offset + 7])
    }
}
