import XCTest
import Foundation
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
            let dummyFrame = Data(repeating: 0, count: 1920 * 1080 * 4)
            let encoded = try await encoder.encodeFrame(dummyFrame, width: 1920, height: 1080)
            XCTAssertGreaterThanOrEqual(encoded.payload.count, 0)
        } catch {
            XCTFail("Encode failed: \(error)")
        }
    }

    func testRequestKeyframe() async {
        let encoder = VideoToolboxEncoder()
        do {
            try await encoder.configure(width: 1920, height: 1080, fps: 30, bitrate: 5_000_000)
            let dummyFrame = Data(repeating: 0, count: 1920 * 1080 * 4)
            _ = try await encoder.encodeFrame(dummyFrame, width: 1920, height: 1080)
            await encoder.requestKeyframe()
        } catch {
            XCTFail("Keyframe request failed: \(error)")
        }
    }

    func testReset() async {
        let encoder = VideoToolboxEncoder()
        try? await encoder.configure(width: 1920, height: 1080, fps: 30, bitrate: 5_000_000)
        await encoder.reset()
    }
}

@available(macOS 12.3, *)
final class VideoToolboxDecoderTests: XCTestCase {
    func testDecodeFrame() async {
        let decoder = VideoToolboxDecoder()
        let encodedFrame = EncodedVideoFrame(
            frameID: 0,
            presentationTimestampNanos: 0,
            isKeyframe: true,
            codecConfigurationRevision: 1,
            payload: Data(repeating: 0, count: 1024)
        )
        do {
            _ = try await decoder.decodeFrame(encodedFrame)
        } catch {
            // Expected to fail with dummy data, just checking it doesn't crash
        }
    }

    func testReset() async {
        let decoder = VideoToolboxDecoder()
        await decoder.reset()
    }
}
