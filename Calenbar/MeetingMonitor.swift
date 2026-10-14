import AppKit
import Combine
import EventKit
import Foundation

struct MeetingSnapshot: Equatable {
    let title: String
    let start: Date
    let end: Date
    let calendarTitle: String
}

enum CalendarAccess: Equatable {
    case unknown
    case granted
    case denied
}

@MainActor
final class MeetingMonitor: ObservableObject {
    @Published private(set) var meeting: MeetingSnapshot?
    @Published private(set) var access: CalendarAccess = .unknown
    @Published private(set) var labelText: String = "Calendar"
    @Published private(set) var meetingNameText: String?
    @Published private(set) var timePhraseText: String = ""
    @Published private(set) var isUrgent: Bool = false

    private let store = EKEventStore()
    private var timer: Timer?
    private let lookahead: TimeInterval = 36 * 60 * 60
    private let urgentThreshold: TimeInterval = 10 * 60

    /// Hide status item when access is granted and there is no upcoming meeting.
    var shouldShowStatusItem: Bool {
        if access == .denied || access == .unknown {
            return true
        }
        return meeting != nil
    }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: store
        )
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Task { await requestAccess() }
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            access = granted ? .granted : .denied
        } catch {
            access = .denied
        }
        refresh()
    }

    func openCalendar() {
        guard let meeting else { return }
        let stamp = meeting.start.timeIntervalSinceReferenceDate
        if let url = URL(string: "calshow:\(stamp)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openPrivacySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars"
        )!
        NSWorkspace.shared.open(url)
    }

    @objc private func storeChanged() {
        refresh()
    }

    private func refresh() {
        guard access == .granted else {
            meeting = nil
            meetingNameText = nil
            timePhraseText = ""
            labelText = access == .denied ? "Calendar access off" : "Calendar"
            isUrgent = false
            return
        }

        let now = Date()
        let queryStart = now.addingTimeInterval(-lookahead)
        let windowEnd = now.addingTimeInterval(lookahead)
        let predicate = store.predicateForEvents(withStart: queryStart, end: windowEnd, calendars: nil)

        let candidates = store.events(matching: predicate)
            .filter { Self.isRelevant($0, now: now) }

        let selected = candidates.first { $0.startDate <= now && $0.endDate > now }
            ?? candidates.min { $0.startDate < $1.startDate }

        meeting = selected.map {
                MeetingSnapshot(
                    title: $0.title?.isEmpty == false ? $0.title! : "Untitled",
                    start: $0.startDate,
                    end: $0.endDate,
                    calendarTitle: $0.calendar.title
                )
            }

        if let meeting {
            let name = Self.truncated(meeting.title)
            let timePhrase = Self.phrase(until: meeting.start)
            meetingNameText = name
            timePhraseText = timePhrase
            labelText = "\(name) \(timePhrase)"
            isUrgent = meeting.start.timeIntervalSinceNow < urgentThreshold
        } else {
            meetingNameText = nil
            timePhraseText = ""
            labelText = "Calendar"
            isUrgent = false
        }
    }

    var supportsCollapse: Bool {
        meeting != nil
    }

    func statusItemDisplay(for level: MenuBarCollapseLevel) -> StatusItemDisplay {
        let toolTip = labelText

        guard supportsCollapse else {
            return StatusItemDisplay(style: .text(labelText), toolTip: toolTip)
        }

        if isUrgent {
            switch level {
            case .full:
                return StatusItemDisplay(style: .pill(text: labelText), toolTip: toolTip)
            case .timeOnly:
                return StatusItemDisplay(style: .pill(text: timePhraseText), toolTip: toolTip)
            case .iconOnly:
                return StatusItemDisplay(style: .pillIcon, toolTip: toolTip)
            }
        }

        switch level {
        case .full:
            return StatusItemDisplay(style: .text(labelText), toolTip: toolTip)
        case .timeOnly:
            return StatusItemDisplay(style: .text(timePhraseText), toolTip: toolTip)
        case .iconOnly:
            return StatusItemDisplay(style: .templateIcon, toolTip: toolTip)
        }
    }

    func measuredWidth(for level: MenuBarCollapseLevel) -> CGFloat {
        guard supportsCollapse else {
            return MenuBarLayoutMetrics.textWidth(labelText, urgent: false)
        }

        if isUrgent {
            return MenuBarLayoutMetrics.pillWidth(
                fullLabel: labelText,
                timePhrase: timePhraseText,
                level: level
            )
        }

        return MenuBarLayoutMetrics.plainTextWidth(
            fullLabel: labelText,
            timePhrase: timePhraseText,
            level: level
        )
    }

    private static func isRelevant(_ event: EKEvent, now: Date) -> Bool {
        guard !event.isAllDay, event.status != .canceled, event.endDate > now else {
            return false
        }
        if let me = event.attendees?.first(where: \.isCurrentUser),
           me.participantStatus == .declined {
            return false
        }
        return true
    }

    private static func phrase(until start: Date, now: Date = .now) -> String {
        let seconds = start.timeIntervalSince(now)
        if seconds <= 0 { return "now" }

        let minutes = Int(seconds / 60)
        if minutes < 60 {
            let shown = max(minutes, 1)
            return shown == 1 ? "in 1 minute" : "in \(shown) minutes"
        }

        let hours = minutes / 60
        let remainder = minutes % 60
        let hourPart = hours == 1 ? "1 hour" : "\(hours) hours"
        guard remainder > 0 else { return "in \(hourPart)" }
        let minutePart = remainder == 1 ? "1 minute" : "\(remainder) minutes"
        return "in \(hourPart) \(minutePart)"
    }

    private static func truncated(_ title: String) -> String {
        title.count > 40 ? String(title.prefix(39)) + "…" : title
    }
}
