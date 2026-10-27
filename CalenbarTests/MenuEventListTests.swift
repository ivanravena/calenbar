import Foundation
import XCTest

@testable import Calenbar

final class MenuEventListTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_000_000)

    func testEmptyDay() {
        let result = MenuEventList.window([], now: base)
        XCTAssertTrue(result.visibleEvents.isEmpty)
        XCTAssertEqual(result.hiddenCount, 0)
    }

    func testAllPastAnchorsOnLastEvent() {
        let events = [
            event(id: "a", start: base.addingTimeInterval(-3 * 3600)),
            event(id: "b", start: base.addingTimeInterval(-2 * 3600)),
            event(id: "c", start: base.addingTimeInterval(-3600)),
        ]
        let result = MenuEventList.window(events, now: base, maxRows: 12)
        XCTAssertEqual(result.visibleEvents.map(\.eventIdentifier), ["a", "b", "c"])
        XCTAssertEqual(result.hiddenCount, 0)
    }

    func testWindowCentersOnNextUpcoming() {
        let events = (0..<8).map { index in
            event(id: "\(index)", start: base.addingTimeInterval(Double(index) * 3600))
        }
        let now = base.addingTimeInterval(3.5 * 3600)
        let result = MenuEventList.window(events, now: now, maxRows: 4)

        XCTAssertEqual(result.visibleEvents.map(\.eventIdentifier), ["2", "3", "4", "5"])
        XCTAssertEqual(result.hiddenCount, 4)
    }

    func testMaxRowsCapsVisibleSlice() {
        let events = (0..<20).map { index in
            event(id: "\(index)", start: base.addingTimeInterval(Double(index) * 600))
        }
        let now = base
        let result = MenuEventList.window(events, now: now, maxRows: 5)

        XCTAssertEqual(result.visibleEvents.count, 5)
        XCTAssertEqual(result.hiddenCount, 15)
    }

    func testNoFutureEventsUsesLastAsAnchor() {
        let events = [
            event(id: "1", start: base.addingTimeInterval(-7200)),
            event(id: "2", start: base.addingTimeInterval(-3600)),
        ]
        let result = MenuEventList.window(events, now: base, maxRows: 12)
        XCTAssertEqual(result.visibleEvents.map(\.eventIdentifier), ["1", "2"])
        XCTAssertEqual(result.hiddenCount, 0)
    }

    private func event(id: String, start: Date) -> MeetingSnapshot {
        MeetingSnapshot(
            eventIdentifier: id,
            calendarItemIdentifier: id,
            title: "Event \(id)",
            start: start,
            end: start.addingTimeInterval(3600),
            calendarTitle: "Work",
            joinURL: nil
        )
    }
}
