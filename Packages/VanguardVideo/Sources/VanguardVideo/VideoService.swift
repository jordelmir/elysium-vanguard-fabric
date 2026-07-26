import Foundation
import CoreVideo
import CoreMedia
import VanguardDomain

public struct VideoCodecConfiguration: Codable, Sendable, Equatable {
    public let codec: VideoCodec
    public let revision: UInt32
    public let width: UInt32
    public let height: UInt32
    public let nalLengthSize: UInt8
    public let sps: Data
    public let pps: Data

    public init(codec: VideoCodec, revision: UInt32, width: UInt32, height: UInt32, nalLengthSize: UInt8, sps: Data, pps: Data) {
        self.codec = codec
        self.revision = revision
        self.width = width
        self.height = height
        self.nalLengthSize = nalLengthSize
        self.sps = sps
        self.pps = pps
    }
}

public struct EncodedVideoAccessUnit: Codable, Sendable, Equatable {
    public let frameID: UInt64
    public let presentationTimestampNanos: UInt64
    public let durationNanos: UInt64
    public let isKeyframe: Bool
    public let configurationRevision: UInt32
    public let avccPayload: Data

    public init(frameID: UInt64, presentationTimestampNanos: UInt64, durationNanos: UInt64, isKeyframe: Bool, configurationRevision: UInt32, avccPayload: Data) {
        self.frameID = frameID
        self.presentationTimestampNanos = presentationTimestampNanos
        self.durationNanos = durationNanos
        self.isKeyframe = isKeyframe
        self.configurationRevision = configurationRevision
        self.avccPayload = avccPayload
    }
}

public enum EncodedVideoOutput: Sendable {
    case configuration(VideoCodecConfiguration)
    case accessUnit(EncodedVideoAccessUnit)
    case configurationAndAccessUnit(VideoCodecConfiguration, EncodedVideoAccessUnit)
}

public protocol VideoEncoderService: Sendable {
    func configure(width: Int, height: Int, fps: Int, bitrate: Int) async throws
    func encode(_ frame: CapturedVideoFrame) async throws -> EncodedVideoOutput
    func requestKeyframe()
    func updateBitrate(_ bitrate: Int) async throws
    func reset() async
}

public protocol VideoDecoderService: Sendable {
    func configure(sps: Data, pps: Data, width: Int, height: Int) async throws
    func decode(_ accessUnit: EncodedVideoAccessUnit) async throws -> DecodedVideoFrame
    func reset() async
}

public struct DecodedVideoFrame: @unchecked Sendable {
    public let frameID: UInt64
    public let presentationTimestampNanos: UInt64
    public let pixelBuffer: CVPixelBuffer

    public init(frameID: UInt64, presentationTimestampNanos: UInt64, pixelBuffer: CVPixelBuffer) {
        self.frameID = frameID
        self.presentationTimestampNanos = presentationTimestampNanos
        self.pixelBuffer = pixelBuffer
    }
}
