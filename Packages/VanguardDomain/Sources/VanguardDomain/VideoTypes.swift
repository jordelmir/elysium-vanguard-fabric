import Foundation

// MARK: - Decoded Video Frame

public struct DecodedVideoFrame: Sendable {
    public let frameID: UInt64
    public let width: Int
    public let height: Int

    public init(frameID: UInt64, width: Int, height: Int) {
        self.frameID = frameID
        self.width = width
        self.height = height
    }
}
