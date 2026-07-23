import Foundation
import VanguardDomain

// MARK: - Permission Service Protocol

public protocol PermissionService: Sendable {
    func checkAllPermissions() async -> [PermissionDescriptor]
    func checkPermission(kind: PermissionKind) async -> PermissionState
    func requestPermission(kind: PermissionKind) async -> PermissionState
    func openSystemSettings(for kind: PermissionKind) async
}

// MARK: - Permission Result

public struct PermissionCheckResult: Sendable, Equatable {
    public let allGranted: Bool
    public let permissions: [PermissionDescriptor]

    public init(allGranted: Bool, permissions: [PermissionDescriptor]) {
        self.allGranted = allGranted
        self.permissions = permissions
    }
}
