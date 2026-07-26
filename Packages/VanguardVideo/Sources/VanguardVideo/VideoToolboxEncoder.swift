import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo
import VanguardDomain

public enum EncoderError: Error, Sendable, LocalizedError {
    case encoderSessionCreationFailed
    case encodingFailed(status: OSStatus)
    case pixelBufferCreationFailed
    case parameterSetExtractionFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .encoderSessionCreationFailed: return "Failed to create encoder session"
        case .encodingFailed(let s): return "Encoding failed: \(s)"
        case .pixelBufferCreationFailed: return "Failed to create pixel buffer"
        case .parameterSetExtractionFailed(let s): return "Failed to extract SPS/PPS: \(s)"
        }
    }
}

@available(macOS 10.13, *)
public final class VideoToolboxEncoder: VideoEncoderService, @unchecked Sendable {
    private let state: EncoderState
    private var frameID: UInt64 = 0
    private var codecConfigRevision: UInt32 = 1
    private let lock = NSLock()
    private var _currentBitrate: Int = 5_000_000
    private var _currentFPS: Int = 30
    private var _forceNextKeyframe = false
    private var _currentConfig: VideoCodecConfiguration?

    public var currentBitrate: Int {
        lock.withLock { _currentBitrate }
    }

    public init() {
        self.state = EncoderState()
    }

    public func configure(width: Int, height: Int, fps: Int, bitrate: Int) async throws {
        if let existing = await state.getSession() {
            VTCompressionSessionInvalidate(existing)
            await state.setSession(nil)
        }

        lock.withLock {
            _currentBitrate = bitrate
            _currentFPS = fps
        }

        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: nil,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: [kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder: true] as CFDictionary,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: encoderCallback,
            refcon: nil,
            compressionSessionOut: &session
        )

        guard status == noErr, let session else {
            throw EncoderError.encoderSessionCreationFailed
        }

        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_High_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: NSNumber(value: bitrate))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: fps * 2))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: NSNumber(value: fps))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_H264EntropyMode, value: kVTH264EntropyMode_CABAC)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: NSNumber(value: 2))

        VTCompressionSessionPrepareToEncodeFrames(session)
        await state.setSession(session)
        codecConfigRevision += 1
    }

    public func encode(_ frame: CapturedVideoFrame) async throws -> EncodedVideoOutput {
        guard let session = await state.getSession() else {
            throw EncoderError.encoderSessionCreationFailed
        }

        frameID += 1
        let currentFrameID = frameID

        let shouldForce = lock.withLock {
            defer { _forceNextKeyframe = false }
            return _forceNextKeyframe
        }

        var frameProperties: CFDictionary? = nil
        if shouldForce {
            frameProperties = [kVTEncodeFrameOptionKey_ForceKeyFrame as String: true] as CFDictionary
        }

        let encodeResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<EncodeResult, Error>) in
            VTCompressionSessionEncodeFrame(
                session,
                imageBuffer: frame.pixelBuffer,
                presentationTimeStamp: frame.presentationTimeStamp,
                duration: .invalid,
                frameProperties: frameProperties,
                sourceFrameRefcon: Unmanaged.passRetained(EncodeContext(continuation: continuation, frameID: currentFrameID)).toOpaque(),
                infoFlagsOut: nil
            )
        }

        let accessUnit = EncodedVideoAccessUnit(
            frameID: currentFrameID,
            presentationTimestampNanos: UInt64(CMTimeGetSeconds(frame.presentationTimeStamp) * 1_000_000_000),
            durationNanos: 0,
            isKeyframe: encodeResult.isKeyframe,
            configurationRevision: codecConfigRevision,
            avccPayload: encodeResult.data
        )

        if encodeResult.isKeyframe, let config = try? extractSPSPPS(from: encodeResult.sampleBuffer) {
            lock.withLock { _currentConfig = config }
            return .configurationAndAccessUnit(config, accessUnit)
        }

        if let existingConfig = lock.withLock({ _currentConfig }) {
            return .accessUnit(accessUnit)
        }

        if let config = try? extractSPSPPS(from: encodeResult.sampleBuffer) {
            lock.withLock { _currentConfig = config }
            return .configurationAndAccessUnit(config, accessUnit)
        }

        return .accessUnit(accessUnit)
    }

    public func requestKeyframe() {
        lock.withLock { _forceNextKeyframe = true }
    }

    public func updateBitrate(_ newBitrate: Int) async throws {
        guard let session = await state.getSession() else { return }
        lock.withLock { _currentBitrate = newBitrate }
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: NSNumber(value: newBitrate))
    }

    public func reset() async {
        if let session = await state.getSession() {
            VTCompressionSessionInvalidate(session)
            await state.setSession(nil)
        }
        frameID = 0
        codecConfigRevision += 1
        lock.withLock {
            _forceNextKeyframe = false
            _currentConfig = nil
        }
    }

    private func extractFormatDescription(session: VTCompressionSession) async throws -> CMSampleBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)

        guard let buffer = pixelBuffer else { return nil }

        var sampleBuffer: CMSampleBuffer?
        var formatDesc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &formatDesc)

        guard let desc = formatDesc else { return nil }

        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 600),
            presentationTimeStamp: .zero,
            decodeTimeStamp: .zero
        )

        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescription: desc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }

    private func extractSPSPPS(from sampleBuffer: CMSampleBuffer) throws -> VideoCodecConfiguration? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }

        var spsPointer: UnsafePointer<UInt8>?
        var spsSize = 0
        var spsCount = 0
        var nalHeaderLength: Int32 = 0

        let spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDesc,
            parameterSetIndex: 0,
            parameterSetPointerOut: &spsPointer,
            parameterSetSizeOut: &spsSize,
            parameterSetCountOut: &spsCount,
            nalUnitHeaderLengthOut: &nalHeaderLength
        )

        guard spsStatus == noErr, let spsPointer else {
            throw EncoderError.parameterSetExtractionFailed(spsStatus)
        }

        var ppsPointer: UnsafePointer<UInt8>?
        var ppsSize = 0

        let ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDesc,
            parameterSetIndex: 1,
            parameterSetPointerOut: &ppsPointer,
            parameterSetSizeOut: &ppsSize,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        )

        guard ppsStatus == noErr, let ppsPointer else {
            throw EncoderError.parameterSetExtractionFailed(ppsStatus)
        }

        let sps = Data(bytes: spsPointer, count: spsSize)
        let pps = Data(bytes: ppsPointer, count: ppsSize)

        let dims = CMVideoFormatDescriptionGetDimensions(formatDesc)

        return VideoCodecConfiguration(
            codec: .h264,
            revision: codecConfigRevision,
            width: UInt32(dims.width),
            height: UInt32(dims.height),
            nalLengthSize: UInt8(nalHeaderLength),
            sps: sps,
            pps: pps
        )
    }
}

private final class EncoderState: @unchecked Sendable {
    private var session: VTCompressionSession?
    private let lock = NSLock()

    func getSession() -> VTCompressionSession? {
        lock.withLock { session }
    }

    func setSession(_ session: VTCompressionSession?) {
        lock.withLock { self.session = session }
    }
}

private final class EncodeContext {
    let continuation: CheckedContinuation<EncodeResult, Error>
    let frameID: UInt64

    init(continuation: CheckedContinuation<EncodeResult, Error>, frameID: UInt64) {
        self.continuation = continuation
        self.frameID = frameID
    }
}

private struct EncodeResult: @unchecked Sendable {
    let data: Data
    let sampleBuffer: CMSampleBuffer
    let isKeyframe: Bool
}

@available(macOS 10.13, *)
private func encoderCallback(
    outputCallbackRefCon: UnsafeMutableRawPointer?,
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTEncodeInfoFlags,
    sampleBuffer: CMSampleBuffer?
) {
    guard let sourceFrameRefCon else { return }

    let context = Unmanaged<EncodeContext>.fromOpaque(sourceFrameRefCon).takeRetainedValue()

    guard status == noErr,
          let sampleBuffer,
          let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
        context.continuation.resume(throwing: EncoderError.encodingFailed(status: status))
        return
    }

    var totalLength = 0
    var dataPointer: UnsafeMutablePointer<Int8>?
    CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)

    guard let dataPointer else {
        context.continuation.resume(throwing: EncoderError.encodingFailed(status: -1))
        return
    }

    let isKeyframe = CMGetAttachment(sampleBuffer, key: kCMSampleAttachmentKey_DependsOnOthers, attachmentModeOut: nil) == nil
    let data = Data(bytes: dataPointer, count: totalLength)

    context.continuation.resume(returning: EncodeResult(data: data, sampleBuffer: sampleBuffer, isKeyframe: isKeyframe))
}
