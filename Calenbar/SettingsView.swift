import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            CustomizeSettingsPane(settings: settings)
                .tabItem {
                    Label("Customize", systemImage: "slider.horizontal.3")
                }
            AboutSettingsPane()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 680, minHeight: 460)
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
        .padding(.bottom, 4)
    }
}

private struct AboutSettingsPane: View {
    var body: some View {
        Form {
            Section {
                SettingsPaneHeader(title: "About", systemImage: "info.circle")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calenbar")
                        .font(.title3.weight(.semibold))
                    Text("Version \(AppVersion.short)")
                        .foregroundStyle(.secondary)
                    Text("Calenbar shows your next meeting in the menu bar.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
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

            Section("Menu bar content") {
                Picker("Display", selection: $settings.menuBarContentStyle) {
                    ForEach(MenuBarContentStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Text("Sets alert and Join now colors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(ColorTheme.allCases) { theme in
                        ColorThemePresetCard(
                            theme: theme,
                            isSelected: settings.colorTheme == theme
                        ) {
                            settings.colorTheme = theme
                        }
                    }
                }
                .padding(.vertical, 4)

                Button("Reset to default") {
                    settings.resetColorsToDefault()
                }
                .buttonStyle(.link)
                .disabled(settings.colorTheme == .calenbarDefault)
            } header: {
                Text("Color theme")
            }

            Section("Preview") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Standard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    MenuBarStandardLabel(
                        meetingName: settings.showsEventTitle ? "Team sync" : "",
                        timePhrase: "in 8 min",
                        joinPhraseAsButton: false,
                        showsEventTitle: settings.showsEventTitle,
                        joinNowColor: settings.joinNowColor.color
                    )
                    Text("Alert")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    MenuBarPill(
                        meetingName: settings.showsEventTitle ? "Team sync" : "",
                        timePhrase: "in 8 min",
                        joinPhraseAsButton: false,
                        showsEventTitle: settings.showsEventTitle,
                        alertColor: settings.alertColor.color,
                        joinNowColor: settings.joinNowColor.color
                    )
                    Text("Sample — Join now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    MenuBarPill(
                        meetingName: settings.showsEventTitle ? "Team sync" : "",
                        timePhrase: "Join now",
                        joinPhraseAsButton: true,
                        showsEventTitle: settings.showsEventTitle,
                        alertColor: settings.alertColor.color,
                        joinNowColor: settings.joinNowColor.color
                    )
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ColorThemePresetCard: View {
    let theme: ColorTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(theme.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                HStack(spacing: 6) {
                    Capsule()
                        .fill(theme.alertColor.color)
                        .frame(width: 36, height: 14)
                    Capsule()
                        .fill(theme.joinNowColor.color)
                        .frame(width: 36, height: 14)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .buttonStyle(.plain)
    }
}
