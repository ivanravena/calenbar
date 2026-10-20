import AppKit
import Combine
import EventKit
import Foundation

struct MeetingSnapshot: Equatable {
    let eventIdentifier: String
    let calendarItemIdentifier: String
    let title: String
    let start: Date
    let end: Date
    let calendarTitle: String
    /// Video or conference link from the calendar event, when present.
    let joinURL: URL?

    /// Compact duration for status menu rows (e.g. `30 min`, `1 h 15 min`).
    var menuDurationLabel: String {
        Self.durationLabel(from: start, to: end)
    }

    private static func durationLabel(from start: Date, to end: Date) -> String {
        let seconds = max(0, end.timeIntervalSince(start))
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            let shown = max(minutes, 1)
            return "\(shown) min"
        }

        let hours = minutes / 60
        let remainder = minutes % 60
        let hourPart = "\(hours) h"
        guard remainder > 0 else { return hourPart }
        return "\(hourPart) \(remainder) min"
    }
}

enum CalendarAccess: Equatable {
    case unknown
    case granted
    case denied
}

@MainActor
final class MeetingMonitor: ObservableObject {
    /// Menu bar and primary actions (rolls to next meeting after join grace).
    @Published private(set) var meeting: MeetingSnapshot?
    /// Meeting in progress now, if any (used for menu bar roll-forward and “Open in Calendar”).
    @Published private(set) var inProgressMeeting: MeetingSnapshot?
    @Published private(set) var access: CalendarAccess = .unknown
    @Published private(set) var labelText: String = "Calendar"
    @Published private(set) var meetingNameText: String?
    /// Truncated name shown in the menu bar next to the time phrase.
    @Published private(set) var menuBarNameText: String?
    @Published private(set) var timePhraseText: String = ""
    @Published private(set) var isUrgent: Bool = false
    /// Featured meeting can be joined now (has a link and is in progress).
    @Published private(set) var canJoinFeaturedMeeting: Bool = false

    private let store = EKEventStore()
    private var timer: Timer?
    private let lookahead: TimeInterval = 36 * 60 * 60
    private let urgentThreshold: TimeInterval = 10 * 60
    private let joinGrace: TimeInterval = 120
    private static let menuBarEventNameLimit = 12

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

    func openEvent(_ event: MeetingSnapshot) {
        if let url = Self.calendarEventURL(
            start: event.start,
            calendarItemIdentifier: event.calendarItemIdentifier
        ) {
            NSWorkspace.shared.open(url)
            return
        }
        if let url = URL(string: "ical://") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCalendar() {
        guard let target = inProgressMeeting ?? meeting else { return }
        openEvent(target)
    }

    func joinMeeting(_ event: MeetingSnapshot) {
        guard Self.canJoin(event: event, now: Date()), let url = event.joinURL else { return }
        NSWorkspace.shared.open(url)
    }

    func joinFeaturedMeeting() {
        guard let meeting else { return }
        joinMeeting(meeting)
    }

    static func canJoin(event: MeetingSnapshot, now: Date) -> Bool {
        guard let joinURL = event.joinURL else { return false }
        guard !joinURL.absoluteString.isEmpty else { return false }
        return now >= event.start && now < event.end
    }

    /// macOS Calendar.app deep link (Sonoma+). `calshow:` is iOS-only and is not registered on macOS.
    private static func calendarEventURL(start: Date, calendarItemIdentifier: String) -> URL? {
        guard !calendarItemIdentifier.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let dateString = formatter.string(from: start)

        var components = URLComponents()
        components.scheme = "ical"
        components.host = "ekevent"
        components.path = "/\(dateString)/\(calendarItemIdentifier)"
        components.queryItems = [
            URLQueryItem(name: "method", value: "show"),
            URLQueryItem(name: "options", value: "more"),
        ]
        return components.url
    }

    func openPrivacySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars"
        )!
        NSWorkspace.shared.open(url)
    }

    /// Timed events on the same calendar day as `referenceDate`, including events that already ended.
    func eventsForDay(containing referenceDate: Date) -> [MeetingSnapshot] {
        guard access == .granted else { return [] }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
        return store.events(matching: predicate)
            .filter { Self.isEligibleForDayMenu($0) }
            .sorted { $0.startDate < $1.startDate }
            .map { Self.snapshot(from: $0) }
    }

    @objc private func storeChanged() {
        refresh()
    }

    private func refresh() {
        guard access == .granted else {
            meeting = nil
            inProgressMeeting = nil
            meetingNameText = nil
            menuBarNameText = nil
            timePhraseText = ""
            labelText = access == .denied ? "Calendar access off" : "Calendar"
            isUrgent = false
            canJoinFeaturedMeeting = false
            return
        }

        let now = Date()
        let queryStart = now.addingTimeInterval(-lookahead)
        let windowEnd = now.addingTimeInterval(lookahead)
        let predicate = store.predicateForEvents(withStart: queryStart, end: windowEnd, calendars: nil)

        let candidates = store.events(matching: predicate)
            .filter { Self.isRelevant($0, now: now) }

        let inProgressEvent = candidates.first { $0.startDate <= now && $0.endDate > now }
        let nextUpcomingEvent = candidates
            .filter { $0.startDate > now }
            .min { $0.startDate < $1.startDate }

        let featuredEvent: EKEvent?
        if let inProgressEvent {
            let withinJoinGrace = now.timeIntervalSince(inProgressEvent.startDate) < joinGrace
            if withinJoinGrace {
                featuredEvent = inProgressEvent
            } else if let nextUpcomingEvent {
                featuredEvent = nextUpcomingEvent
            } else {
                featuredEvent = inProgressEvent
            }
        } else {
            featuredEvent = nextUpcomingEvent
                ?? candidates.min { $0.startDate < $1.startDate }
        }

        inProgressMeeting = inProgressEvent.map { Self.snapshot(from: $0) }
        meeting = featuredEvent.map { Self.snapshot(from: $0) }

        if let meeting {
            let name = meeting.title
            let joinable = Self.canJoin(event: meeting, now: now)
            let timePhrase = joinable ? "Join now" : Self.phrase(until: meeting.start)
            let menuBarName = Self.truncatedMenuBarEventName(name)
            meetingNameText = name
            menuBarNameText = menuBarName
            timePhraseText = timePhrase
            canJoinFeaturedMeeting = joinable
            labelText = "\(menuBarName) \(timePhrase)"
            isUrgent = Self.isUrgent(
                featured: meeting,
                inProgress: inProgressMeeting,
                now: now,
                urgentThreshold: urgentThreshold,
                joinGrace: joinGrace
            )
        } else {
            meetingNameText = nil
            menuBarNameText = nil
            timePhraseText = ""
            labelText = "Calendar"
            isUrgent = false
            canJoinFeaturedMeeting = false
        }
    }

    private static func isUrgent(
        featured: MeetingSnapshot,
        inProgress: MeetingSnapshot?,
        now: Date,
        urgentThreshold: TimeInterval,
        joinGrace: TimeInterval
    ) -> Bool {
        let secondsToStart = featured.start.timeIntervalSince(now)
        if secondsToStart > 0, secondsToStart < urgentThreshold {
            return true
        }
        if let inProgress,
           featured.eventIdentifier == inProgress.eventIdentifier,
           now.timeIntervalSince(inProgress.start) < joinGrace {
            return true
        }
        return false
    }

    private static func isRelevant(_ event: EKEvent, now: Date) -> Bool {
        guard isEligibleForDayMenu(event), event.endDate > now else {
            return false
        }
        return true
    }

    private static func isEligibleForDayMenu(_ event: EKEvent) -> Bool {
        guard !event.isAllDay, event.status != .canceled else {
            return false
        }
        if let me = event.attendees?.first(where: \.isCurrentUser),
           me.participantStatus == .declined {
            return false
        }
        return true
    }

    private static func snapshot(from event: EKEvent) -> MeetingSnapshot {
        MeetingSnapshot(
            eventIdentifier: event.eventIdentifier ?? "",
            calendarItemIdentifier: event.calendarItemIdentifier,
            title: event.title?.isEmpty == false ? event.title! : "Untitled",
            start: event.startDate,
            end: event.endDate,
            calendarTitle: event.calendar.title,
            joinURL: event.url
        )
    }

    private static func truncatedMenuBarEventName(_ name: String) -> String {
        guard name.count > menuBarEventNameLimit else { return name }
        return String(name.prefix(menuBarEventNameLimit)) + "…"
    }

    private static func phrase(until start: Date, now: Date = .now) -> String {
        let seconds = start.timeIntervalSince(now)
        if seconds <= 0 { return "now" }

        let minutes = Int(seconds / 60)
        if minutes < 60 {
            let shown = max(minutes, 1)
            return "in \(shown) min"
        }

        let hours = minutes / 60
        let remainder = minutes % 60
        let hourPart = "\(hours) h"
        guard remainder > 0 else { return "in \(hourPart)" }
        return "in \(hourPart) \(remainder) min"
    }

}
