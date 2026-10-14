import AppKit
import Combine
import EventKit
import Foundation

struct MeetingSnapshot: Equatable {
    let eventIdentifier: String
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

    func openEvent(at start: Date) {
        let stamp = start.timeIntervalSinceReferenceDate
        if let url = URL(string: "calshow:\(stamp)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCalendar() {
        guard let meeting else { return }
        openEvent(at: meeting.start)
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

        meeting = selected.map { Self.snapshot(from: $0) }

        if let meeting {
            let name = meeting.title
            let timePhrase = Self.phrase(until: meeting.start)
            let menuBarName = Self.truncatedMenuBarEventName(name)
            meetingNameText = name
            timePhraseText = timePhrase
            labelText = "\(menuBarName) \(timePhrase)"
            isUrgent = meeting.start.timeIntervalSinceNow < urgentThreshold
        } else {
            meetingNameText = nil
            timePhraseText = ""
            labelText = "Calendar"
            isUrgent = false
        }
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
            title: event.title?.isEmpty == false ? event.title! : "Untitled",
            start: event.startDate,
            end: event.endDate,
            calendarTitle: event.calendar.title
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
