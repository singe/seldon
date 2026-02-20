import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        Task { @MainActor in
            NSApplication.shared.windows.forEach { Self.configure(window: $0) }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let window = note.object as? NSWindow else { return }
            Task { @MainActor in
                Self.configure(window: window)
            }
        }
    }

    @MainActor
    private static func configure(window: NSWindow) {
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 320, height: 100)
    }
}

struct SeldonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Seldon Chat") {
            ContentView(
                runner: AppRuntime.runner,
                defaultTemperature: AppRuntime.defaultTemperature,
                defaultSystemPrompt: AppRuntime.defaultSystemPrompt,
                toolsAvailable: AppRuntime.toolsAvailable
            )
        }
    }
}
