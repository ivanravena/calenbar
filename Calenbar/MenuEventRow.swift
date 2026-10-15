import AppKit

/// Fixed-width columns for event rows in the status item menu (native `NSMenuItem` text).
enum MenuEventRow {
    private enum Metrics {
        static let columnSpacing: CGFloat = 8
        static let columnPadding: CGFloat = 4
    }

    /// Shared column widths for all rows on a given day (semibold monospaced-digit metrics).
    static func columnWidths(
        timeStrings: [String],
        durationStrings: [String]
    ) -> (time: CGFloat, duration: CGFloat) {
        let pointSize = NSFont.systemFontSize
        let digitFont = NSFont.monospacedDigitSystemFont(ofSize: pointSize, weight: .semibold)

        func maxWidth(for strings: [String]) -> CGFloat {
            strings
                .map { ($0 as NSString).size(withAttributes: [.font: digitFont]).width }
                .max() ?? 0
        }

        let padding = Metrics.columnPadding
        return (
            maxWidth(for: timeStrings) + padding,
            maxWidth(for: durationStrings) + padding
        )
    }

    static func attributedTitle(
        timeText: String,
        durationText: String,
        titleText: String,
        isPast: Bool,
        timeColumnWidth: CGFloat,
        durationColumnWidth: CGFloat
    ) -> NSAttributedString {
        let pointSize = NSFont.systemFontSize
        let weight: NSFont.Weight = isPast ? .regular : .semibold
        let textFont = NSFont.systemFont(ofSize: pointSize, weight: weight)
        let digitFont = NSFont.monospacedDigitSystemFont(ofSize: pointSize, weight: weight)
        let color = isPast ? NSColor.secondaryLabelColor : NSColor.labelColor

        // `NSMenuItem` ignores tab stops; align with measured space padding instead.
        let timeColumn = rightAlignedColumn(timeText, targetWidth: timeColumnWidth, font: digitFont)
        let gap = spaces(forWidth: Metrics.columnSpacing, font: digitFont)
        let durationColumn = leftAlignedColumn(
            durationText,
            targetWidth: durationColumnWidth,
            font: digitFont
        )
        let plain = timeColumn + gap + durationColumn + gap + titleText

        let attributed = NSMutableAttributedString(
            string: plain,
            attributes: [
                .foregroundColor: color,
                .font: digitFont,
            ]
        )

        let timeRange = NSRange(location: 0, length: (timeColumn as NSString).length)
        let durationStart = timeRange.upperBound + (gap as NSString).length
        let durationRange = NSRange(location: durationStart, length: (durationColumn as NSString).length)
        let titleStart = durationRange.upperBound + (gap as NSString).length
        let titleRange = NSRange(location: titleStart, length: (titleText as NSString).length)

        attributed.addAttribute(.font, value: textFont, range: titleRange)

        return attributed
    }

    private static func textWidth(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    private static func spaces(forWidth width: CGFloat, font: NSFont) -> String {
        guard width > 0 else { return "" }
        let unit = " "
        let unitWidth = textWidth(unit, font: font)
        guard unitWidth > 0 else { return " " }
        let count = max(1, Int(round(width / unitWidth)))
        return String(repeating: unit, count: count)
    }

    private static func rightAlignedColumn(_ text: String, targetWidth: CGFloat, font: NSFont) -> String {
        var column = text
        while textWidth(column, font: font) < targetWidth {
            column = " " + column
        }
        return column
    }

    private static func leftAlignedColumn(_ text: String, targetWidth: CGFloat, font: NSFont) -> String {
        var column = text
        while textWidth(column, font: font) < targetWidth {
            column += " "
        }
        return column
    }
}
