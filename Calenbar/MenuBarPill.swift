import SwiftUI

struct MenuBarPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background {
                Capsule().fill(Color.yellow)
            }
            .fixedSize()
    }
}
