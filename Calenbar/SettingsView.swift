import SwiftUI

private enum SettingsChrome {
    static let sidebarWidth: CGFloat = 180
    static let windowMinWidth: CGFloat = 900
    static let windowMinHeight: CGFloat = 560
}

private enum SettingsSidebarGroup: String, CaseIterable {
    case settings = "Settings"
    case calenbar = "Calenbar"

    var sections: [SettingsSection] {
        switch self {
        case .settings: [.customize]
        case .calenbar: [.about]
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case customize
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .customize: "Customize"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .customize: "slider.horizontal.3"
        case .about: "info.circle"
        }
    }

    var sidebarGroup: SettingsSidebarGroup {
        switch self {
        case .customize: .settings
        case .about: .calenbar
        }
    }

    var accentColor: Color {
        switch self {
        case .customize: Color(red: 0.22, green: 0.55, blue: 0.95)
        case .about: Color(white: 0.45)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var selection: SettingsSection = .customize

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selection)
                .frame(width: SettingsChrome.sidebarWidth)
                .clipped()

            Divider()

            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: SettingsChrome.windowMinWidth, minHeight: SettingsChrome.windowMinHeight)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .customize:
            CustomizeSettingsPane(settings: settings)
        case .about:
            AboutSettingsPane()
        }
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(SettingsSidebarGroup.allCases, id: \.self) { group in
                VStack(alignment: .leading, spacing: 4) {
                    SettingsSidebarGroupHeader(title: group.rawValue)

                    ForEach(group.sections) { section in
                        SettingsSidebarRow(
                            section: section,
                            isSelected: selection == section
                        ) {
                            selection = section
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
    }
}

private struct SettingsSidebarGroupHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 8)
            .padding(.bottom, 2)
    }
}

private struct SettingsSidebarRow: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SettingsSidebarIcon(section: section)
                Text(section.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.35) : Color.clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

private struct SettingsSidebarIcon: View {
    let section: SettingsSection

    var body: some View {
        Image(systemName: section.systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(section.accentColor)
            }
    }
}

private struct SettingsPaneHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.weight(.semibold))
        }
        .padding(.bottom, SettingsPaneLayout.headerBottomPadding)
    }
}

private enum SettingsPaneLayout {
    static let contentVerticalPadding: CGFloat = 4
    static let headerBottomPadding: CGFloat = 4
}

private struct SettingsPaneContentPadding: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(.vertical, SettingsPaneLayout.contentVerticalPadding)
    }
}

private extension View {
    func settingsPaneContentPadding() -> some View {
        modifier(SettingsPaneContentPadding())
    }
}

private struct AboutSettingsPane: View {
    var body: some View {
        Form {
            Section {
                SettingsPaneHeader(title: "About", systemImage: "info.circle")
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calenbar")
                        .font(.title3.weight(.semibold))
                    Text("Version \(AppVersion.short)")
                        .foregroundStyle(.secondary)
                    Text("Calenbar shows your next meeting in the menu bar.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .settingsPaneContentPadding()
            }
        }
        .formStyle(.grouped)
    }
}

private struct CustomizeSettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                SettingsPaneHeader(title: "Customize", systemImage: "slider.horizontal.3")
            }

            Section {
                MenuBarCustomizeBlock(settings: settings)
            } header: {
                Text("Menu bar")
            }

            Section("Startup") {
                Toggle("Open at login", isOn: $settings.openAtLogin)
                if settings.loginItemRequiresApproval {
                    Text("Allow Calenbar in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            LaunchAtLoginController.refreshFromSystem(into: settings)
        }
    }
}

private enum MenuBarPreviewSamples {
    static let meeting = "Team sync"
    static let timePhrase = "in 8 min"
}

private struct SettingsCardChrome: ViewModifier {
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
    }
}

private struct MenuBarCustomizeBlock: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 16) {
                    previewColumn(title: "Standard") {
                        MenuBarStandardLabel(
                            meetingName: settings.showsEventTitle ? MenuBarPreviewSamples.meeting : "",
                            timePhrase: MenuBarPreviewSamples.timePhrase,
                            joinPhraseAsButton: false,
                            showsEventTitle: settings.showsEventTitle,
                            joinNowColor: settings.joinNowColor.color
                        )
                    }
                    previewColumn(title: "Alert") {
                        MenuBarPill(
                            meetingName: settings.showsEventTitle ? MenuBarPreviewSamples.meeting : "",
                            timePhrase: MenuBarPreviewSamples.timePhrase,
                            joinPhraseAsButton: false,
                            showsEventTitle: settings.showsEventTitle,
                            alertColor: settings.alertColor.color,
                            joinNowColor: settings.joinNowColor.color
                        )
                    }
                    previewColumn(title: "Join now") {
                        MenuBarPill(
                            meetingName: settings.showsEventTitle ? MenuBarPreviewSamples.meeting : "",
                            timePhrase: "Join now",
                            joinPhraseAsButton: true,
                            showsEventTitle: settings.showsEventTitle,
                            alertColor: settings.alertColor.color,
                            joinNowColor: settings.joinNowColor.color
                        )
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Display")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(MenuBarContentStyle.allCases) { style in
                        MenuBarDisplayOptionCard(
                            style: style,
                            isSelected: settings.menuBarContentStyle == style
                        ) {
                            settings.menuBarContentStyle = style
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Color theme")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(ColorTheme.allCases) { theme in
                        ColorThemeOptionCard(
                            theme: theme,
                            isSelected: settings.colorTheme == theme
                        ) {
                            settings.colorTheme = theme
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            HStack {
                Text("Sets alert and Join now colors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset to default") {
                    settings.resetColorsToDefault()
                }
                .buttonStyle(.link)
                .disabled(settings.colorTheme == .calenbarDefault)
            }
        }
        .settingsPaneContentPadding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func previewColumn(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MenuBarDisplayOptionCard: View {
    let style: MenuBarContentStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(style.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(width: 104, alignment: .leading)
            .modifier(SettingsCardChrome(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

private struct ColorThemeSwatches: View {
    let theme: ColorTheme

    var body: some View {
        HStack(spacing: 4) {
            Capsule()
                .fill(theme.alertColor.color)
                .frame(width: 28, height: 10)
            Capsule()
                .fill(theme.joinNowColor.color)
                .frame(width: 28, height: 10)
        }
    }
}

private struct ColorThemeOptionCard: View {
    let theme: ColorTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(theme.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                ColorThemeSwatches(theme: theme)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(width: 96, alignment: .leading)
            .modifier(SettingsCardChrome(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}
