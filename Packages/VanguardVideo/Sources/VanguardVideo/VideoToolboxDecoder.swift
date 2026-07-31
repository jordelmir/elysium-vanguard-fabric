import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo
import VanguardDomain

public enum DecoderError: Error, Sendable, LocalizedError {
    case notConfigured
    case decoderSessionCreationFailed
    case formatDescriptionFailed
    case decodingFailed(OSStatus)
    case submitFailed(OSStatus)
    case missingPixelBuffer
    case invalidFrameData

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "Decoder not configured"
        case .decoderSessionCreationFailed: return "Failed to create decoder session"
        case .formatDescriptionFailed: return "Failed to create format description"
        case .decodingFailed(let s): return "Decoding failed: \(s)"
        case .submitFailed(let s): return "Failed to submit frame: \(s)"
        case .missingPixelBuffer: return "Decoded frame missing pixel buffer"
        case .invalidFrameData: return "Invalid frame data"
        }
    }
}

@available(macOS 10.13, *)
public final class VideoToolboxDecoder: VideoDecoderService, @unchecked Sendable {
    private let state: DecoderState
    private let lock = NSLock()

    public init() {
        self.state = DecoderState()
    }

    public func configure(sps: Data, pps: Data, width: Int, height: Int) async throws {
        if let existing = await state.getSession() {
            VTDecompressionSessionInvalidate(existing)
            await state.setSession(nil)
        }

        let formatDesc = try createFormatDescription(sps: sps, pps: pps)
        await state.setFormatDescription(formatDesc)

        let session = try createSession(formatDescription: formatDesc)
        await state.setSession(session)
    }

    public func decode(_ accessUnit: EncodedVideoAccessUnit) async throws -> DecodedVideoFrame {
        guard let session = await state.getSession() else {
            throw DecoderError.notConfigured
        }

        guard let formatDesc = await state.getFormatDescription() else {
            throw DecoderError.notConfigured
        }

        let blockBuffer = try accessUnit.avccPayload.withUnsafeBytes { ptr -> CMBlockBuffer in
            guard let baseAddress = ptr.baseAddress else {
                throw DecoderError.invalidFrameData
            }
            var blockBuffer: CMBlockBuffer?
            let status = CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: UnsafeMutableRawPointer(mutating: baseAddress),
                blockLength: accessUnit.avccPayload.count,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: accessUnit.avccPayload.count,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            guard status == noErr, let buffer = blockBuffer else {
                throw DecoderError.invalidFrameData
            }
            return buffer
        }

        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMTime(value: CMTimeValue(accessUnit.presentationTimestampNanos), timescale: 1_000_000_000),
            decodeTimeStamp: .invalid
        )

        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard sampleStatus == noErr, let sample = sampleBuffer else {
            throw DecoderError.invalidFrameData
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DecodedVideoFrame, Error>) in
            var decodeFlags: VTDecodeFrameFlags = [._EnableAsynchronousDecompression]
            var flagsOut: VTDecodeInfoFlags = []

            let context = DecodeCallbackContext(continuation: continuation, frameID: accessUnit.frameID, ptsNanos: accessUnit.presentationTimestampNanos)

            let status = VTDecompressionSessionDecodeFrame(
                session,
                sampleBuffer: sample,
                flags: decodeFlags,
                frameRefcon: Unmanaged.passRetained(context).toOpaque(),
                infoFlagsOut: &flagsOut
            )

            if status != noErr {
                continuation.resume(throwing: DecoderError.submitFailed(status))
            }
        }
    }

    public func reset() async {
        if let session = await state.getSession() {
            VTDecompressionSessionInvalidate(session)
            await state.setSession(nil)
        }
        await state.setFormatDescription(nil)
    }

    private func createFormatDescription(sps: Data, pps: Data) throws -> CMVideoFormatDescription {
        var formatDescription: CMVideoFormatDescription?

        let status = sps.withUnsafeBytes { spsPtr -> OSStatus in
            pps.withUnsafeBytes { ppsPtr -> OSStatus in
                var pointers: [UnsafePointer<UInt8>] = []
                var sizes: [Int] = []

                if let spsBase = spsPtr.baseAddress {
                    pointers.append(spsBase.assumingMemoryBound(to: UInt8.self))
                    sizes.append(sps.count)
                }
                if let ppsBase = ppsPtr.baseAddress {
                    pointers.append(ppsBase.assumingMemoryBound(to: UInt8.self))
                    sizes.append(pps.count)
                }

                return pointers.withUnsafeBufferPointer { ptrBuf -> OSStatus in
                    sizes.withUnsafeBufferPointer { sizeBuf -> OSStatus in
                        guard let ptrBase = ptrBuf.baseAddress, let sizeBase = sizeBuf.baseAddress else {
                            return -1
                        }
                        return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                            allocator: kCFAllocatorDefault,
                            parameterSetCount: ptrBuf.count,
                            parameterSetPointers: ptrBase,
                            parameterSetSizes: sizeBase,
                            nalUnitHeaderLength: 4,
                            formatDescriptionOut: &formatDescription
                        )
                    }
                }
            }
        }

        guard status == noErr, let desc = formatDescription else {
            throw DecoderError.formatDescriptionFailed
        }

        return desc
    }

    private func createSession(formatDescription: CMVideoFormatDescription) throws -> VTDecompressionSession {
        var session: VTDecompressionSession?

        var callbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: decoderCallback,
            decompressionOutputRefCon: nil
        )

        let decoderSpec: [String: Any] = [
            kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder as String: true
        ]

        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]

        let status = VTDecompressionSessionCreate(
            allocator: nil,
            formatDescription: formatDescription,
            decoderSpecification: decoderSpec as CFDictionary,
            imageBufferAttributes: pixelBufferAttrs as CFDictionary,
            outputCallback: &callbackRecord,
            decompressionSessionOut: &session
        )

        guard status == noErr, let newSession = session else {
            throw DecoderError.decoderSessionCreationFailed
        }

        return newSession
    }
}

private final class DecoderState: @unchecked Sendable {
    private var session: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?
    private let lock = NSLock()

    func getSession() -> VTDecompressionSession? { lock.withLock { session } }
    func setSession(_ s: VTDecompressionSession?) { lock.withLock { session = s } }
    func getFormatDescription() -> CMVideoFormatDescription? { lock.withLock { formatDescription } }
    func setFormatDescription(_ d: CMVideoFormatDescription?) { lock.withLock { formatDescription = d } }
}

private final class DecodeCallbackContext {
    let continuation: CheckedContinuation<DecodedVideoFrame, Error>
    let frameID: UInt64
    let ptsNanos: UInt64
    private let resolved = AtomicFlag()

    init(continuation: CheckedContinuation<DecodedVideoFrame, Error>, frameID: UInt64, ptsNanos: UInt64) {
        self.continuation = continuation
        self.frameID = frameID
        self.ptsNanos = ptsNanos
    }

    func tryResume(returning value: DecodedVideoFrame) -> Bool {
        guard resolved.compareAndSet() else { return false }
        continuation.resume(returning: value)
        return true
    }

    func tryResume(throwing error: Error) -> Bool {
        guard resolved.compareAndSet() else { return false }
        continuation.resume(throwing: error)
        return true
    }
}

private final class AtomicFlag {
    private var value: Int32 = 0

    func compareAndSet() -> Bool {
        OSAtomicCompareAndSwap32(0, 1, &value)
    }
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
    let context = Unmanaged<DecodeCallbackContext>.fromOpaque(refCon).takeRetainedValue()

    guard status == noErr else {
        context.tryResume(throwing: DecoderError.decodingFailed(status))
        return
    }

    guard let imageBuffer else {
        context.tryResume(throwing: DecoderError.missingPixelBuffer)
        return
    }

    let frame = DecodedVideoFrame(
        frameID: context.frameID,
        presentationTimestampNanos: context.ptsNanos,
        pixelBuffer: imageBuffer
    )

    _ = context.tryResume(returning: frame)
}
