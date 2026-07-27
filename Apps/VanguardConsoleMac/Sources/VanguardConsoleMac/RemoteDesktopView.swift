import SwiftUI
import VanguardUI
import AppKit
import CoreVideo
import CoreImage
import VanguardDomain
import VanguardProtocol
import VanguardInput
import VanguardRender
import VanguardSession
import MetalKit

struct RemoteDesktopView: View {
    let nodeName: String
    @StateObject private var renderer = RemoteDesktopState()
    @EnvironmentObject private var consoleState: ConsoleAppState
    @State private var isFullscreen = false
    @State private var metalView: MTKView?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().background(Color.white.opacity(0.04))
            videoArea
            Divider().background(Color.white.opacity(0.04))
            statusBar
        }
        .task {
            await renderer.startReceiving(consoleState: consoleState)
            if let view = metalView {
                renderer.setupMetalView(view)
            }
        }
        .onDisappear { Task { await renderer.stop() } }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            renderer.isConnected = true
        }
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
                HStack(spacing: DS.Spacing.sm) {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text("\(renderer.fps)")
                                .font(DS.Typography.monoBold)
                                .foregroundColor(renderer.fps >= 30 ? DS.Colors.success : DS.Colors.warning)
                            Text("FPS")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textQuaternary)
                        }
                        HStack(spacing: DS.Spacing.xs) {
                            Text("\(renderer.latency, specifier: "%.0f")")
                                .font(DS.Typography.monoBold)
                                .foregroundColor(renderer.latency < 50 ? DS.Colors.success : DS.Colors.warning)
                            Text("ms")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textQuaternary)
                        }
                    }
                    if let stats = renderer.pipelineStats {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: DS.Spacing.xs) {
                                Text("↑\(stats.framesEncoded)")
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.accent)
                                Text("↓\(stats.framesDecoded)")
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.success)
                            }
                            Text("\(stats.currentBitrate / 1_000_000)Mbps")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textQuaternary)
                        }
                    }
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

            MetalRepresentableView(metalView: $metalView)
                .onAppear {
                    if let view = metalView {
                        renderer.setupMetalView(view)
                    }
                }

            if renderer.currentImage != nil {
                Image(nsImage: renderer.currentImage!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .allowsHitTesting(false)
                    .opacity(renderer.useMetalFallback ? 1 : 0)
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
        .modifier(DesktopHoverModifier(renderer: renderer))
        .modifier(DesktopTapModifier(renderer: renderer, consoleState: consoleState))
        .modifier(DesktopScrollModifier(renderer: renderer, consoleState: consoleState))
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

            if renderer.isConnected {
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(DS.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("Connected")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.success)
                }
            }

            ElysiumButton(title: "Disconnect", icon: "xmark.circle.fill", color: DS.Colors.error, style: .bordered) {
                Task { await consoleState.disconnect() }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
}

struct MetalRepresentableView: NSViewRepresentable {
    @Binding var metalView: MTKView?

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        view.framebufferOnly = false
        view.preferredFramesPerSecond = 60
        view.colorPixelFormat = .bgra8Unorm
        DispatchQueue.main.async {
            self.metalView = view
        }
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}

struct DesktopHoverModifier: ViewModifier {
    @ObservedObject var renderer: RemoteDesktopState
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        renderer.cursorX = location.x
                        renderer.cursorY = location.y
                        renderer.showCrosshair = true
                        Task {
                            let frame = renderer.currentFrameSize
                            guard frame.width > 0, frame.height > 0 else { return }
                            let normalizedX = location.x / frame.width
                            let normalizedY = 1.0 - (location.y / frame.height)
                            try? await renderer.consoleState?.sendInputEvent(
                                .mouseMove(normalizedX: normalizedX, normalizedY: normalizedY, sequence: UInt64(Date().timeIntervalSinceReferenceDate * 1000))
                            )
                        }
                    case .ended:
                        renderer.showCrosshair = false
                    }
                }
        } else {
            content
                .onHover { inside in
                    renderer.showCrosshair = inside
                }
        }
    }
}

struct DesktopTapModifier: ViewModifier {
    @ObservedObject var renderer: RemoteDesktopState
    var consoleState: ConsoleAppState
    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    Task {
                        let frame = renderer.currentFrameSize
                        guard frame.width > 0, frame.height > 0 else { return }
                        let normalizedX = value.location.x / frame.width
                        let normalizedY = 1.0 - (value.location.y / frame.height)
                        try? await consoleState.sendInputEvent(
                            .mouseButton(button: .left, phase: .down, normalizedX: normalizedX, normalizedY: normalizedY)
                        )
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        try? await consoleState.sendInputEvent(
                            .mouseButton(button: .left, phase: .up, normalizedX: normalizedX, normalizedY: normalizedY)
                        )
                    }
                }
        )
    }
}

struct DesktopScrollModifier: ViewModifier {
    @ObservedObject var renderer: RemoteDesktopState
    var consoleState: ConsoleAppState
    func body(content: Content) -> some View {
        content
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
    @Published var isConnected = false
    @Published var pipelineStats: PipelineStats?
    @Published var useMetalFallback = true

    var currentFrameSize: CGSize { currentImage?.size ?? .zero }
    weak var consoleState: ConsoleAppState?

    private var frameCount = 0
    private var lastFPSTime = Date()
    private var receiveTask: Task<Void, any Error>?
    private var metalRenderer: VideoMetalRenderer?
    private var statsTask: Task<Void, Never>?

    func setupMetalView(_ view: MTKView) {
        let renderer = VideoMetalRenderer()
        renderer.setMTKView(view)
        self.metalRenderer = renderer
        Task { try? await renderer.startRendering() }
    }

    func startReceiving(consoleState: ConsoleAppState) async {
        self.consoleState = consoleState
        isConnected = true
        receiveTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                for try await sendableFrame in await consoleState.frameUpdates {
                    await MainActor.run {
                        self.frameCount += 1
                        let now = Date()
                        if now.timeIntervalSince(self.lastFPSTime) >= 1.0 {
                            self.fps = self.frameCount
                            self.frameCount = 0
                            self.lastFPSTime = now
                        }
                        let pb = sendableFrame.pixelBuffer
                        if self.metalRenderer != nil {
                            self.useMetalFallback = false
                            Task { try? await self.metalRenderer?.renderPixelBuffer(pb) }
                        } else {
                            if let image = self.createImage(from: pb) {
                                self.currentImage = image
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isConnected = false
                }
            }
        }
    }

    func requestKeyframe() async {
        try? await consoleState?.sendInputEvent(.releaseAll)
    }

    func stop() async {
        receiveTask?.cancel()
        receiveTask = nil
        statsTask?.cancel()
        statsTask = nil
        isConnected = false
        await metalRenderer?.stopRendering()
    }

    private func createImage(from pixelBuffer: CVPixelBuffer) -> NSImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
