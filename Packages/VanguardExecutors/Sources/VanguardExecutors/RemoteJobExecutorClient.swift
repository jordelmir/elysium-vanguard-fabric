import Foundation
import os
import VanguardDomain
import VanguardTransport
import VanguardProtocol

public actor RemoteJobExecutorClient: RemoteJobExecutor {
    private let transport: any VanguardTransport
    private let nodeID: NodeID
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "RemoteExecutor")

    public init(transport: any VanguardTransport, nodeID: NodeID) {
        self.transport = transport
        self.nodeID = nodeID
    }

    public func submitJob(
        name: String,
        command: [String],
        workingDirectory: String?,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
        let jobID = UUID().uuidString
        logger.info("Submitting job \(name) as \(jobID) to node \(self.nodeID.rawValue.uuidString)")

        var payload = Data()
        let jobIDData = jobID.data(using: .utf8) ?? Data()
        payload.append(UInt8(jobIDData.count))
        payload.append(jobIDData)
        let nameData = name.data(using: .utf8) ?? Data()
        payload.append(UInt8(nameData.count))
        payload.append(nameData)
        for arg in command {
            let argData = arg.data(using: .utf8) ?? Data()
            payload.append(UInt8(argData.count))
            payload.append(argData)
        }
        if let wd = workingDirectory {
            let wdData = wd.data(using: .utf8) ?? Data()
            payload.append(UInt8(wdData.count))
            payload.append(wdData)
        } else {
            payload.append(0)
        }
        let timeoutData = withUnsafeBytes(of: UInt64(timeoutSeconds)) { Data($0) }
        payload.append(timeoutData)

        let message = OutboundMessage(
            messageType: .jobSubmit,
            streamChannel: .control,
            payload: payload
        )
        try await transport.send(message)

        return jobID
    }

    public func cancelJob(jobID: String) async throws {
        logger.info("Cancelling remote job \(jobID)")
        guard let payload = jobID.data(using: .utf8) else { return }
        let message = OutboundMessage(
            messageType: .jobCancelled,
            streamChannel: .control,
            payload: payload
        )
        try await transport.send(message)
    }

    public func getJobStatus(jobID: String) async -> String? {
        logger.debug("Polling status for job \(jobID)")
        return "running"
    }
}
