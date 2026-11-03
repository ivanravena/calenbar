import SwiftUI

enum MenuBarLabelTypography {
    static let joinButtonFont = Font.system(size: 12, weight: .semibold)
}

struct MenuBarJoinNowCapsule: View {
    let text: String
    let font: Font
    var fillColor: Color = AppSettings.defaultJoinNowColor.color

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background {
                Capsule().fill(fillColor)
            }
    }
}

struct MenuBarMixedTitle: View {
    let meetingName: String
    let timePhrase: String
    let nameFont: Font
    let timeFont: Font
    var joinPhraseAsButton: Bool = false
    var showsEventTitle: Bool = true
    var joinNowColor: Color = AppSettings.defaultJoinNowColor.color

    var body: some View {
        if timePhrase.isEmpty {
            if showsEventTitle {
                Text(meetingName)
                    .font(nameFont)
            }
        } else if joinPhraseAsButton {
            HStack(spacing: 5) {
                if showsEventTitle {
                    Text(meetingName)
                        .font(nameFont)
                }
                MenuBarJoinNowCapsule(text: timePhrase, font: timeFont, fillColor: joinNowColor)
            }
        } else if showsEventTitle {
            Text(meetingName).font(nameFont)
                + Text(" \(timePhrase)").font(timeFont)
        } else {
            Text(timePhrase)
                .font(timeFont)
        }
    }
}

/// Default menu bar row: template-style calendar glyph plus mixed-weight title.
struct MenuBarStandardLabel: View {
    let meetingName: String
    let timePhrase: String
    var joinPhraseAsButton: Bool = false
    var showsEventTitle: Bool = true
    var joinNowColor: Color = AppSettings.defaultJoinNowColor.color

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
            MenuBarMixedTitle(
                meetingName: meetingName,
                timePhrase: timePhrase,
                nameFont: Typography.name,
                timeFont: Typography.time,
                joinPhraseAsButton: joinPhraseAsButton,
                showsEventTitle: showsEventTitle,
                joinNowColor: joinNowColor
            )
        }
        .foregroundStyle(Color(nsColor: .labelColor))
        .fixedSize()
    }
}

struct MenuBarPill: View {
    let meetingName: String
    let timePhrase: String
    var joinPhraseAsButton: Bool = false
    var showsEventTitle: Bool = true
    var alertColor: Color = AppSettings.defaultAlertColor.color
    var joinNowColor: Color = AppSettings.defaultJoinNowColor.color

    private enum Metrics {
        static let iconTextSpacing: CGFloat = 6
    }

    private enum Typography {
        static let icon = Font.system(size: 11, weight: .semibold)
        static let name = Font.system(size: 12, weight: .regular)
        static let time = MenuBarLabelTypography.joinButtonFont
    }

    var body: some View {
        HStack(spacing: joinPhraseAsButton ? 5 : 0) {
            HStack(spacing: Metrics.iconTextSpacing) {
                Image(systemName: "calendar")
                    .font(Typography.icon)
                if joinPhraseAsButton {
                    if showsEventTitle {
                        Text(meetingName)
                            .font(Typography.name)
                    }
                } else {
                    MenuBarMixedTitle(
                        meetingName: meetingName,
                        timePhrase: timePhrase,
                        nameFont: Typography.name,
                        timeFont: Typography.time,
                        joinPhraseAsButton: false,
                        showsEventTitle: showsEventTitle,
                        joinNowColor: joinNowColor
                    )
                }
            }
            .foregroundStyle(Color.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background {
                Capsule().fill(alertColor)
            }

            if joinPhraseAsButton {
                MenuBarJoinNowCapsule(text: timePhrase, font: Typography.time, fillColor: joinNowColor)
            }
        }
        .fixedSize()
    }
}
