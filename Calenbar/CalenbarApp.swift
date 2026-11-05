import AppKit
import SwiftUI

@main
struct CalenbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: MeetingMonitor?
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let monitor = MeetingMonitor()
        self.monitor = monitor
        statusController = StatusItemController(monitor: monitor, settings: AppSettings.shared)

        LaunchAtLoginController.syncPreferenceToSystem(AppSettings.shared.openAtLogin)
        LaunchAtLoginController.refreshFromSystem(into: AppSettings.shared)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func applicationDidBecomeActive() {
        LaunchAtLoginController.refreshFromSystem(into: AppSettings.shared)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
