import SwiftUI

struct MenuBarPill: View {
    enum Content {
        case text(String)
        case icon
    }

    let content: Content

    init(text: String) {
        content = .text(text)
    }

    static var iconOnly: MenuBarPill {
        MenuBarPill(content: .icon)
    }

    private init(content: Content) {
        self.content = content
    }

    var body: some View {
        Group {
            switch content {
            case .text(let text):
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black)
            case .icon:
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background {
            Capsule().fill(Color.yellow)
        }
        .fixedSize()
    }
}
