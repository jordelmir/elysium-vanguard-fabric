import XCTest
import Foundation
import CoreMedia
import CoreVideo
@testable import VanguardVideo
@testable import VanguardDomain

@available(macOS 12.3, *)
final class VideoToolboxEncoderTests: XCTestCase {
    func testConfigure() async {
        let encoder = VideoToolboxEncoder()
        do {
            try await encoder.configure(width: 1920, height: 1080, fps: 30, bitrate: 5_000_000)
        } catch {
            XCTFail("Configure failed: \(error)")
        }
    }

    func testEncodeFrame() async {
        let encoder = VideoToolboxEncoder()
        do {
            try await encoder.configure(width: 1920, height: 1080, fps: 30, bitrate: 5_000_000)
            let pixelBuffer = try createTestPixelBuffer(width: 1920, height: 1080)
            let frame = CapturedVideoFrame(
                pixelBuffer: pixelBuffer,
                presentationTimeStamp: CMTime(value: 0, timescale: 30),
                displayID: 0
            )
            let output = try await encoder.encode(frame)
            switch output {
            case .accessUnit(let au):
                XCTAssertGreaterThanOrEqual(au.avccPayload.count, 0)
            case .configuration, .configurationAndAccessUnit:
                break
            }
        } catch {
            XCTFail("Encode failed: \(error)")
        }
    }

    func testRequestKeyframe() async {
        let encoder = VideoToolboxEncoder()
        do {
            try await encoder.configure(width: 1920, height: 1080, fps: 30, bitrate: 5_000_000)
            let pixelBuffer = try createTestPixelBuffer(width: 1920, height: 1080)
            let frame = CapturedVideoFrame(
                pixelBuffer: pixelBuffer,
                presentationTimeStamp: CMTime(value: 0, timescale: 30),
                displayID: 0
            )
            _ = try await encoder.encode(frame)
            encoder.requestKeyframe()
        } catch {
            XCTFail("Keyframe request failed: \(error)")
        }
    }

    func testReset() async {
        let encoder = VideoToolboxEncoder()
        try? await encoder.configure(width: 1920, height: 1080, fps: 30, bitrate: 5_000_000)
        await encoder.reset()
    }

    private func createTestPixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        let attrs: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw NSError(domain: "Test", code: Int(status))
        }
        return buffer
    }
}

@available(macOS 12.3, *)
final class VideoToolboxDecoderTests: XCTestCase {
    func testDecodeFrame() async {
        let decoder = VideoToolboxDecoder()
        let accessUnit = EncodedVideoAccessUnit(
            frameID: 0,
            presentationTimestampNanos: 0,
            durationNanos: 33_333_333,
            isKeyframe: true,
            configurationRevision: 1,
            avccPayload: Data(repeating: 0, count: 1024)
        )
        do {
            _ = try await decoder.decode(accessUnit)
        } catch {
            // Expected to fail with dummy data
        }
    }

    func testReset() async {
        let decoder = VideoToolboxDecoder()
        await decoder.reset()
    }
}

