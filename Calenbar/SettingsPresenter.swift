import AppKit
import SwiftUI

@MainActor
final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@MainActor
enum SettingsPresenter {
    private static let windowIdentifier = NSUserInterfaceItemIdentifier("calenbar.settings")
    private static let windowSize = NSSize(width: 680, height: 460)

    private static var window: NSWindow?
    private static let windowDelegate = SettingsWindowDelegate()

    static func show() {
        let settingsWindow = window ?? makeWindow()
        window = settingsWindow

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)
    }

    private static func makeWindow() -> NSWindow {
        let hostingController = NSHostingController(
            rootView: SettingsView(settings: AppSettings.shared)
        )

        let settingsWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.identifier = windowIdentifier
        settingsWindow.title = "Settings"
        settingsWindow.contentViewController = hostingController
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.delegate = windowDelegate
        return settingsWindow
    }
}
