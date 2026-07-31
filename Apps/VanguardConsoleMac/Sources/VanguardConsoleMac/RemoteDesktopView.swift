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
            renderer.startKeyboardMonitor()
            if let view = metalView {
                renderer.setupMetalView(view)
            }
        }
        .onDisappear {
            renderer.stopKeyboardMonitor()
            Task { await renderer.stop() }
        }
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
        content
            .onHover { inside in
                renderer.showCrosshair = inside
            }
            .background(
                MouseMoveView(renderer: renderer)
                    .allowsHitTesting(false)
            )
    }
}

struct MouseMoveView: NSViewRepresentable {
    @ObservedObject var renderer: RemoteDesktopState

    func makeNSView(context: Context) -> MouseMoveNSView {
        let view = MouseMoveNSView()
        view.onMove = { [weak renderer] location in
            guard let renderer = renderer else { return }
            renderer.cursorX = location.x
            renderer.cursorY = location.y
            let frame = renderer.currentFrameSize
            guard frame.width > 0, frame.height > 0 else { return }
            let normalizedX = location.x / frame.width
            let normalizedY = 1.0 - (location.y / frame.height)
            Task {
                try? await renderer.consoleState?.sendInputEvent(
                    .mouseMove(
                        normalizedX: normalizedX,
                        normalizedY: normalizedY,
                        sequence: UInt64(Date().timeIntervalSinceReferenceDate * 1000)
                    )
                )
            }
        }
        return view
    }

    func updateNSView(_ nsView: MouseMoveNSView, context: Context) {}
}

class MouseMoveNSView: NSView {
    var onMove: ((CGPoint) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let flipped = NSPoint(x: location.x, y: bounds.height - location.y)
        onMove?(flipped)
    }
}

struct DesktopTapModifier: ViewModifier {
    @ObservedObject var renderer: RemoteDesktopState
    var consoleState: ConsoleAppState
    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let frame = renderer.currentFrameSize
                        guard frame.width > 0, frame.height > 0 else { return }
                        let normalizedX = value.location.x / frame.width
                        let normalizedY = 1.0 - (value.location.y / frame.height)
                        Task {
                            try? await consoleState.sendInputEvent(
                                .mouseMove(
                                    normalizedX: normalizedX,
                                    normalizedY: normalizedY,
                                    sequence: UInt64(Date().timeIntervalSinceReferenceDate * 1000)
                                )
                            )
                        }
                    }
                    .onEnded { value in
                        let frame = renderer.currentFrameSize
                        guard frame.width > 0, frame.height > 0 else { return }
                        let normalizedX = value.location.x / frame.width
                        let normalizedY = 1.0 - (value.location.y / frame.height)
                        Task {
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
            .contextMenu {
                Button("Right Click") {
                    let frame = renderer.currentFrameSize
                    guard frame.width > 0, frame.height > 0 else { return }
                    let x = renderer.cursorX / frame.width
                    let y = 1.0 - (renderer.cursorY / frame.height)
                    Task {
                        try? await consoleState.sendInputEvent(
                            .mouseButton(button: .right, phase: .down, normalizedX: x, normalizedY: y)
                        )
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        try? await consoleState.sendInputEvent(
                            .mouseButton(button: .right, phase: .up, normalizedX: x, normalizedY: y)
                        )
                    }
                }
            }
    }
}

struct DesktopScrollModifier: ViewModifier {
    @ObservedObject var renderer: RemoteDesktopState
    var consoleState: ConsoleAppState
    func body(content: Content) -> some View {
        content
            .background(
                ScrollCaptureView(consoleState: consoleState)
                    .allowsHitTesting(false)
            )
    }
}

struct ScrollCaptureView: NSViewRepresentable {
    var consoleState: ConsoleAppState

    func makeNSView(context: Context) -> ScrollCaptureNSView {
        let view = ScrollCaptureNSView()
        view.onScroll = { [weak consoleState] deltaX, deltaY, precise in
            Task {
                try? await consoleState?.sendInputEvent(
                    .scroll(deltaX: deltaX, deltaY: deltaY, phase: .changed, precise: precise)
                )
            }
        }
        return view
    }

    func updateNSView(_ nsView: ScrollCaptureNSView, context: Context) {}
}

class ScrollCaptureNSView: NSView {
    var onScroll: ((Double, Double, Bool) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        let deltaX = Double(event.scrollingDeltaX)
        let deltaY = Double(event.scrollingDeltaY)
        let precise = event.isDirectionInvertedFromDevice || (abs(deltaY) < 1.0 && abs(deltaX) < 1.0)
        onScroll?(deltaX, deltaY, precise)
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
    private var keyboardMonitor: Any?

    func setupMetalView(_ view: MTKView) {
        guard let renderer = try? VideoMetalRenderer.create() else { return }
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

    func startKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            let keyCode = event.keyCode
            let eventType = event.type
            let isRepeat = event.isARepeat
            let modifierFlags = event.modifierFlags
            Task { @MainActor [weak self] in
                guard let self = self, self.isConnected else { return }
                let phase: KeyPhase = eventType == .keyDown ? .down : .up
                let modifiers = self.mapModifiers(modifierFlags)
                try? await self.consoleState?.sendInputEvent(
                    .key(
                        keyCode: UInt16(keyCode),
                        phase: phase,
                        modifiers: modifiers,
                        isRepeat: isRepeat
                    )
                )
            }
            return event
        }
    }

    func stopKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
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
        stopKeyboardMonitor()
        await metalRenderer?.stopRendering()
    }

    private func mapModifiers(_ flags: NSEvent.ModifierFlags) -> ModifierSet {
        var modifiers = ModifierSet()
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.capsLock) { modifiers.insert(.capsLock) }
        if flags.contains(.function) { modifiers.insert(.function) }
        return modifiers
    }

    private func createImage(from pixelBuffer: CVPixelBuffer) -> NSImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
