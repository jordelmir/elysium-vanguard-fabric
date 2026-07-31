import Testing
import Foundation
@testable import VanguardDomain

@Suite("Multi-Display & Window Geometry")
struct MultiDisplayTests {

    let localDisplay = DisplayDescriptor(id: 1, name: "Local", width: 1920, height: 1080, originX: 0, originY: 0, backingScaleFactor: 2.0, isMain: true, isBuiltIn: true)

    let remoteDisplay1 = DisplayDescriptor(id: 2, name: "Remote 1", width: 2560, height: 1440, originX: 0, originY: 0, backingScaleFactor: 2.0, isMain: true, isBuiltIn: false)

    let remoteDisplay2 = DisplayDescriptor(id: 3, name: "Remote 2", width: 1920, height: 1080, originX: 2560, originY: 0, backingScaleFactor: 1.0, isMain: false, isBuiltIn: false)

    @Test("DisplayDescriptor center calculations")
    func displayCenter() {
        #expect(localDisplay.centerX == 960.0)
        #expect(localDisplay.centerY == 540.0)
        #expect(remoteDisplay2.centerX == 3520.0)
        #expect(remoteDisplay2.centerY == 540.0)
    }

    @Test("Map normalized coordinates (normalized stays normalized)")
    func mapNormalizedToRemote() {
        let mapper = WindowGeometryMapper(localDisplay: localDisplay, remoteDisplays: [remoteDisplay1, remoteDisplay2])
        let (mx, my) = mapper.mapNormalizedToRemote(x: 0.5, y: 0.5, targetDisplayID: 2)
        #expect(mx == 0.5)
        #expect(my == 0.5)
    }

    @Test("Map normalized coordinates edge case (top-left)")
    func mapTopLeft() {
        let mapper = WindowGeometryMapper(localDisplay: localDisplay, remoteDisplays: [remoteDisplay1])
        let (mx, my) = mapper.mapNormalizedToRemote(x: 0.0, y: 0.0, targetDisplayID: 2)
        #expect(mx == 0.0)
        #expect(my == 0.0)
    }

    @Test("Map normalized coordinates edge case (bottom-right)")
    func mapBottomRight() {
        let mapper = WindowGeometryMapper(localDisplay: localDisplay, remoteDisplays: [remoteDisplay1])
        let (mx, my) = mapper.mapNormalizedToRemote(x: 1.0, y: 1.0, targetDisplayID: 2)
        #expect(mx == 1.0)
        #expect(my == 1.0)
    }

    @Test("Map remote coordinates back to local")
    func mapRemoteToLocal() {
        let mapper = WindowGeometryMapper(localDisplay: localDisplay, remoteDisplays: [remoteDisplay1])
        let (lx, ly) = mapper.mapRemoteToLocal(x: 0.5, y: 0.5, sourceDisplayID: 2)
        #expect(lx == 0.5)
        #expect(ly == 0.5)
    }

    @Test("Map absolute to normalized coordinates")
    func mapAbsoluteToNormalized() {
        let mapper = WindowGeometryMapper(localDisplay: localDisplay, remoteDisplays: [remoteDisplay1])
        let (nx, ny) = mapper.mapAbsoluteToNormalized(absX: 1280, absY: 720, displayID: 2)
        #expect(nx == 1280.0 / Double(remoteDisplay1.width))
        #expect(ny == 720.0 / Double(remoteDisplay1.height))
    }

    @Test("Map normalized to absolute coordinates")
    func mapNormalizedToAbsolute() {
        let mapper = WindowGeometryMapper(localDisplay: localDisplay, remoteDisplays: [remoteDisplay1])
        let (ax, ay) = mapper.mapNormalizedToAbsolute(nx: 0.5, ny: 0.5, displayID: 2)
        #expect(ax == 0.5 * Double(remoteDisplay1.width))
        #expect(ay == 0.5 * Double(remoteDisplay1.height))
    }

    @Test("Map window bounds to display normalized coordinates")
    func mapWindowToDisplay() {
        let mapper = WindowGeometryMapper(localDisplay: localDisplay, remoteDisplays: [remoteDisplay1])
        let (nx, ny, nw, nh) = mapper.mapWindowToDisplay(
            wx: 100, wy: 200, ww: 800, wh: 600, displayID: 2
        )
        #expect(nx == 100.0 / Double(remoteDisplay1.width))
        #expect(ny == 200.0 / Double(remoteDisplay1.height))
        #expect(nw == 800.0 / Double(remoteDisplay1.width))
        #expect(nh == 600.0 / Double(remoteDisplay1.height))
    }

    @Test("Fallback to first remote display when target not found")
    func fallbackDisplay() {
        let mapper = WindowGeometryMapper(localDisplay: localDisplay, remoteDisplays: [remoteDisplay1])
        let (mx, my) = mapper.mapNormalizedToRemote(x: 0.5, y: 0.5, targetDisplayID: 999)
        #expect(mx == 0.5)
        #expect(my == 0.5)
    }

    @Test("Fallback to local display when no remote displays")
    func noRemoteDisplays() {
        let mapper = WindowGeometryMapper(localDisplay: localDisplay, remoteDisplays: [])
        let (mx, my) = mapper.mapNormalizedToRemote(x: 0.5, y: 0.5, targetDisplayID: 2)
        #expect(mx == 0.5)
        #expect(my == 0.5)
    }

    @Test("RemotePointerContext initialization")
    func pointerContext() {
        let ctx = RemotePointerContext(displayID: 2, normalizedX: 0.5, normalizedY: 0.5, sequence: 42)
        #expect(ctx.displayID == 2)
        #expect(ctx.normalizedX == 0.5)
        #expect(ctx.normalizedY == 0.5)
        #expect(ctx.sequence == 42)
    }

    @Test("WindowGeometryMapper equality")
    func mapperEquality() {
        let m1 = WindowGeometryMapper(localDisplay: localDisplay, remoteDisplays: [remoteDisplay1])
        let m2 = WindowGeometryMapper(localDisplay: localDisplay, remoteDisplays: [remoteDisplay1])
        #expect(m1 == m2)
    }

    @Test("DisplayDescriptor equality")
    func displayEquality() {
        let d1 = DisplayDescriptor(id: 1, name: "A", width: 1920, height: 1080)
        let d2 = DisplayDescriptor(id: 1, name: "A", width: 1920, height: 1080)
        #expect(d1 == d2)
    }

    @Test("WindowCaptureMode values")
    func captureModeValues() {
        #expect(WindowCaptureMode.display.rawValue == "display")
        #expect(WindowCaptureMode.window.rawValue == "window")
        #expect(WindowCaptureMode.application.rawValue == "application")
    }
}
