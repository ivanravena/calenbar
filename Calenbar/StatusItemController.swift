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
        .combineLatest(
            monitor.$menuBarNameText,
            monitor.$timePhraseText,
            monitor.$canJoinFeaturedMeeting
        )
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
            let joinPhraseAsButton = monitor.canJoinFeaturedMeeting
            if monitor.isUrgent {
                button.image = renderLabelImage(
                    MenuBarPill(
                        meetingName: name,
                        timePhrase: monitor.timePhraseText,
                        joinPhraseAsButton: joinPhraseAsButton
                    )
                )
            } else {
                button.image = renderLabelImage(
                    MenuBarStandardLabel(
                        meetingName: name,
                        timePhrase: monitor.timePhraseText,
                        joinPhraseAsButton: joinPhraseAsButton
                    )
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
        if monitor.canJoinFeaturedMeeting {
            return "\(meeting.title) — Click to join"
        }
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
        let pointSize = NSFont.menuFont(ofSize: NSFont.systemFontSize).pointSize
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let symbol = NSImage(
            systemSymbolName: systemSymbolName,
            accessibilityDescription: accessibilityDescription
        )?.withSymbolConfiguration(configuration) else {
            return nil
        }
        symbol.isTemplate = true
        return symbol
    }

    private func applyMenuEventIndicator(
        to item: NSMenuItem,
        event: MeetingSnapshot,
        nextUpcomingInMenu: MeetingSnapshot?
    ) {
        item.state = .off
        item.image = nil

        guard let nextUpcomingInMenu, eventsMatch(event, nextUpcomingInMenu) else { return }

        item.image = upcomingEventMenuIcon()
    }

    private func upcomingEventMenuIcon() -> NSImage? {
        if let upcoming = templateMenuSymbol(
            systemSymbolName: "upcoming",
            accessibilityDescription: "Upcoming"
        ) {
            return upcoming
        }
        return templateMenuSymbol(
            systemSymbolName: MenuSymbols.upcomingEvent,
            accessibilityDescription: "Upcoming"
        )
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
        if monitor.canJoinFeaturedMeeting, event.type != .rightMouseUp {
            monitor.joinFeaturedMeeting()
            return
        }
        let menu = buildMenu()
        let location = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: location, in: sender)
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
            if monitor.canJoinFeaturedMeeting {
                menu.addItem(
                    withTitle: "Join now",
                    action: #selector(joinFeaturedMeeting),
                    keyEquivalent: ""
                ).target = self
                menu.addItem(NSMenuItem.separator())
            }
            let dayEvents = monitor.eventsForDay(containing: meeting.start)
            let nextUpcomingInMenu = dayEvents.first { $0.start > now }
            let timeStrings = dayEvents.map { $0.start.formatted(date: .omitted, time: .shortened) }
            let durationStrings = dayEvents.map(\.menuDurationLabel)
            let columnWidths = MenuEventRow.columnWidths(
                timeStrings: timeStrings,
                durationStrings: durationStrings
            )
            for event in dayEvents {
                let timeString = event.start.formatted(date: .omitted, time: .shortened)
                let eventTitle = truncatedMenuEventName(event.title)
                let accessibilityTitle =
                    "\(timeString)  \(event.menuDurationLabel)  \(eventTitle)"
                let isPast = event.end <= now
                let item = NSMenuItem(
                    title: accessibilityTitle,
                    action: #selector(eventMenuItemActivated(_:)),
                    keyEquivalent: ""
                )
                item.attributedTitle = MenuEventRow.attributedTitle(
                    timeText: timeString,
                    durationText: event.menuDurationLabel,
                    titleText: eventTitle,
                    isPast: isPast,
                    timeColumnWidth: columnWidths.time,
                    durationColumnWidth: columnWidths.duration
                )
                item.target = self
                item.representedObject = event
                item.isEnabled = true
                applyMenuEventIndicator(
                    to: item,
                    event: event,
                    nextUpcomingInMenu: nextUpcomingInMenu
                )
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

    @objc private func joinFeaturedMeeting() {
        monitor.joinFeaturedMeeting()
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
