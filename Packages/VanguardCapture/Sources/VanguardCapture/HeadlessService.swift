import Foundation
import CoreGraphics
import os.log

public actor HeadlessService {
    private var isHeadless = false
    private var dummyDisplayConnected = false
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Headless")

    public init() {}

    public func detectHeadlessMode() -> HeadlessState {
        let displayIDs = getActiveDisplayIDs()
        let hasDummyDisplay = checkForDummyDisplay(displayIDs)
        let isClamshell = checkClamshellMode()

        isHeadless = displayIDs.isEmpty || hasDummyDisplay
        dummyDisplayConnected = hasDummyDisplay

        return HeadlessState(
            isHeadless: isHeadless,
            hasDummyDisplay: hasDummyDisplay,
            isClamshellClosed: isClamshell,
            activeDisplayCount: displayIDs.count
        )
    }

    public func getActiveDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        let err = CGGetActiveDisplayList(0, nil, &displayCount)
        guard err == .success else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        return displays
    }

    public func getDisplayDimensions(_ displayID: CGDirectDisplayID) -> (width: Int, height: Int)? {
        guard let mode = CGDisplayCopyDisplayMode(displayID) else { return nil }
        return (width: Int(mode.width), height: Int(mode.height))
    }

    public func prepareForHeadless() async throws -> HeadlessState {
        let state = await detectHeadlessMode()
        if state.isHeadless {
            logger.info("Headless mode detected — \(state.activeDisplayCount) active displays")
        }
        return state
    }

    private func checkForDummyDisplay(_ displayIDs: [CGDirectDisplayID]) -> Bool {
        for displayID in displayIDs {
            if CGDisplayVendorNumber(displayID) == 0 {
                return true
            }
        }
        return false
    }

    private func checkClamshellMode() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        defer { IOObjectRelease(service) }
        guard service != 0 else { return false }
        if let prop = IORegistryEntryCreateCFProperty(service, "AAPL,ClamshellPid" as CFString, nil, 0) {
            return prop.takeRetainedValue() as? Bool ?? false
        }
        return false
    }
}

public struct HeadlessState: Sendable {
    public let isHeadless: Bool
    public let hasDummyDisplay: Bool
    public let isClamshellClosed: Bool
    public let activeDisplayCount: Int

    public init(isHeadless: Bool, hasDummyDisplay: Bool, isClamshellClosed: Bool, activeDisplayCount: Int) {
        self.isHeadless = isHeadless
        self.hasDummyDisplay = hasDummyDisplay
        self.isClamshellClosed = isClamshellClosed
        self.activeDisplayCount = activeDisplayCount
    }
}
