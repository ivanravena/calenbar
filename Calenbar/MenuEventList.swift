import Foundation

struct MenuEventListWindow: Equatable {
    let visibleEvents: [MeetingSnapshot]
    /// Events from the full day list not shown in `visibleEvents`.
    let hiddenCount: Int
}

enum MenuEventList {
    static let defaultMaxRows = 12

    /// Returns a slice of `events` centered on the next upcoming meeting, capped at `maxRows`.
    static func window(
        _ events: [MeetingSnapshot],
        now: Date,
        maxRows: Int = defaultMaxRows
    ) -> MenuEventListWindow {
        guard !events.isEmpty, maxRows > 0 else {
            return MenuEventListWindow(visibleEvents: [], hiddenCount: 0)
        }

        let nextIndex = events.firstIndex { $0.start > now } ?? (events.count - 1)
        let start = max(0, nextIndex - 2)
        let end = min(events.count, start + maxRows)
        let visible = Array(events[start..<end])
        let hiddenCount = max(0, events.count - visible.count)
        return MenuEventListWindow(visibleEvents: visible, hiddenCount: hiddenCount)
    }
}
