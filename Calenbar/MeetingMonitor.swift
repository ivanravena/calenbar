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
    /// Event shown in the menu bar label.
    @Published private(set) var meeting: MeetingSnapshot?
    /// Meeting in progress now, if any (used for “Open in Calendar” and menu join while time remains).
    @Published private(set) var inProgressMeeting: MeetingSnapshot?
    @Published private(set) var access: CalendarAccess = .unknown
    @Published private(set) var labelText: String = "Calendar"
    @Published private(set) var meetingNameText: String?
    /// Truncated name shown in the menu bar next to the time phrase.
    @Published private(set) var menuBarNameText: String?
    @Published private(set) var timePhraseText: String = ""
    @Published private(set) var isUrgent: Bool = false
    /// Meeting opened when the user chooses Join from the menu bar or dropdown.
    @Published private(set) var joinableMeeting: MeetingSnapshot?
    @Published private(set) var showsJoinNow: Bool = false
    @Published private(set) var showsMenuJoin: Bool = false
    @Published private(set) var statusItemClickJoins: Bool = false

    private let store = EKEventStore()
    private var pollTimer: Timer?
    private var boundaryTimer: Timer?
    private let lookahead: TimeInterval = 36 * 60 * 60
    private static let menuBarEventNameLimit = 12
    /// Suppress “Join now” for an event until this date after the user joins from Calenbar.
    private var joinNowSuppressUntil: [String: Date] = [:]

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
        self.pollTimer = timer
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
        let now = Date()
        guard MenuBarSchedule.canJoin(event: event, now: now, earlyJoin: MenuBarSchedule.earlyJoinWindow),
              let url = event.joinURL else { return }
        joinNowSuppressUntil[event.eventIdentifier] = event.start.addingTimeInterval(
            MenuBarSchedule.joinNowHoldAfterStart
        )
        NSWorkspace.shared.open(url)
        refresh()
    }

    func joinFeaturedMeeting() {
        guard let joinableMeeting else { return }
        joinMeeting(joinableMeeting)
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
            .map { Self.snapshot(from: $0, store: store) }
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
            joinableMeeting = nil
            showsJoinNow = false
            showsMenuJoin = false
            statusItemClickJoins = false
            boundaryTimer?.invalidate()
            boundaryTimer = nil
            return
        }

        let now = Date()
        pruneJoinSuppression(now: now)

        let queryStart = now.addingTimeInterval(-lookahead)
        let windowEnd = now.addingTimeInterval(lookahead)
        let predicate = store.predicateForEvents(withStart: queryStart, end: windowEnd, calendars: nil)

        let candidates = store.events(matching: predicate)
            .filter { Self.isRelevant($0, now: now) }

        let inProgressEvent = candidates
            .filter { $0.startDate <= now && $0.endDate > now }
            .max(by: { $0.startDate < $1.startDate })

        let nextUpcomingEvent = candidates
            .filter { $0.startDate > now }
            .min { $0.startDate < $1.startDate }

        let runningSnapshot = inProgressEvent.map { Self.snapshot(from: $0, store: store) }
        let nextSnapshot = nextUpcomingEvent.map { Self.snapshot(from: $0, store: store) }

        inProgressMeeting = runningSnapshot

        let schedule = MenuBarSchedule.resolve(
            running: runningSnapshot,
            next: nextSnapshot,
            now: now,
            isJoinNowSuppressed: { [weak self] event in
                self?.isJoinNowSuppressed(event: event, now: now) ?? false
            }
        )

        if let schedule {
            meeting = schedule.displayedMeeting
            let menuBarName = Self.truncatedMenuBarEventName(schedule.displayedMeeting.title)
            meetingNameText = schedule.displayedMeeting.title
            menuBarNameText = menuBarName
            timePhraseText = schedule.phraseText
            labelText = "\(menuBarName) \(schedule.phraseText)"
            isUrgent = MenuBarSchedule.isUrgent(result: schedule, now: now)
            showsJoinNow = schedule.phraseKind == .joinNow

            let earlyJoin = MenuBarSchedule.earlyJoinWindow
            let displayed = schedule.displayedMeeting
            statusItemClickJoins = showsJoinNow
                || (schedule.phraseKind == .untilStart
                    && MenuBarSchedule.canJoin(event: displayed, now: now, earlyJoin: earlyJoin))

            showsMenuJoin = showsJoinNow
                || MenuBarSchedule.canJoin(event: displayed, now: now, earlyJoin: earlyJoin)
                || (schedule.phraseKind == .remaining
                    && runningSnapshot.map {
                        MenuBarSchedule.canJoin(event: $0, now: now, earlyJoin: earlyJoin)
                    } == true)

            joinableMeeting = Self.resolveJoinableMeeting(
                schedule: schedule,
                running: runningSnapshot,
                now: now,
                earlyJoin: earlyJoin
            )
        } else {
            meeting = nil
            meetingNameText = nil
            menuBarNameText = nil
            timePhraseText = ""
            labelText = "Calendar"
            isUrgent = false
            showsJoinNow = false
            showsMenuJoin = false
            statusItemClickJoins = false
            joinableMeeting = nil
        }

        scheduleNextBoundary(running: runningSnapshot, next: nextSnapshot, now: now)
    }

    private static func resolveJoinableMeeting(
        schedule: MenuBarScheduleResult,
        running: MeetingSnapshot?,
        now: Date,
        earlyJoin: TimeInterval
    ) -> MeetingSnapshot? {
        let displayed = schedule.displayedMeeting
        if schedule.phraseKind == .joinNow, MenuBarSchedule.hasJoinURL(displayed) {
            return displayed
        }
        if MenuBarSchedule.canJoin(event: displayed, now: now, earlyJoin: earlyJoin) {
            return displayed
        }
        if schedule.phraseKind == .remaining,
           let running,
           MenuBarSchedule.canJoin(event: running, now: now, earlyJoin: earlyJoin) {
            return running
        }
        return nil
    }

    private func isJoinNowSuppressed(event: MeetingSnapshot, now: Date) -> Bool {
        guard let until = joinNowSuppressUntil[event.eventIdentifier] else { return false }
        return now < until
    }

    private func pruneJoinSuppression(now: Date) {
        joinNowSuppressUntil = joinNowSuppressUntil.filter { now < $0.value }
    }

    private func scheduleNextBoundary(
        running: MeetingSnapshot?,
        next: MeetingSnapshot?,
        now: Date
    ) {
        boundaryTimer?.invalidate()
        boundaryTimer = nil

        guard let boundary = MenuBarSchedule.nextBoundary(running: running, next: next, now: now) else {
            return
        }

        let interval = boundary.timeIntervalSince(now)
        if interval <= 0 {
            refresh()
            return
        }

        let timer = Timer(fire: boundary, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        boundaryTimer = timer
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

    private static func snapshot(from event: EKEvent, store: EKEventStore) -> MeetingSnapshot {
        let resolved = resolvedEvent(event, store: store)
        return MeetingSnapshot(
            eventIdentifier: resolved.eventIdentifier ?? "",
            calendarItemIdentifier: resolved.calendarItemIdentifier,
            title: resolved.title?.isEmpty == false ? resolved.title! : "Untitled",
            start: resolved.startDate,
            end: resolved.endDate,
            calendarTitle: resolved.calendar.title,
            joinURL: ConferenceLinkResolver.joinURL(from: resolved)
        )
    }

    private static func resolvedEvent(_ event: EKEvent, store: EKEventStore) -> EKEvent {
        guard let identifier = event.eventIdentifier,
              let full = store.event(withIdentifier: identifier) else {
            return event
        }
        return full
    }

    private static func truncatedMenuBarEventName(_ name: String) -> String {
        guard name.count > menuBarEventNameLimit else { return name }
        return String(name.prefix(menuBarEventNameLimit)) + "…"
    }
}
