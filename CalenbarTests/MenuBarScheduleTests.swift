import Foundation
import XCTest

@testable import Calenbar

final class MenuBarScheduleTests: XCTestCase {
    private let joinURL = URL(string: "https://meet.example.com/room")!

    private func eventResult(from display: MenuBarDisplay?) -> MenuBarScheduleResult? {
        guard case .event(let result) = display else { return nil }
        return result
    }

    private func eveningNowAndTomorrowMorning() -> (now: Date, tomorrow: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let now = dayStart.addingTimeInterval(20 * 3600)
        let tomorrow = dayStart.addingTimeInterval(24 * 3600 + 9 * 3600)
        return (now, tomorrow)
    }

    func testIdleShowsCountdownToNext() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let next = meeting(
            id: "next",
            title: "Standup",
            start: now.addingTimeInterval(30 * 60),
            joinURL: joinURL
        )

        let result = eventResult(from: MenuBarSchedule.resolve(running: nil, next: next, now: now))

        XCTAssertEqual(result?.displayedMeeting.eventIdentifier, "next")
        XCTAssertEqual(result?.phraseKind, .untilStart)
        XCTAssertEqual(result?.phraseText, "in 30 min")
    }

    func testRunningWithDistantNextShowsTimeRemaining() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let running = meeting(
            id: "run",
            title: "Deep work",
            start: now.addingTimeInterval(-20 * 60),
            end: now.addingTimeInterval(40 * 60),
            joinURL: joinURL
        )
        let next = meeting(
            id: "next",
            title: "Later",
            start: now.addingTimeInterval(60 * 60),
            joinURL: joinURL
        )

        let result = eventResult(from: MenuBarSchedule.resolve(running: running, next: next, now: now))

        XCTAssertEqual(result?.displayedMeeting.eventIdentifier, "run")
        XCTAssertEqual(result?.phraseKind, .remaining)
        XCTAssertEqual(result?.phraseText, "40 min left")
    }

    func testRunningWithNoNextShowsTimeRemaining() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let running = meeting(
            id: "run",
            title: "Solo",
            start: now.addingTimeInterval(-5 * 60),
            end: now.addingTimeInterval(25 * 60),
            joinURL: joinURL
        )

        let result = eventResult(from: MenuBarSchedule.resolve(running: running, next: nil, now: now))

        XCTAssertEqual(result?.phraseKind, .remaining)
        XCTAssertEqual(result?.phraseText, "25 min left")
    }

    func testHandoffAtFifteenMinutesShowsNextCountdown() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let running = meeting(
            id: "run",
            title: "Current",
            start: now.addingTimeInterval(-30 * 60),
            end: now.addingTimeInterval(30 * 60),
            joinURL: joinURL
        )
        let next = meeting(
            id: "next",
            title: "Upcoming",
            start: now.addingTimeInterval(15 * 60),
            joinURL: joinURL
        )

        let result = eventResult(from: MenuBarSchedule.resolve(running: running, next: next, now: now))

        XCTAssertEqual(result?.displayedMeeting.eventIdentifier, "next")
        XCTAssertEqual(result?.phraseKind, .untilStart)
        XCTAssertEqual(result?.phraseText, "in 15 min")
    }

    func testJoinNowForNextWithinTwoMinutesOverridesRunningHold() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let running = meeting(
            id: "run",
            title: "Current",
            start: now.addingTimeInterval(-4 * 60),
            end: now.addingTimeInterval(26 * 60),
            joinURL: joinURL
        )
        let next = meeting(
            id: "next",
            title: "Next",
            start: now.addingTimeInterval(90),
            joinURL: joinURL
        )

        let result = eventResult(from: MenuBarSchedule.resolve(running: running, next: next, now: now))

        XCTAssertEqual(result?.displayedMeeting.eventIdentifier, "next")
        XCTAssertEqual(result?.phraseKind, .joinNow)
        XCTAssertEqual(result?.phraseText, "Join now")
    }

    func testJoinNowHoldForFiveMinutesAfterStartBeatsNearbyNext() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let running = meeting(
            id: "run",
            title: "Current",
            start: now.addingTimeInterval(-2 * 60),
            end: now.addingTimeInterval(28 * 60),
            joinURL: joinURL
        )
        let next = meeting(
            id: "next",
            title: "Soon",
            start: now.addingTimeInterval(10 * 60),
            joinURL: joinURL
        )

        let result = eventResult(from: MenuBarSchedule.resolve(running: running, next: next, now: now))

        XCTAssertEqual(result?.displayedMeeting.eventIdentifier, "run")
        XCTAssertEqual(result?.phraseKind, .joinNow)
    }

    func testHoldEndsAtFiveMinutesAfterStart() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let running = meeting(
            id: "run",
            title: "Current",
            start: now.addingTimeInterval(-5 * 60),
            end: now.addingTimeInterval(25 * 60),
            joinURL: joinURL
        )
        let next = meeting(
            id: "next",
            title: "Soon",
            start: now.addingTimeInterval(10 * 60),
            joinURL: joinURL
        )

        let result = eventResult(from: MenuBarSchedule.resolve(running: running, next: next, now: now))

        XCTAssertEqual(result?.displayedMeeting.eventIdentifier, "next")
        XCTAssertEqual(result?.phraseKind, .untilStart)
    }

    func testNoJoinURLFallsThroughToCountdownOrRemaining() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let nextSoon = meeting(
            id: "next",
            title: "No link",
            start: now.addingTimeInterval(90),
            joinURL: nil
        )

        let idle = eventResult(from: MenuBarSchedule.resolve(running: nil, next: nextSoon, now: now))
        XCTAssertEqual(idle?.phraseKind, .untilStart)
        XCTAssertEqual(idle?.phraseText, "in 1 min")

        let running = meeting(
            id: "run",
            title: "No link",
            start: now.addingTimeInterval(-60),
            end: now.addingTimeInterval(30 * 60),
            joinURL: nil
        )
        let during = eventResult(from: MenuBarSchedule.resolve(running: running, next: nil, now: now))
        XCTAssertEqual(during?.phraseKind, .remaining)
    }

    func testJoinNowSuppressionSkipsNextWithinTwoMinutes() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let next = meeting(
            id: "next",
            title: "Soon",
            start: now.addingTimeInterval(90),
            joinURL: joinURL
        )

        let result = eventResult(from: MenuBarSchedule.resolve(
            running: nil,
            next: next,
            now: now,
            isJoinNowSuppressed: { $0.eventIdentifier == "next" }
        ))

        XCTAssertEqual(result?.phraseKind, .untilStart)
        XCTAssertEqual(result?.phraseText, "in 1 min")
    }

    func testJoinNowSuppressionSkipsRunningHold() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let running = meeting(
            id: "run",
            title: "Current",
            start: now.addingTimeInterval(-60),
            end: now.addingTimeInterval(30 * 60),
            joinURL: joinURL
        )

        let result = eventResult(from: MenuBarSchedule.resolve(
            running: running,
            next: nil,
            now: now,
            isJoinNowSuppressed: { $0.eventIdentifier == "run" }
        ))

        XCTAssertEqual(result?.phraseKind, .remaining)
    }

    func testUrgentForJoinNowAndNearCountdown() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let join = MenuBarScheduleResult(
            displayedMeeting: meeting(
                id: "j",
                title: "J",
                start: now,
                joinURL: joinURL
            ),
            phraseKind: .joinNow,
            phraseText: "Join now"
        )
        XCTAssertTrue(MenuBarSchedule.isUrgent(result: join, now: now))

        let soon = MenuBarScheduleResult(
            displayedMeeting: meeting(
                id: "s",
                title: "S",
                start: now.addingTimeInterval(5 * 60),
                joinURL: joinURL
            ),
            phraseKind: .untilStart,
            phraseText: "in 5 min"
        )
        XCTAssertTrue(MenuBarSchedule.isUrgent(result: soon, now: now))

        let later = MenuBarScheduleResult(
            displayedMeeting: meeting(
                id: "l",
                title: "L",
                start: now.addingTimeInterval(20 * 60),
                joinURL: joinURL
            ),
            phraseKind: .untilStart,
            phraseText: "in 20 min"
        )
        XCTAssertFalse(MenuBarSchedule.isUrgent(result: later, now: now))
    }

    func testNextBoundaryIncludesJoinAndHoldTransitions() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let running = meeting(
            id: "run",
            title: "Run",
            start: now.addingTimeInterval(-60),
            end: now.addingTimeInterval(30 * 60),
            joinURL: joinURL
        )
        let next = meeting(
            id: "next",
            title: "Next",
            start: now.addingTimeInterval(20 * 60),
            joinURL: joinURL
        )

        let boundary = MenuBarSchedule.nextBoundary(running: running, next: next, now: now)
        let holdEnd = running.start.addingTimeInterval(MenuBarSchedule.joinNowHoldAfterStart)
        XCTAssertEqual(boundary, holdEnd)
    }

    func testCanJoinWithinEarlyWindow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let event = meeting(
            id: "e",
            title: "E",
            start: now.addingTimeInterval(8 * 60),
            joinURL: joinURL
        )
        XCTAssertTrue(
            MenuBarSchedule.canJoin(
                event: event,
                now: now,
                earlyJoin: MenuBarSchedule.earlyJoinWindow
            )
        )
    }

    func testMeetingInSeventyMinutesDoesNotShowJoinNow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let next = meeting(
            id: "next",
            title: "Later",
            start: now.addingTimeInterval(70 * 60),
            joinURL: joinURL
        )

        let result = eventResult(from: MenuBarSchedule.resolve(running: nil, next: next, now: now))

        XCTAssertEqual(result?.phraseKind, .untilStart)
        XCTAssertEqual(result?.phraseText, "in 1 h 10 min")
        XCTAssertFalse(
            MenuBarSchedule.shouldShowJoinNow(meeting: next, now: now, isSuppressed: false)
        )
    }

    func testShouldShowJoinNowWithinTwoMinuteLead() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let next = meeting(
            id: "next",
            title: "Soon",
            start: now.addingTimeInterval(90),
            joinURL: joinURL
        )
        XCTAssertTrue(
            MenuBarSchedule.shouldShowJoinNow(meeting: next, now: now, isSuppressed: false)
        )
    }

    func testIdleWithNextOnLaterDayShowsDoneForToday() {
        let (now, tomorrow) = eveningNowAndTomorrowMorning()
        let next = meeting(
            id: "next",
            title: "Morning standup",
            start: tomorrow,
            joinURL: joinURL
        )

        let display = MenuBarSchedule.resolve(running: nil, next: next, now: now)

        XCTAssertEqual(display, .noMoreEventsToday)
    }

    func testRunningWithNextOnLaterDayShowsTimeRemaining() {
        let (now, tomorrow) = eveningNowAndTomorrowMorning()
        let running = meeting(
            id: "run",
            title: "Late call",
            start: now.addingTimeInterval(-30 * 60),
            end: now.addingTimeInterval(15 * 60),
            joinURL: joinURL
        )
        let next = meeting(
            id: "next",
            title: "Morning standup",
            start: tomorrow,
            joinURL: joinURL
        )

        let result = eventResult(from: MenuBarSchedule.resolve(running: running, next: next, now: now))

        XCTAssertEqual(result?.displayedMeeting.eventIdentifier, "run")
        XCTAssertEqual(result?.phraseKind, .remaining)
    }

    func testJoinNowForNextTomorrowWithinTwoMinutes() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let now = dayStart.addingTimeInterval(24 * 3600 - 90)
        let nextStart = dayStart.addingTimeInterval(24 * 3600 + 30)
        XCTAssertFalse(calendar.isDate(nextStart, inSameDayAs: now))
        let next = meeting(
            id: "next",
            title: "Midnight sync",
            start: nextStart,
            joinURL: joinURL
        )

        let result = eventResult(from: MenuBarSchedule.resolve(running: nil, next: next, now: now))

        XCTAssertEqual(result?.phraseKind, .joinNow)
    }

    private func meeting(
        id: String,
        title: String,
        start: Date,
        end: Date? = nil,
        joinURL: URL?
    ) -> MeetingSnapshot {
        MeetingSnapshot(
            eventIdentifier: id,
            calendarItemIdentifier: id,
            title: title,
            start: start,
            end: end ?? start.addingTimeInterval(60 * 60),
            calendarTitle: "Work",
            joinURL: joinURL
        )
    }
}
