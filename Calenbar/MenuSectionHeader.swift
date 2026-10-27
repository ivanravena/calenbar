import AppKit

enum MenuSectionHeader {
    private enum Metrics {
        static let rowHeight: CGFloat = 22
        /// Align with standard `NSMenu` text inset.
        static let leadingInset: CGFloat = 18
    }

    /// Custom view so AppKit does not gray out disabled `attributedTitle` (which ignores our color).
    static func menuItem(title: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.title = title
        item.isEnabled = false

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        label.textColor = NSColor.labelColor.withAlphaComponent(0.62)
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: Metrics.rowHeight))
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Metrics.leadingInset),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        item.view = container
        return item
    }
}
