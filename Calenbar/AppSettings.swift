import AppKit
import Combine
import SwiftUI

enum MenuBarContentStyle: String, CaseIterable, Identifiable {
    case eventTitle
    case timeOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .eventTitle: return "Full"
        case .timeOnly: return "Compact"
        }
    }
}

struct StoredColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        var value: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    init(color: Color) {
        let ns = NSColor(color)
        guard let rgb = ns.usingColorSpace(.deviceRGB) else {
            red = 0
            green = 0
            blue = 0
            alpha = 1
            return
        }
        red = Double(rgb.redComponent)
        green = Double(rgb.greenComponent)
        blue = Double(rgb.blueComponent)
        alpha = Double(rgb.alphaComponent)
    }
}

enum ColorTheme: String, CaseIterable, Identifiable {
    case calenbarDefault
    case harvest
    case studio
    case mint
    case coral
    case indigo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calenbarDefault: return "Default"
        case .harvest: return "Harvest"
        case .studio: return "Studio"
        case .mint: return "Mint"
        case .coral: return "Coral"
        case .indigo: return "Indigo"
        }
    }

    var alertColor: StoredColor {
        switch self {
        case .calenbarDefault:
            return StoredColor(hex: "#FFDB4D")
        case .harvest:
            return StoredColor(hex: "#ECB22E")
        case .studio:
            return StoredColor(hex: "#F2C94C")
        case .mint:
            return StoredColor(hex: "#ABF5D1")
        case .coral:
            return StoredColor(hex: "#FFCCBC")
        case .indigo:
            return StoredColor(hex: "#E8EAF6")
        }
    }

    var joinNowColor: StoredColor {
        switch self {
        case .calenbarDefault:
            return StoredColor(red: 0, green: 0.45, blue: 0.98)
        case .harvest:
            return StoredColor(hex: "#611F69")
        case .studio:
            return StoredColor(hex: "#5E6AD2")
        case .mint:
            return StoredColor(hex: "#007A5A")
        case .coral:
            return StoredColor(hex: "#E01E5A")
        case .indigo:
            return StoredColor(hex: "#4F46E5")
        }
    }

    static func migrated(fromPersistedRawValue raw: String) -> String {
        switch raw {
        case "slack": return ColorTheme.harvest.rawValue
        case "linear": return ColorTheme.studio.rawValue
        default: return raw
        }
    }
}

enum AppVersion {
    static var short: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var menuSectionTitle: String {
        "Version \(short)"
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let menuBarContentStyle = "menuBarContentStyle"
        static let colorTheme = "colorTheme"
        static let openAtLogin = "openAtLogin"
        static let legacyAlertColor = "alertColor"
        static let legacyJoinNowColor = "joinNowColor"
    }

    private var suppressLaunchAtLoginSync = false

    static let defaultAlertColor = ColorTheme.calenbarDefault.alertColor
    static let defaultJoinNowColor = ColorTheme.calenbarDefault.joinNowColor

    @Published var menuBarContentStyle: MenuBarContentStyle {
        didSet { UserDefaults.standard.set(menuBarContentStyle.rawValue, forKey: Keys.menuBarContentStyle) }
    }

    @Published var colorTheme: ColorTheme {
        didSet {
            UserDefaults.standard.set(colorTheme.rawValue, forKey: Keys.colorTheme)
            clearLegacyColorKeys()
        }
    }

    @Published var openAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(openAtLogin, forKey: Keys.openAtLogin)
            guard !suppressLaunchAtLoginSync else { return }
            LaunchAtLoginController.syncPreferenceToSystem(openAtLogin)
            loginItemRequiresApproval = LaunchAtLoginController.requiresApproval
        }
    }

    @Published private(set) var loginItemRequiresApproval = false

    var alertColor: StoredColor { colorTheme.alertColor }
    var joinNowColor: StoredColor { colorTheme.joinNowColor }

    var showsEventTitle: Bool {
        menuBarContentStyle == .eventTitle
    }

    private init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: Keys.menuBarContentStyle),
           let style = MenuBarContentStyle(rawValue: raw) {
            menuBarContentStyle = style
        } else {
            menuBarContentStyle = .eventTitle
        }

        if let raw = defaults.string(forKey: Keys.colorTheme) {
            let migrated = ColorTheme.migrated(fromPersistedRawValue: raw)
            if let theme = ColorTheme(rawValue: migrated) {
                colorTheme = theme
                if migrated != raw {
                    defaults.set(migrated, forKey: Keys.colorTheme)
                }
            } else {
                colorTheme = .calenbarDefault
            }
        } else {
            colorTheme = .calenbarDefault
            if defaults.data(forKey: Keys.legacyAlertColor) != nil
                || defaults.data(forKey: Keys.legacyJoinNowColor) != nil {
                defaults.removeObject(forKey: Keys.legacyAlertColor)
                defaults.removeObject(forKey: Keys.legacyJoinNowColor)
            }
            defaults.set(ColorTheme.calenbarDefault.rawValue, forKey: Keys.colorTheme)
        }

        if defaults.object(forKey: Keys.openAtLogin) != nil {
            suppressLaunchAtLoginSync = true
            openAtLogin = defaults.bool(forKey: Keys.openAtLogin)
            suppressLaunchAtLoginSync = false
        } else {
            suppressLaunchAtLoginSync = true
            openAtLogin = true
            suppressLaunchAtLoginSync = false
            defaults.set(true, forKey: Keys.openAtLogin)
        }
    }

    func updateLaunchAtLoginState(effectiveEnabled: Bool, requiresApproval: Bool) {
        loginItemRequiresApproval = requiresApproval
        guard openAtLogin != effectiveEnabled else { return }
        suppressLaunchAtLoginSync = true
        openAtLogin = effectiveEnabled
        UserDefaults.standard.set(effectiveEnabled, forKey: Keys.openAtLogin)
        suppressLaunchAtLoginSync = false
    }

    func resetColorsToDefault() {
        colorTheme = .calenbarDefault
    }

    private func clearLegacyColorKeys() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.legacyAlertColor)
        defaults.removeObject(forKey: Keys.legacyJoinNowColor)
    }
}
