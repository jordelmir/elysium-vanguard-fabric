import Foundation
import CoreGraphics
import AppKit
import ServiceManagement
import VanguardDomain

// MARK: - macOS Permission Service

public final class MacOSPermissionService: PermissionService, @unchecked Sendable {
    public init() {}

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

    public func requestPermission(kind: PermissionKind) async -> PermissionState {
        switch kind {
        case .screenRecording:
            return CGRequestScreenCaptureAccess() ? .granted : .denied

        case .accessibility:
            return AXIsProcessTrusted() ? .granted : .denied

        case .localNetwork:
            return .granted

        case .loginItem:
            if #available(macOS 13.0, *) {
                do {
                    try ServiceManagement.SMAppService.mainApp.register()
                    return .granted
                } catch {
                    return .denied
                }
            }
            return .unsupported
        }
    }

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
}
