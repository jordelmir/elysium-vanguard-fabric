import SwiftUI
import AppKit
import VanguardDomain
import VanguardProtocol
import VanguardInput
import VanguardRender

struct RemoteDesktopView: View {
    let nodeName: String
    @StateObject private var renderer = RemoteDesktopState()
    @EnvironmentObject private var consoleState: ConsoleAppState

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(EV.Colors.cyan.opacity(0.15))
            videoArea
            Divider().overlay(EV.Colors.cyan.opacity(0.15))
            statusBar
        }
        .task { await renderer.startReceiving(consoleState: consoleState) }
        .onDisappear { Task { await renderer.stop() } }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "display")
                    .foregroundColor(EV.Colors.cyan)
                Text(nodeName)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(EV.Colors.textPrimary)
            }
            Spacer()
            if renderer.showFPS {
                HStack(spacing: 6) {
                    Text("\(renderer.fps)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(EV.Colors.green)
                    Text("FPS")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(EV.Colors.textTertiary)
                    Text("·")
                        .foregroundColor(EV.Colors.textTertiary)
                    Text("\(renderer.latency, specifier: "%.0f")")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(EV.Colors.cyan)
                    Text("ms")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(EV.Colors.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(EV.Colors.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(EV.Colors.bg)
    }

    private var videoArea: some View {
        ZStack {
            Color.black

            if let nsImage = renderer.currentImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(EV.Colors.cyan.opacity(0.06))
                            .frame(width: 80, height: 80)
                        Image(systemName: "display.trianglebadge.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundColor(EV.Colors.textTertiary)
                    }
                    Text("WAITING FOR STREAM")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(EV.Colors.textTertiary)
                        .tracking(3)
                }
            }

            if renderer.showCrosshair {
                Path { path in
                    path.move(to: CGPoint(x: renderer.cursorX - 12, y: renderer.cursorY))
                    path.addLine(to: CGPoint(x: renderer.cursorX + 12, y: renderer.cursorY))
                    path.move(to: CGPoint(x: renderer.cursorX, y: renderer.cursorY - 12))
                    path.addLine(to: CGPoint(x: renderer.cursorX, y: renderer.cursorY + 12))
                }
                .stroke(EV.Colors.cyan.opacity(0.6), lineWidth: 1)
                .shadow(color: EV.Colors.cyan.opacity(0.4), radius: 4)
                Circle()
                    .stroke(EV.Colors.cyan.opacity(0.3), lineWidth: 1)
                    .frame(width: 24, height: 24)
                    .position(x: renderer.cursorX, y: renderer.cursorY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                renderer.cursorX = location.x
                renderer.cursorY = location.y
                renderer.showCrosshair = true
            case .ended:
                renderer.showCrosshair = false
            }
        }
        .onTapGesture { location in
            Task {
                let frame = renderer.currentFrameSize
                guard frame.width > 0, frame.height > 0 else { return }
                let normalizedX = location.x / frame.width
                let normalizedY = 1.0 - (location.y / frame.height)
                let event = RemoteInputEvent.mouseButton(
                    button: .left, phase: .down,
                    normalizedX: normalizedX, normalizedY: normalizedY
                )
                try? await consoleState.sendInputEvent(event)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 16) {
            Button(action: { Task { await renderer.requestKeyframe() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Keyframe")
                }
            }
            .buttonStyle(NeonButtonStyle(color: EV.Colors.cyan, isSmall: true))

            Toggle(isOn: $renderer.showFPS) {
                Text("HUD")
                    .font(.system(.caption, design: .monospaced))
            }
            .toggleStyle(SwitchToggleStyle(tint: EV.Colors.cyan))
            .controlSize(.small)

            Spacer()

            Button(action: { Task { await consoleState.disconnect() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Disconnect")
                }
            }
            .buttonStyle(NeonButtonStyle(color: EV.Colors.red, isSmall: true))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(EV.Colors.bg)
    }
}

@MainActor
final class RemoteDesktopState: ObservableObject {
    @Published var currentImage: NSImage?
    @Published var fps: Int = 0
    @Published var latency: Double = 0
    @Published var showFPS = true
    @Published var showCrosshair = false
    @Published var cursorX: CGFloat = 0
    @Published var cursorY: CGFloat = 0

    var currentFrameSize: CGSize { currentImage?.size ?? .zero }

    private var frameCount = 0
    private var lastFPSTime = Date()
    private var receiveTask: Task<Void, any Error>?
    private var renderer: VideoMetalRenderer?

    func startReceiving(consoleState: ConsoleAppState) async {
        renderer = VideoMetalRenderer()
        receiveTask = Task { [weak self] in
            guard let self = self else { return }
            for try await frameData in await consoleState.frameUpdates {
                await MainActor.run {
                    self.frameCount += 1
                    let now = Date()
                    if now.timeIntervalSince(self.lastFPSTime) >= 1.0 {
                        self.fps = self.frameCount
                        self.frameCount = 0
                        self.lastFPSTime = now
                    }
                    if let image = self.createImage(from: frameData) {
                        self.currentImage = image
                    }
                }
            }
        }
    }

    func requestKeyframe() async {}
    func stop() async { receiveTask?.cancel(); receiveTask = nil }

    private func createImage(from data: Data) -> NSImage? {
        guard let bitmap = NSBitmapImageRep(data: data) else { return nil }
        return NSImage(size: bitmap.size)
    }
}
