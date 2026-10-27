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

            Section("Colors") {
                ColorPicker(
                    "Alert state",
                    selection: binding(for: \.alertColor),
                    supportsOpacity: false
                )
                ColorPicker(
                    "Join now button",
                    selection: binding(for: \.joinNowColor),
                    supportsOpacity: false
                )
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
                    Text("Join now")
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

    private func binding(for keyPath: ReferenceWritableKeyPath<AppSettings, StoredColor>) -> Binding<Color> {
        Binding(
            get: { settings[keyPath: keyPath].color },
            set: { settings[keyPath: keyPath] = StoredColor(color: $0) }
        )
    }
}
