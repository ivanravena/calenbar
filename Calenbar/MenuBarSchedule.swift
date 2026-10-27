import Foundation

enum MenuBarTimePhraseKind: Equatable {
    case joinNow
    case untilStart
    case remaining
}

struct MenuBarScheduleResult: Equatable {
    let displayedMeeting: MeetingSnapshot
    let phraseKind: MenuBarTimePhraseKind
    let phraseText: String
}

enum MenuBarSchedule {
    static let joinNowLead: TimeInterval = 2 * 60
    static let nextHandoffLead: TimeInterval = 15 * 60
    static let joinNowHoldAfterStart: TimeInterval = 5 * 60
    static let urgentCountdownThreshold: TimeInterval = 10 * 60
    static let earlyJoinWindow: TimeInterval = 10 * 60

    static func resolve(
        running: MeetingSnapshot?,
        next: MeetingSnapshot?,
        now: Date,
        isJoinNowSuppressed: (MeetingSnapshot) -> Bool = { _ in false }
    ) -> MenuBarScheduleResult? {
        if let next,
           hasJoinURL(next),
           next.start.timeIntervalSince(now) <= joinNowLead {
            return result(for: next, kind: .joinNow, now: now)
        }

        if let running,
           hasJoinURL(running),
           now.timeIntervalSince(running.start) < joinNowHoldAfterStart,
           !isJoinNowSuppressed(running) {
            return result(for: running, kind: .joinNow, now: now)
        }

        if running == nil, let next {
            return result(for: next, kind: .untilStart, now: now)
        }

        if let running, let next, next.start.timeIntervalSince(now) <= nextHandoffLead {
            return result(for: next, kind: .untilStart, now: now)
        }

        if let running {
            return result(for: running, kind: .remaining, now: now)
        }

        return nil
    }

    static func isUrgent(result: MenuBarScheduleResult, now: Date) -> Bool {
        switch result.phraseKind {
        case .joinNow:
            return true
        case .untilStart:
            let seconds = result.displayedMeeting.start.timeIntervalSince(now)
            return seconds > 0 && seconds <= urgentCountdownThreshold
        case .remaining:
            return false
        }
    }

    /// Earliest future instant when schedule state or phrase should be recomputed.
    static func nextBoundary(
        running: MeetingSnapshot?,
        next: MeetingSnapshot?,
        now: Date
    ) -> Date? {
        var candidates: [Date] = []

        if let next {
            let joinNext = next.start.addingTimeInterval(-joinNowLead)
            if joinNext > now { candidates.append(joinNext) }
            let handoff = next.start.addingTimeInterval(-nextHandoffLead)
            if handoff > now { candidates.append(handoff) }
            if next.start > now { candidates.append(next.start) }
        }

        if let running {
            let holdEnd = running.start.addingTimeInterval(joinNowHoldAfterStart)
            if holdEnd > now { candidates.append(holdEnd) }
            if running.end > now { candidates.append(running.end) }
        }

        return candidates.min()
    }

    static func hasJoinURL(_ event: MeetingSnapshot) -> Bool {
        guard let joinURL = event.joinURL, !joinURL.absoluteString.isEmpty else { return false }
        return true
    }

    static func canJoin(event: MeetingSnapshot, now: Date, earlyJoin: TimeInterval) -> Bool {
        guard hasJoinURL(event) else { return false }
        let opens = event.start.addingTimeInterval(-earlyJoin)
        return now >= opens && now < event.end
    }

    static func phrase(until start: Date, now: Date) -> String {
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

    static func phrase(remainingUntil end: Date, now: Date) -> String {
        let seconds = end.timeIntervalSince(now)
        if seconds <= 0 { return "now" }

        let minutes = Int(seconds / 60)
        if minutes < 60 {
            let shown = max(minutes, 1)
            return "\(shown) min left"
        }

        let hours = minutes / 60
        let remainder = minutes % 60
        let hourPart = "\(hours) h"
        guard remainder > 0 else { return "\(hourPart) left" }
        return "\(hourPart) \(remainder) min left"
    }

    private static func result(
        for meeting: MeetingSnapshot,
        kind: MenuBarTimePhraseKind,
        now: Date
    ) -> MenuBarScheduleResult {
        let text: String
        switch kind {
        case .joinNow:
            text = "Join now"
        case .untilStart:
            text = phrase(until: meeting.start, now: now)
        case .remaining:
            text = phrase(remainingUntil: meeting.end, now: now)
        }
        return MenuBarScheduleResult(
            displayedMeeting: meeting,
            phraseKind: kind,
            phraseText: text
        )
    }
}
