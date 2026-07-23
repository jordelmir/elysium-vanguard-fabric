import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo
import VanguardDomain

// MARK: - VideoToolbox H.264 Decoder

@available(macOS 10.13, *)
public final class VideoToolboxDecoder: VideoDecoderService, @unchecked Sendable {
    private let state: DecoderState

    public init() {
        self.state = DecoderState()
    }

    public func configure(codecConfiguration: Data) async throws {
        if let existing = await state.getSession() {
            VTDecompressionSessionInvalidate(existing)
            await state.setSession(nil)
        }
    }

    public func decodeFrame(_ frame: EncodedVideoFrame) async throws -> DecodedVideoFrame {
        guard let session = await state.getSession() else {
            throw DecoderError.decoderSessionCreationFailed
        }

        let sampleBuffer = try createSampleBuffer(from: frame)

        var outputFrame: CVPixelBuffer?
        let decodeFlags: VTDecodeFrameFlags = [._EnableAsynchronousDecompression]
        var flagsOut: VTDecodeInfoFlags = []

        let status = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: decodeFlags,
            frameRefcon: nil,
            infoFlagsOut: &flagsOut
        )

        guard status == noErr else {
            throw DecoderError.decodingFailed(status: status)
        }

        guard let outputBuffer = outputFrame else {
            throw DecoderError.invalidFrameData
        }

        let width = CVPixelBufferGetWidth(outputBuffer)
        let height = CVPixelBufferGetHeight(outputBuffer)

        return DecodedVideoFrame(
            frameID: frame.frameID,
            width: width,
            height: height
        )
    }

    public func reset() async {
        if let session = await state.getSession() {
            VTDecompressionSessionInvalidate(session)
            await state.setSession(nil)
        }
        await state.setFormatDescription(nil)
    }

    // MARK: - Helpers

    private func createSampleBuffer(from frame: EncodedVideoFrame) throws -> CMSampleBuffer {
        var blockBuffer: CMBlockBuffer?
        let status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: frame.payload.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: frame.payload.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr, let buffer = blockBuffer else {
            throw DecoderError.invalidFrameData
        }

        frame.payload.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            CMBlockBufferReplaceDataBytes(with: baseAddress, blockBuffer: buffer, offsetIntoDestination: 0, dataLength: frame.payload.count)
        }

        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: buffer,
            formatDescription: nil,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard sampleStatus == noErr, let sample = sampleBuffer else {
            throw DecoderError.invalidFrameData
        }

        return sample
    }
}

// MARK: - Decoder State (safe concurrent access)

private final class DecoderState: @unchecked Sendable {
    private var session: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?
    private let lock = NSLock()

    func getSession() -> VTDecompressionSession? {
        lock.withLock { session }
    }

    func setSession(_ session: VTDecompressionSession?) {
        lock.withLock { self.session = session }
    }

    func getFormatDescription() -> CMVideoFormatDescription? {
        lock.withLock { formatDescription }
    }

    func setFormatDescription(_ description: CMVideoFormatDescription?) {
        lock.withLock { self.formatDescription = description }
    }
}
