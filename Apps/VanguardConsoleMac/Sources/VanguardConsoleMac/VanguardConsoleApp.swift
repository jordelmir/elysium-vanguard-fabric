import SwiftUI

@main
struct VanguardConsoleApp: App {
    @StateObject private var consoleState = ConsoleAppState()

    var body: some Scene {
        WindowGroup {
            ConsoleView()
                .environmentObject(consoleState)
        }

        if #available(macOS 13.0, *) {
            MenuBarExtra {
                ConsoleMenuBarView()
                    .environmentObject(consoleState)
            } label: {
                Label("Elysium Console", systemImage: consoleState.isScanning ? "antenna.radiowaves.left.and.right" : "display")
            }
        }
    }
}
