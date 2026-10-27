import AppKit

@MainActor
enum SettingsPresenter {
    private static weak var trackedSettingsWindow: NSWindow?

    static func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

        DispatchQueue.main.async {
            let settingsWindow = resolveSettingsWindow()
            settingsWindow?.makeKeyAndOrderFront(nil)
            trackedSettingsWindow = settingsWindow
        }
    }

    static func handleWindowWillClose(_ window: NSWindow) {
        if window === trackedSettingsWindow || isSettingsWindow(window) {
            trackedSettingsWindow = nil
        }
        DispatchQueue.main.async {
            restoreAccessoryPolicyIfNeeded()
        }
    }

    private static func restoreAccessoryPolicyIfNeeded() {
        let visibleAppWindows = NSApp.windows.filter { $0.isVisible && !$0.isSheet }
        if visibleAppWindows.isEmpty {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private static func resolveSettingsWindow() -> NSWindow? {
        if let tracked = trackedSettingsWindow, tracked.isVisible || NSApp.windows.contains(tracked) {
            return tracked
        }

        if let match = NSApp.windows.first(where: isSettingsWindow) {
            return match
        }

        return NSApp.windows.last(where: { $0.canBecomeKey })
    }

    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        if window === trackedSettingsWindow {
            return true
        }
        let title = window.title
        if title.localizedCaseInsensitiveContains("settings") {
            return true
        }
        if let identifier = window.identifier?.rawValue,
           identifier.localizedCaseInsensitiveContains("settings") {
            return true
        }
        return false
    }
}
