import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private enum Metrics {
        /// Extra space between the calendar symbol and the title on the status item.
        static let iconTitleSpacing: CGFloat = 6
    }

    private let monitor: MeetingMonitor
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    init(monitor: MeetingMonitor) {
        self.monitor = monitor
        super.init()
        bind()
        observeScreenChanges()
        applyPresentation()
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        applyPresentation()
    }

    private func bind() {
        Publishers.CombineLatest4(
            monitor.$meeting,
            monitor.$access,
            monitor.$labelText,
            monitor.$isUrgent
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _, _, _ in
            self?.applyPresentation()
        }
        .store(in: &cancellables)
    }

    private func applyPresentation() {
        if monitor.shouldShowStatusItem {
            ensureStatusItem()
            updateButton()
        } else {
            removeStatusItem()
        }
    }

    private func ensureStatusItem() {
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self
            item.button?.action = #selector(statusItemClicked(_:))
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            statusItem = item
        }
    }

    private func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func updateButton() {
        guard let button = statusItem?.button else { return }

        let text = monitor.labelText
        if monitor.isUrgent {
            button.title = ""
            button.image = renderPillImage(text: text)
            button.imagePosition = .imageOnly
        } else {
            button.image = templateCalendarIcon()
            button.title = text
            button.imagePosition = .imageLeading
        }
        button.toolTip = statusItemToolTip(fallback: text)
    }

    private func statusItemToolTip(fallback: String) -> String {
        guard let meeting = monitor.meeting else { return fallback }
        let phrase = monitor.timePhraseText
        if phrase.isEmpty {
            return meeting.title
        }
        return "\(meeting.title) \(phrase)"
    }

    private func renderPillImage(text: String) -> NSImage? {
        let view = MenuBarPill(text: text)
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }

    private func templateCalendarIcon() -> NSImage? {
        guard let symbol = NSImage(
            systemSymbolName: "calendar",
            accessibilityDescription: "Upcoming meeting"
        ) else { return nil }

        let symbolSize = symbol.size
        let canvasSize = NSSize(
            width: symbolSize.width + Metrics.iconTitleSpacing,
            height: symbolSize.height
        )

        let image = NSImage(size: canvasSize)
        image.isTemplate = true
        image.lockFocus()
        symbol.draw(
            at: .zero,
            from: NSRect(origin: .zero, size: symbolSize),
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        return image
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let menu = buildMenu()
        let location = NSPoint(x: 0, y: sender.bounds.height + 4)
        if event.type == .rightMouseUp {
            menu.popUp(positioning: nil, at: location, in: sender)
        } else {
            menu.popUp(positioning: nil, at: location, in: sender)
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        if monitor.access == .denied {
            menu.addItem(withTitle: "Calendar access is off", action: nil, keyEquivalent: "")
            menu.addItem(
                withTitle: "Open System Settings…",
                action: #selector(openPrivacySettings),
                keyEquivalent: ""
            ).target = self
        } else if let meeting = monitor.meeting {
            menu.addItem(withTitle: meeting.title, action: nil, keyEquivalent: "")
            let calendarItem = menu.addItem(
                withTitle: meeting.calendarTitle,
                action: nil,
                keyEquivalent: ""
            )
            calendarItem.attributedTitle = NSAttributedString(
                string: meeting.calendarTitle,
                attributes: [.foregroundColor: NSColor.secondaryLabelColor]
            )
            let timeString = meeting.start.formatted(date: .omitted, time: .shortened)
            menu.addItem(withTitle: timeString, action: nil, keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
            menu.addItem(
                withTitle: "Open in Calendar",
                action: #selector(openCalendar),
                keyEquivalent: ""
            ).target = self
        } else if monitor.access == .unknown {
            menu.addItem(withTitle: "Requesting calendar access…", action: nil, keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "No upcoming meetings", action: nil, keyEquivalent: "")
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: "Quit Calenbar",
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self

        return menu
    }

    @objc private func openCalendar() {
        monitor.openCalendar()
    }

    @objc private func openPrivacySettings() {
        monitor.openPrivacySettings()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
