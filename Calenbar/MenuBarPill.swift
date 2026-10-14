import SwiftUI

struct MenuBarPill: View {
    let text: String

    private enum Metrics {
        static let iconTextSpacing: CGFloat = 6
    }

    var body: some View {
        HStack(spacing: Metrics.iconTextSpacing) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background {
            Capsule().fill(Color.yellow)
        }
        .fixedSize()
    }
}
