import Foundation
import VideoToolbox
import CoreMedia
import VanguardDomain

@available(macOS 10.13, *)
public final class VideoToolboxEncoder: VideoEncoderService, @unchecked Sendable {
    private let state: EncoderState
    private var frameID: UInt64 = 0
    private var codecConfigRevision: UInt32 = 1
    private let lock = NSLock()
    private var _currentBitrate: Int = 5_000_000
    private var _currentFPS: Int = 60

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
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: fps * 4))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: NSNumber(value: fps))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_H264EntropyMode, value: kVTH264EntropyMode_CABAC)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: NSNumber(value: 4))

        VTCompressionSessionPrepareToEncodeFrames(session)
        await state.setSession(session)
        codecConfigRevision += 1
    }

    public func encodeFrame(_ frame: Data, width: Int, height: Int) async throws -> EncodedVideoFrame {
        guard let session = await state.getSession() else {
            throw EncoderError.encoderSessionCreationFailed
        }

        frameID += 1
        let currentFrameID = frameID

        let pixelBuffer = try createPixelBuffer(from: frame, width: width, height: height)

        let encodeResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, Bool), Error>) in
            VTCompressionSessionEncodeFrame(
                session,
                imageBuffer: pixelBuffer,
                presentationTimeStamp: CMTime(value: CMTimeValue(currentFrameID), timescale: 600),
                duration: .invalid,
                frameProperties: nil,
                sourceFrameRefcon: Unmanaged.passRetained(EncodeContext(continuation: continuation, frameID: currentFrameID)).toOpaque(),
                infoFlagsOut: nil
            )
        }

        return EncodedVideoFrame(
            frameID: currentFrameID,
            presentationTimestampNanos: UInt64(currentFrameID) * 1_000_000_000 / 600,
            isKeyframe: encodeResult.1,
            codecConfigurationRevision: codecConfigRevision,
            payload: encodeResult.0
        )
    }

    public func requestKeyframe() async {
        guard let session = await state.getSession() else { return }
        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
    }

    public func updateBitrate(_ newBitrate: Int) async {
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
    }

    private func createPixelBuffer(from frame: Data, width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ] as CFDictionary

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )

        guard status == noErr, let buffer = pixelBuffer else {
            throw EncoderError.invalidPixelBuffer
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw EncoderError.invalidPixelBuffer
        }

        frame.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            guard let dataProvider = CGDataProvider(dataInfo: nil, data: baseAddress, size: frame.count, releaseData: { _, _, _ in }) else { return }
            if let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo,
                provider: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            ) {
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }

        return buffer
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
    let continuation: CheckedContinuation<(Data, Bool), Error>
    let frameID: UInt64

    init(continuation: CheckedContinuation<(Data, Bool), Error>, frameID: UInt64) {
        self.continuation = continuation
        self.frameID = frameID
    }
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

    context.continuation.resume(returning: (data, isKeyframe))
}
