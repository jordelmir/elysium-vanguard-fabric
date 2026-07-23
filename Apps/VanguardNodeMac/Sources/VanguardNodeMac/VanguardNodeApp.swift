import SwiftUI

@main
struct VanguardNodeApp: App {
    @StateObject private var nodeState = NodeAppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(nodeState)
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(nodeState)
        } label: {
            Label("Elysium Node", systemImage: nodeState.isRunning ? "circle.fill" : "circle")
        }
    }
}
