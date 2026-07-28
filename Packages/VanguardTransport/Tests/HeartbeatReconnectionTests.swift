import Testing
import Foundation
@testable import VanguardTransport

@Suite("HeartbeatController (Swift Testing)")
struct HeartbeatControllerSwiftTests {

    @Test("Initial state is offline")
    func initialState() {
        let controller = HeartbeatController()
        #expect(controller.currentState == .offline)
        #expect(controller.currentSmoothedRTT == 0)
    }

    @Test("Create ping increments sequence")
    func createPing() {
        let controller = HeartbeatController()
        let ping1 = controller.createPing()
        let ping2 = controller.createPing()
        #expect(ping2.sequence > ping1.sequence)
    }

    @Test("Handle pong transitions to healthy and computes RTT")
    func handlePong() {
        let controller = HeartbeatController()
        let ping = controller.createPing()
        controller.handlePong(ping)
        #expect(controller.currentState == .healthy)
        #expect(controller.currentSmoothedRTT > 0)
    }

    @Test("Missed heartbeats degrade connection")
    func missedHeartbeats() {
        let controller = HeartbeatController()
        controller.handlePong(controller.createPing())
        #expect(controller.currentState == .healthy)
        controller.heartbeatMissed()
        #expect(controller.currentState == .degraded)
        controller.heartbeatMissed()
        controller.heartbeatMissed()
        #expect(controller.currentState == .stalled)
    }

    @Test("Mark reconnecting and offline")
    func markStates() {
        let controller = HeartbeatController()
        controller.handlePong(controller.createPing())
        controller.markReconnecting()
        #expect(controller.currentState == .reconnecting)
        controller.markOffline()
        #expect(controller.currentState == .offline)
    }

    @Test("Reset clears all state")
    func reset() {
        let controller = HeartbeatController()
        controller.handlePong(controller.createPing())
        controller.reset()
        #expect(controller.currentState == .offline)
        #expect(controller.currentSmoothedRTT == 0)
    }

    @Test("Jitter computed from multiple pongs")
    func jitterComputation() {
        let controller = HeartbeatController()
        for _ in 0..<5 {
            controller.handlePong(controller.createPing())
        }
        #expect(controller.currentJitter >= 0)
    }
}

@Suite("ReconnectionManager (Swift Testing)")
struct ReconnectionManagerSwiftTests {

    @Test("Initial state allows reconnection")
    func initialReconnect() {
        let manager = ReconnectionManager(maxAttempts: 5, baseDelayMs: 100, maxDelayMs: 500)
        #expect(manager.shouldAttemptReconnect() == true)
    }

    @Test("Max attempts prevents reconnection")
    func maxAttempts() {
        let manager = ReconnectionManager(maxAttempts: 2, baseDelayMs: 100, maxDelayMs: 500)
        _ = manager.shouldAttemptReconnect()
        Thread.sleep(forTimeInterval: 0.5)
        _ = manager.shouldAttemptReconnect()
        Thread.sleep(forTimeInterval: 0.5)
        #expect(manager.shouldAttemptReconnect() == false)
    }

    @Test("Reset allows reconnection again")
    func resetReconnect() {
        let manager = ReconnectionManager(maxAttempts: 1, baseDelayMs: 100, maxDelayMs: 500)
        _ = manager.shouldAttemptReconnect()
        Thread.sleep(forTimeInterval: 0.5)
        #expect(manager.shouldAttemptReconnect() == false)
        manager.reset()
        Thread.sleep(forTimeInterval: 0.5)
        #expect(manager.shouldAttemptReconnect() == true)
    }

    @Test("MarkConnected resets attempt count")
    func markConnected() {
        let manager = ReconnectionManager(maxAttempts: 2, baseDelayMs: 100, maxDelayMs: 500)
        _ = manager.shouldAttemptReconnect()
        Thread.sleep(forTimeInterval: 0.5)
        manager.markConnected()
        Thread.sleep(forTimeInterval: 0.5)
        #expect(manager.shouldAttemptReconnect() == true)
    }
}
