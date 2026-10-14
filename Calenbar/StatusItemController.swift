import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private enum Metrics {
        /// Extra space between the calendar symbol and the title on the status item.
        static let iconTitleSpacing: CGFloat = 6
        static let menuEventNameLimit = 24
    }

    private enum MenuSymbols {
        /// SF Symbol for the next upcoming event in the day list (replaces the menu checkmark).
        static let upcomingEvent = "calendar.badge.clock"
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
        .combineLatest(monitor.$menuBarNameText, monitor.$timePhraseText)
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
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
        button.attributedTitle = NSAttributedString(string: "")

        if let name = monitor.menuBarNameText, !monitor.timePhraseText.isEmpty {
            button.title = ""
            if monitor.isUrgent {
                button.image = renderLabelImage(
                    MenuBarPill(meetingName: name, timePhrase: monitor.timePhraseText)
                )
            } else {
                button.image = renderLabelImage(
                    MenuBarStandardLabel(meetingName: name, timePhrase: monitor.timePhraseText)
                )
            }
            button.imagePosition = .imageOnly
        } else {
            button.image = templateCalendarIcon()
            button.title = text
            button.imagePosition = .imageLeading
        }
        button.toolTip = statusItemToolTip(fallback: text)
    }

    private func renderLabelImage<V: View>(_ content: V) -> NSImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }

    private func statusItemToolTip(fallback: String) -> String {
        guard let meeting = monitor.meeting else { return fallback }
        let phrase = monitor.timePhraseText
        if phrase.isEmpty {
            return meeting.title
        }
        return "\(meeting.title) \(phrase)"
    }

    private func truncatedMenuEventName(_ name: String) -> String {
        guard name.count > Metrics.menuEventNameLimit else { return name }
        return String(name.prefix(Metrics.menuEventNameLimit)) + "…"
    }

    private func eventsMatch(_ lhs: MeetingSnapshot, _ rhs: MeetingSnapshot) -> Bool {
        lhs.eventIdentifier == rhs.eventIdentifier
            || (lhs.start == rhs.start && lhs.title == rhs.title)
    }

    private func templateMenuSymbol(
        systemSymbolName: String,
        accessibilityDescription: String
    ) -> NSImage? {
        let pointSize = NSFont.menuFont(ofSize: NSFont.smallSystemFontSize).pointSize
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        guard let symbol = NSImage(
            systemSymbolName: systemSymbolName,
            accessibilityDescription: accessibilityDescription
        )?.withSymbolConfiguration(configuration) else {
            return nil
        }
        symbol.isTemplate = true
        return symbol
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
            let now = Date()
            let menuHighlight = monitor.inProgressMeeting ?? meeting
            let dayEvents = monitor.eventsForDay(containing: meeting.start)
            for event in dayEvents {
                let timeString = event.start.formatted(date: .omitted, time: .shortened)
                let title = "\(timeString)  \(truncatedMenuEventName(event.title))"
                let item = NSMenuItem(
                    title: title,
                    action: #selector(eventMenuItemActivated(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = event
                item.isEnabled = true
                let isFeatured = eventsMatch(event, menuHighlight)
                if isFeatured {
                    if let inProgress = monitor.inProgressMeeting, eventsMatch(event, inProgress) {
                        item.state = .on
                    } else {
                        item.image = templateMenuSymbol(
                            systemSymbolName: MenuSymbols.upcomingEvent,
                            accessibilityDescription: "Upcoming"
                        )
                    }
                }
                let isPast = event.end <= now
                let menuFont = NSFont.menuFont(ofSize: NSFont.systemFontSize)
                if isPast {
                    item.attributedTitle = NSAttributedString(
                        string: title,
                        attributes: [
                            .foregroundColor: NSColor.secondaryLabelColor,
                            .font: menuFont,
                        ]
                    )
                } else {
                    item.attributedTitle = NSAttributedString(
                        string: title,
                        attributes: [
                            .foregroundColor: NSColor.labelColor,
                            .font: NSFont.systemFont(ofSize: menuFont.pointSize, weight: .semibold),
                        ]
                    )
                }
                menu.addItem(item)
            }
            if dayEvents.isEmpty {
                menu.addItem(withTitle: "No events today", action: nil, keyEquivalent: "")
            }
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

    @objc private func eventMenuItemActivated(_ sender: NSMenuItem) {
        guard let event = sender.representedObject as? MeetingSnapshot else { return }
        monitor.openEvent(event)
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
