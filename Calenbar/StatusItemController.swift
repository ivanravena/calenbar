import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private enum Metrics {
        /// Extra space between the calendar symbol and the title on the status item.
        static let iconTitleSpacing: CGFloat = 6
        static let menuEventNameLimit = 24
    }

    private let monitor: MeetingMonitor
    private let settings: AppSettings
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    /// Guards `performClick` re-entry while presenting `statusItem.menu`.
    private var isPresentingMenu = false

    init(monitor: MeetingMonitor, settings: AppSettings) {
        self.monitor = monitor
        self.settings = settings
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
            Publishers.CombineLatest3(
                monitor.$menuBarNameText,
                monitor.$timePhraseText,
                monitor.$showsJoinNow
            )
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.applyPresentation()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest3(
            settings.$menuBarContentStyle,
            settings.$alertColor,
            settings.$joinNowColor
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _, _ in
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
            let joinPhraseAsButton = monitor.showsJoinNow
            let displayName = settings.showsEventTitle ? name : ""
            let showsEventTitle = settings.showsEventTitle
            let alertColor = settings.alertColor.color
            let joinNowColor = settings.joinNowColor.color
            if monitor.isUrgent {
                button.image = renderLabelImage(
                    MenuBarPill(
                        meetingName: displayName,
                        timePhrase: monitor.timePhraseText,
                        joinPhraseAsButton: joinPhraseAsButton,
                        showsEventTitle: showsEventTitle,
                        alertColor: alertColor,
                        joinNowColor: joinNowColor
                    )
                )
            } else {
                button.image = renderLabelImage(
                    MenuBarStandardLabel(
                        meetingName: displayName,
                        timePhrase: monitor.timePhraseText,
                        joinPhraseAsButton: joinPhraseAsButton,
                        showsEventTitle: showsEventTitle,
                        joinNowColor: joinNowColor
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
        if monitor.showsJoinNow, let joinable = monitor.joinableMeeting {
            return "\(joinable.title) — Click to join"
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
        if isPresentingMenu {
            return
        }
        guard let event = NSApp.currentEvent else { return }
        if monitor.showsJoinNow, event.type != .rightMouseUp {
            monitor.joinFeaturedMeeting()
            return
        }
        guard let statusItem else { return }
        let menu = buildMenu()
        menu.delegate = self
        isPresentingMenu = true
        statusItem.menu = menu
        sender.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem?.menu = nil
        isPresentingMenu = false
        menu.delegate = nil
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
            menu.addItem(MenuSectionHeader.menuItem(title: "Next event"))
            if monitor.showsMenuJoin {
                let joinItem = menu.addItem(
                    withTitle: "Join",
                    action: #selector(joinFeaturedMeeting),
                    keyEquivalent: ""
                )
                joinItem.target = self
            }
            if monitor.showsJoinNow {
                let dismissItem = menu.addItem(
                    withTitle: "Dismiss",
                    action: #selector(dismissJoinNow),
                    keyEquivalent: ""
                )
                dismissItem.target = self
            }
            menu.addItem(
                withTitle: "View event",
                action: #selector(openCalendar),
                keyEquivalent: ""
            ).target = self
            menu.addItem(NSMenuItem.separator())
            menu.addItem(MenuSectionHeader.menuItem(title: "Today"))
            let dayEvents = monitor.eventsForDay(containing: meeting.start)
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
                menu.addItem(item)
            }
            if dayEvents.isEmpty {
                menu.addItem(withTitle: "No events today", action: nil, keyEquivalent: "")
            }
        } else if monitor.access == .unknown {
            menu.addItem(withTitle: "Requesting calendar access…", action: nil, keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "No upcoming meetings", action: nil, keyEquivalent: "")
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(MenuSectionHeader.menuItem(title: AppVersion.menuSectionTitle))
        let settingsItem = menu.addItem(
            withTitle: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
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

    @objc private func dismissJoinNow() {
        monitor.dismissJoinNow()
    }

    @objc private func openCalendar() {
        monitor.openCalendar()
    }

    @objc private func openPrivacySettings() {
        monitor.openPrivacySettings()
    }

    @objc private func openSettings() {
        SettingsPresenter.show()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
