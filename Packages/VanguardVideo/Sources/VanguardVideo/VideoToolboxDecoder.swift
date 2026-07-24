import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo
import VanguardDomain

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

        let formatDescription = try createFormatDescription(from: codecConfiguration)
        await state.setFormatDescription(formatDescription)

        let session = try createSession(formatDescription: formatDescription)
        await state.setSession(session)
    }

    public func decodeFrame(_ frame: EncodedVideoFrame) async throws -> DecodedVideoFrame {
        guard let session = await state.getSession() else {
            throw DecoderError.decoderSessionCreationFailed
        }

        guard let formatDesc = await state.getFormatDescription() else {
            throw DecoderError.decoderSessionCreationFailed
        }

        let context = DecodeContext()

        let blockBuffer = try frame.payload.withUnsafeBytes { ptr -> CMBlockBuffer in
            guard let baseAddress = ptr.baseAddress else {
                throw DecoderError.invalidFrameData
            }
            var blockBuffer: CMBlockBuffer?
            let status = CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: UnsafeMutableRawPointer(mutating: baseAddress),
                blockLength: frame.payload.count,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: frame.payload.count,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            guard status == noErr, let buffer = blockBuffer else {
                throw DecoderError.invalidFrameData
            }
            return buffer
        }

        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDesc,
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

        let decodeFlags: VTDecodeFrameFlags = [._EnableAsynchronousDecompression]
        var flagsOut: VTDecodeInfoFlags = []

        let status = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sample,
            flags: decodeFlags,
            frameRefcon: Unmanaged.passRetained(context).toOpaque(),
            infoFlagsOut: &flagsOut
        )

        guard status == noErr else {
            throw DecoderError.decodingFailed(status: status)
        }

        guard let outputBuffer = context.outputPixelBuffer else {
            throw DecoderError.invalidFrameData
        }

        await state.setLastDecodedPixelBuffer(outputBuffer)

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
        await state.setLastDecodedPixelBuffer(nil)
    }

    public func getLastDecodedPixelBuffer() async -> CVPixelBuffer? {
        await state.getLastDecodedPixelBuffer()
    }

    private func createFormatDescription(from configData: Data) throws -> CMVideoFormatDescription {
        var formatDescription: CMVideoFormatDescription?

        let nalUnits = extractNALUnits(from: configData)
        var spsData: Data?
        var ppsData: Data?

        for nal in nalUnits {
            let nalType = nal[0] & 0x1F
            if nalType == 7 {
                spsData = Data(nal)
            } else if nalType == 8 {
                ppsData = Data(nal)
            }
        }

        guard let sps = spsData, let pps = ppsData else {
            throw DecoderError.decoderSessionCreationFailed
        }

        let status = sps.withUnsafeBytes { spsPtr -> OSStatus in
            pps.withUnsafeBytes { ppsPtr -> OSStatus in
                var parameterSetPointers: [UnsafePointer<UInt8>] = []
                var parameterSetSizes: [Int] = []

                if let spsBase = spsPtr.baseAddress {
                    parameterSetPointers.append(spsBase.assumingMemoryBound(to: UInt8.self))
                    parameterSetSizes.append(sps.count)
                }
                if let ppsBase = ppsPtr.baseAddress {
                    parameterSetPointers.append(ppsBase.assumingMemoryBound(to: UInt8.self))
                    parameterSetSizes.append(pps.count)
                }

                return parameterSetPointers.withUnsafeBufferPointer { pointersPtr -> OSStatus in
                    parameterSetSizes.withUnsafeBufferPointer { sizesPtr -> OSStatus in
                        CMVideoFormatDescriptionCreateFromH264ParameterSets(
                            allocator: kCFAllocatorDefault,
                            parameterSetCount: pointersPtr.count,
                            parameterSetPointers: pointersPtr.baseAddress!,
                            parameterSetSizes: sizesPtr.baseAddress!,
                            nalUnitHeaderLength: 4,
                            formatDescriptionOut: &formatDescription
                        )
                    }
                }
            }
        }

        guard status == noErr, let desc = formatDescription else {
            throw DecoderError.decoderSessionCreationFailed
        }

        return desc
    }

    private func createSession(formatDescription: CMVideoFormatDescription) throws -> VTDecompressionSession {
        var session: VTDecompressionSession?

        var callbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: decoderCallback,
            decompressionOutputRefCon: nil
        )

        let videoDecoderSpecification: [String: Any] = [
            kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder as String: true
        ]

        let status = VTDecompressionSessionCreate(
            allocator: nil,
            formatDescription: formatDescription,
            decoderSpecification: videoDecoderSpecification as CFDictionary,
            imageBufferAttributes: nil,
            outputCallback: &callbackRecord,
            decompressionSessionOut: &session
        )

        guard status == noErr, let newSession = session else {
            throw DecoderError.decoderSessionCreationFailed
        }

        return newSession
    }

    private func extractNALUnits(from data: Data) -> [[UInt8]] {
        var units: [[UInt8]] = []
        var i = 0
        let bytes = [UInt8](data)

        while i < bytes.count - 3 {
            if bytes[i] == 0 && bytes[i + 1] == 0 {
                if bytes[i + 2] == 1 {
                    let start = i + 3
                    if start < bytes.count {
                        var end = start
                        while end < bytes.count - 2 {
                            if bytes[end] == 0 && bytes[end + 1] == 0 && (bytes[end + 2] == 1 || bytes[end + 2] == 0) {
                                break
                            }
                            end += 1
                        }
                        if end >= bytes.count - 2 { end = bytes.count }
                        units.append(Array(bytes[start..<end]))
                    }
                    i += 3
                } else {
                    i += 2
                }
            } else {
                i += 1
            }
        }

        return units
    }
}

private final class DecoderState: @unchecked Sendable {
    private var session: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?
    private var lastDecodedPixelBuffer: CVPixelBuffer?
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

    func getLastDecodedPixelBuffer() -> CVPixelBuffer? {
        lock.withLock { lastDecodedPixelBuffer }
    }

    func setLastDecodedPixelBuffer(_ buffer: CVPixelBuffer?) {
        lock.withLock { self.lastDecodedPixelBuffer = buffer }
    }
}

private final class DecodeContext {
    var outputPixelBuffer: CVPixelBuffer?
}

@available(macOS 10.13, *)
private func decoderCallback(
    decompressionOutputRefCon: UnsafeMutableRawPointer?,
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTDecodeInfoFlags,
    imageBuffer: CVImageBuffer?,
    presentationTimeStamp: CMTime,
    presentationDuration: CMTime
) {
    guard let refCon = sourceFrameRefCon else { return }
    let context = Unmanaged<DecodeContext>.fromOpaque(refCon).takeRetainedValue()
    guard status == noErr else { return }
    context.outputPixelBuffer = imageBuffer
}
