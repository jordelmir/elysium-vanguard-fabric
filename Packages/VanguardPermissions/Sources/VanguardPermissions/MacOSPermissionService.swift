import Foundation
import CoreGraphics
import AppKit
import ServiceManagement
import VanguardDomain

// MARK: - macOS Permission Service

public final class MacOSPermissionService: PermissionService, @unchecked Sendable {
    private static let cacheKey = "com.elysiumvanguard.permissions.granted"
    @MainActor private static let defaults = UserDefaults.standard

    public init() {}

    // MARK: - Cache

    private static func cachedGrants() -> Set<String> {
        let arr = MainActor.assumeIsolated { defaults.object(forKey: cacheKey) as? [String] }
        return Set(arr ?? [])
    }

    private static func cacheGrant(_ kind: PermissionKind) {
        MainActor.assumeIsolated {
            var grants = cachedGrants()
            grants.insert(kind.rawValue)
            defaults.set(Array(grants), forKey: cacheKey)
        }
    }

    private static func isCached(_ kind: PermissionKind) -> Bool {
        cachedGrants().contains(kind.rawValue)
    }

    // MARK: - Check

    public func checkAllPermissions() async -> [PermissionDescriptor] {
        var descriptors: [PermissionDescriptor] = []
        for kind in PermissionKind.allCases {
            let state = await checkPermission(kind: kind)
            descriptors.append(PermissionDescriptor(
                kind: kind,
                state: state,
                description: kind.displayName,
                instructions: kind.explanation
            ))
        }
        return descriptors
    }

    public func checkPermission(kind: PermissionKind) async -> PermissionState {
        let systemState = checkSystemPermission(kind: kind)

        if systemState.isGranted {
            Self.cacheGrant(kind)
            return .granted
        }

        if Self.isCached(kind) {
            return .granted
        }

        return systemState
    }

    private func checkSystemPermission(kind: PermissionKind) -> PermissionState {
        switch kind {
        case .screenRecording:
            return CGPreflightScreenCaptureAccess() ? .granted : .notDetermined

        case .accessibility:
            return AXIsProcessTrusted() ? .granted : .notDetermined

        case .localNetwork:
            return .granted

        case .loginItem:
            if #available(macOS 13.0, *) {
                return ServiceManagement.SMAppService.mainApp.status == .enabled ? .granted : .notDetermined
            }
            return .unsupported
        }
    }

    // MARK: - Request

    public func requestPermission(kind: PermissionKind) async -> PermissionState {
        switch kind {
        case .screenRecording:
            let granted = CGRequestScreenCaptureAccess()
            if granted { Self.cacheGrant(kind) }
            return granted ? .granted : .denied

        case .accessibility:
            let result = Self.requestAccessibilityTrust()
            if result.isGranted { Self.cacheGrant(kind) }
            return result

        case .localNetwork:
            return .granted

        case .loginItem:
            if #available(macOS 13.0, *) {
                do {
                    try ServiceManagement.SMAppService.mainApp.register()
                    Self.cacheGrant(kind)
                    return .granted
                } catch {
                    return .denied
                }
            }
            return .unsupported
        }
    }

    private static func requestAccessibilityTrust() -> PermissionState {
        let key = unsafeBitCast(NSString("AXTrustedCheckOptionPrompt"), to: CFString.self)
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .granted : .denied
    }

    // MARK: - Settings

    public func openSystemSettings(for kind: PermissionKind) async {
        let urlString: String
        switch kind {
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .localNetwork:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Network"
        case .loginItem:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_LoginItems"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    public func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    public func revalidateAllPermissions() async -> [PermissionKind: PermissionState] {
        var results: [PermissionKind: PermissionState] = [:]
        for kind in PermissionKind.allCases {
            results[kind] = await checkPermission(kind: kind)
        }
        return results
    }

    public func watchPermissionChanges(interval: TimeInterval) -> AsyncStream<PermissionKind> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                var previous: [PermissionKind: PermissionState] = [:]
                for kind in PermissionKind.allCases {
                    previous[kind] = await self?.checkPermission(kind: kind)
                }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    guard !Task.isCancelled else { break }
                    for kind in PermissionKind.allCases {
                        let current = await self?.checkPermission(kind: kind)
                        if let current, previous[kind] != current {
                            continuation.yield(kind)
                            previous[kind] = current
                        }
                    }
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }
}
