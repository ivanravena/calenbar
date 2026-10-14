import AppKit
import CoreGraphics
import Foundation

enum MenuBarCollapseLevel: Int, Comparable, CaseIterable {
    case full
    case timeOnly
    case iconOnly

    static func < (lhs: MenuBarCollapseLevel, rhs: MenuBarCollapseLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct StatusItemDisplay: Equatable {
    enum Style: Equatable {
        case text(String)
        case pill(text: String)
        case pillIcon
        case templateIcon
    }

    let style: Style
    let toolTip: String
}

enum MenuBarSpaceEstimator {
    /// Approximates how much horizontal space is free for status items on the given screen.
    static func availableWidth(for screen: NSScreen) -> CGFloat {
        let frame = screen.frame
        let leadingReserve = min(frame.width * 0.35, max(350, frame.width * 0.25))
        let trailingReserve: CGFloat = screen.safeAreaInsets.left > 0 ? 240 : 200
        return max(0, frame.width - leadingReserve - trailingReserve)
    }
}

enum MenuBarCollapseResolver {
    /// Picks the most detailed collapse level that fits in `availableWidth`.
    static func bestLevel(
        availableWidth: CGFloat,
        measure: (MenuBarCollapseLevel) -> CGFloat
    ) -> MenuBarCollapseLevel {
        if measure(.full) <= availableWidth { return .full }
        if measure(.timeOnly) <= availableWidth { return .timeOnly }
        return .iconOnly
    }
}

enum MenuBarLayoutMetrics {
    private static let statusFont = NSFont.menuBarFont(ofSize: 0)
    private static let pillFont = NSFont.systemFont(ofSize: 12, weight: .semibold)

    static func textWidth(_ text: String, urgent: Bool) -> CGFloat {
        let font = urgent ? pillFont : statusFont
        let size = (text as NSString).size(withAttributes: [.font: font])
        return ceil(size.width)
    }

    static func plainTextWidth(fullLabel: String, timePhrase: String, level: MenuBarCollapseLevel) -> CGFloat {
        switch level {
        case .full:
            return textWidth(fullLabel, urgent: false) + leadingIconExtraWidth
        case .timeOnly:
            return textWidth(timePhrase, urgent: false) + leadingIconExtraWidth
        case .iconOnly:
            return templateIconWidth
        }
    }

    static func pillWidth(fullLabel: String, timePhrase: String, level: MenuBarCollapseLevel) -> CGFloat {
        switch level {
        case .full:
            return textWidth(fullLabel, urgent: true) + pillHorizontalPadding
        case .timeOnly:
            return textWidth(timePhrase, urgent: true) + pillHorizontalPadding
        case .iconOnly:
            return pillIconWidth
        }
    }

    static let templateIconWidth: CGFloat = 18
    static let leadingIconExtraWidth: CGFloat = templateIconWidth + 4
    static let pillHorizontalPadding: CGFloat = 16
    static let pillIconWidth: CGFloat = 24
}
