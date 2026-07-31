import SwiftUI
import VanguardCoordinator
import VanguardProtocol
import VanguardTransport
import VanguardDomain

@main
struct VanguardCoordinatorServerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var coordinatorServerState: CoordinatorServerState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = CoordinatorServerState()
        self.coordinatorServerState = state

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.title = "EC"
            button.toolTip = "Elysium Coordinator"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Elysium Vanguard Coordinator", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Start Server", action: #selector(startServer), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Stop Server", action: #selector(stopServer), keyEquivalent: "x"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu

        state.start()
    }

    @objc private func startServer() {
        coordinatorServerState?.start()
    }

    @objc private func stopServer() {
        coordinatorServerState?.stop()
    }

    @objc private func quit() {
        coordinatorServerState?.stop()
        NSApplication.shared.terminate(nil)
    }
}
