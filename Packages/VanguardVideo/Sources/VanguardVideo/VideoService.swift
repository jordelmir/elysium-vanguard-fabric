import Foundation
import VanguardDomain

// MARK: - Video Encoder Service Protocol

public protocol VideoEncoderService: Sendable {
    func configure(width: Int, height: Int, fps: Int, bitrate: Int) async throws
    func encodeFrame(_ frame: Data, width: Int, height: Int) async throws -> EncodedVideoFrame
    func requestKeyframe() async
    func reset() async
}

// MARK: - Video Decoder Service Protocol

public protocol VideoDecoderService: Sendable {
    func configure(codecConfiguration: Data) async throws
    func decodeFrame(_ frame: EncodedVideoFrame) async throws -> DecodedVideoFrame
    func reset() async
}

// MARK: - Video Service Protocol

public protocol VideoService: Sendable {
    func startEncoding(
        width: Int,
        height: Int,
        fps: Int,
        bitrate: Int
    ) async throws -> AsyncThrowingStream<EncodedVideoFrame, Error>
    func stopEncoding() async
    func configureDecoder(codecConfiguration: Data) async throws
    func decodeNextFrame() async throws -> DecodedVideoFrame
    func requestKeyframe() async
}
