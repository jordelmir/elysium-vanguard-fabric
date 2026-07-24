import Foundation
import os.log
import VanguardDomain

public actor WorkspaceDistributedService {
    private var workspaces: [WorkspaceID: Workspace] = [:]
    private var activeWorkspace: WorkspaceID?
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Workspace")

    public init() {}

    public func createWorkspace(name: String) -> Workspace {
        let id = WorkspaceID()
        let workspace = Workspace(
            id: id,
            name: name,
            nodeIDs: [],
            createdAt: Date(),
            layout: .grid
        )
        workspaces[id] = workspace
        logger.info("Created workspace: \(name)")
        return workspace
    }

    public func deleteWorkspace(_ id: WorkspaceID) async {
        guard workspaces[id] != nil else {
            logger.warning("Attempted to delete non-existent workspace")
            return
        }
        workspaces.removeValue(forKey: id)
        if activeWorkspace == id {
            activeWorkspace = nil
        }
        logger.info("Deleted workspace: \(id.rawValue.uuidString)")
    }

    public func addNode(_ nodeID: NodeID, to workspaceID: WorkspaceID) async throws {
        guard var workspace = workspaces[workspaceID] else {
            throw WorkspaceError.workspaceNotFound(workspaceID)
        }
        workspace.nodeIDs.insert(nodeID)
        workspaces[workspaceID] = workspace
        logger.info("Added node \(nodeID.rawValue.uuidString) to workspace \(workspace.name)")
    }

    public func removeNode(_ nodeID: NodeID, from workspaceID: WorkspaceID) async {
        guard var workspace = workspaces[workspaceID] else {
            logger.warning("Attempted to remove node from non-existent workspace")
            return
        }
        workspace.nodeIDs.remove(nodeID)
        workspaces[workspaceID] = workspace
        logger.info("Removed node \(nodeID.rawValue.uuidString) from workspace \(workspace.name)")
    }

    public func setActiveWorkspace(_ id: WorkspaceID) async {
        guard workspaces[id] != nil else {
            logger.warning("Attempted to activate non-existent workspace")
            return
        }
        activeWorkspace = id
        logger.info("Set active workspace: \(id.rawValue.uuidString)")
    }

    public func getActiveWorkspace() -> Workspace? {
        guard let id = activeWorkspace else { return nil }
        return workspaces[id]
    }

    public func getAllWorkspaces() -> [Workspace] {
        Array(workspaces.values)
    }

    public func getWorkspaceNodes(_ workspaceID: WorkspaceID) -> [NodeID] {
        guard let workspace = workspaces[workspaceID] else { return [] }
        return Array(workspace.nodeIDs)
    }

    public func renameWorkspace(_ id: WorkspaceID, newName: String) async {
        guard var workspace = workspaces[id] else {
            logger.warning("Attempted to rename non-existent workspace")
            return
        }
        workspace.name = newName
        workspaces[id] = workspace
        logger.info("Renamed workspace to \(newName)")
    }
}

public struct Workspace: Sendable, Identifiable {
    public let id: WorkspaceID
    public var name: String
    public var nodeIDs: Set<NodeID>
    public var createdAt: Date
    public var layout: WorkspaceLayout

    public init(id: WorkspaceID, name: String, nodeIDs: Set<NodeID>, createdAt: Date, layout: WorkspaceLayout) {
        self.id = id
        self.name = name
        self.nodeIDs = nodeIDs
        self.createdAt = createdAt
        self.layout = layout
    }
}

public enum WorkspaceLayout: String, Sendable, Codable {
    case grid
    case horizontal
    case vertical
    case freeform
}

public enum WorkspaceError: Error, Sendable {
    case workspaceNotFound(WorkspaceID)
}
