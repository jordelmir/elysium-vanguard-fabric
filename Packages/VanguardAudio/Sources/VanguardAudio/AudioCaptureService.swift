import Foundation
import AVFoundation
import os.log

public struct AudioDevice: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let isDefault: Bool
}

public actor AudioCaptureService {
    private var audioEngine: AVAudioEngine?
    private var isCapturing = false
    private var outputFormat: AVAudioFormat?
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Audio")

    nonisolated(unsafe) public var onAudioCaptured: (@Sendable (Data) -> Void)?

    public init() {}

    public func startCapture(sampleRate: Double = 44100, channels: Int = 2) async throws {
        guard !isCapturing else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        )

        guard let format else {
            throw AudioCaptureError.invalidFormat
        }

        outputFormat = format

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            let data = AudioCaptureService.convertBufferToData(buffer)
            self.onAudioCaptured?(data)
        }

        try engine.start()
        audioEngine = engine
        isCapturing = true
        logger.info("Audio capture started: \(sampleRate)Hz \(channels)ch")
    }

    public func stopCapture() async {
        guard isCapturing, let engine = audioEngine else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        audioEngine = nil
        isCapturing = false
        logger.info("Audio capture stopped")
    }

    public func getAvailableInputDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone],
            mediaType: .audio,
            position: .unspecified
        )

        for device in discoverySession.devices {
            devices.append(AudioDevice(
                id: device.uniqueID,
                name: device.localizedName,
                isDefault: device == AVCaptureDevice.default(for: .audio)
            ))
        }

        return devices
    }

    public func setVolume(_ volume: Float) async {
        let _ = min(max(volume, 0.0), 1.0)
    }

    public func getVolume() -> Float {
        return 1.0
    }

    private static func convertBufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        guard let channelData = buffer.floatChannelData else { return Data() }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        let bytesPerFrame = MemoryLayout<Float>.size

        var data = Data(count: frameLength * channelCount * bytesPerFrame)
        data.withUnsafeMutableBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            let ptr16 = baseAddress.bindMemory(to: Float.self, capacity: frameLength * channelCount)

            for frame in 0..<frameLength {
                for ch in 0..<channelCount {
                    let sample = channelData[ch][frame]
                    ptr16[frame * channelCount + ch] = sample
                }
            }
        }

        return data
    }
}

public enum AudioCaptureError: Error {
    case invalidFormat
}
