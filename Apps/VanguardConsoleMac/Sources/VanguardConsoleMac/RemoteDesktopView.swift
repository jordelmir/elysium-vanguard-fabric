import SwiftUI
import VanguardUI
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
            Divider().background(Color.white.opacity(0.04))
            videoArea
            Divider().background(Color.white.opacity(0.04))
            statusBar
        }
        .task { await renderer.startReceiving(consoleState: consoleState) }
        .onDisappear { Task { await renderer.stop() } }
    }

    private var toolbar: some View {
        HStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "display")
                    .foregroundColor(DS.Colors.accent)
                Text(nodeName)
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.textPrimary)
            }
            Spacer()
            if renderer.showFPS {
                HStack(spacing: DS.Spacing.xs) {
                    Text("\(renderer.fps)")
                        .font(DS.Typography.monoBold)
                        .foregroundColor(DS.Colors.success)
                    Text("FPS")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textQuaternary)
                    Text("·").foregroundColor(DS.Colors.textQuaternary)
                    Text("\(renderer.latency, specifier: "%.0f")")
                        .font(DS.Typography.monoBold)
                        .foregroundColor(DS.Colors.accent)
                    Text("ms")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textQuaternary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .glass(style: .ultraThin, cornerRadius: DS.Radius.sm)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    private var videoArea: some View {
        ZStack {
            Color.black

            if let nsImage = renderer.currentImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                VStack(spacing: DS.Spacing.lg) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            .frame(width: 72, height: 72)
                        Image(systemName: "display.trianglebadge.exclamationmark")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(DS.Colors.textQuaternary)
                    }
                    Text("WAITING FOR STREAM")
                        .font(DS.Typography.micro)
                        .foregroundColor(DS.Colors.textQuaternary)
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
                .stroke(DS.Colors.accent.opacity(0.5), lineWidth: 1)
                .shadow(color: DS.Colors.accent.opacity(0.3), radius: 4)
                Circle()
                    .stroke(DS.Colors.accent.opacity(0.2), lineWidth: 1)
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
        HStack(spacing: DS.Spacing.md) {
            ElysiumButton(title: "Keyframe", icon: "arrow.triangle.2.circlepath", color: DS.Colors.accent, style: .bordered) {
                Task { await renderer.requestKeyframe() }
            }

            Toggle(isOn: $renderer.showFPS) {
                Text("HUD").font(DS.Typography.caption)
            }
            .toggleStyle(SwitchToggleStyle(tint: DS.Colors.accent))
            .controlSize(.small)

            Spacer()

            ElysiumButton(title: "Disconnect", icon: "xmark.circle.fill", color: DS.Colors.error, style: .bordered) {
                Task { await consoleState.disconnect() }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
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
