import SwiftUI

struct MenuBarPill: View {
    let meetingName: String
    let timePhrase: String

    private enum Metrics {
        static let iconTextSpacing: CGFloat = 6
    }

    private enum Typography {
        static let icon = Font.system(size: 11, weight: .semibold)
        static let name = Font.system(size: 12, weight: .regular)
        static let time = Font.system(size: 12, weight: .semibold)
    }

    var body: some View {
        HStack(spacing: Metrics.iconTextSpacing) {
            Image(systemName: "calendar")
                .font(Typography.icon)
            menuBarLabel
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background {
            Capsule().fill(Color.yellow)
        }
        .fixedSize()
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        if timePhrase.isEmpty {
            Text(meetingName)
                .font(Typography.name)
        } else {
            Text(meetingName).font(Typography.name)
                + Text(" \(timePhrase)").font(Typography.time)
        }
    }
}
