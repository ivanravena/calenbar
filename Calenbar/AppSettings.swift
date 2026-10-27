import AppKit
import Combine
import SwiftUI

enum MenuBarContentStyle: String, CaseIterable, Identifiable {
    case eventTitle
    case timeOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .eventTitle: return "Event title"
        case .timeOnly: return "Time only"
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
        static let alertColor = "alertColor"
        static let joinNowColor = "joinNowColor"
    }

    static let defaultAlertColor = StoredColor(red: 1, green: 1, blue: 0)
    static let defaultJoinNowColor = StoredColor(red: 0, green: 0.45, blue: 0.98)

    @Published var menuBarContentStyle: MenuBarContentStyle {
        didSet { UserDefaults.standard.set(menuBarContentStyle.rawValue, forKey: Keys.menuBarContentStyle) }
    }

    @Published var alertColor: StoredColor {
        didSet { persist(alertColor, forKey: Keys.alertColor) }
    }

    @Published var joinNowColor: StoredColor {
        didSet { persist(joinNowColor, forKey: Keys.joinNowColor) }
    }

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
        alertColor = Self.loadColor(forKey: Keys.alertColor) ?? Self.defaultAlertColor
        joinNowColor = Self.loadColor(forKey: Keys.joinNowColor) ?? Self.defaultJoinNowColor
    }

    private func persist(_ color: StoredColor, forKey key: String) {
        guard let data = try? JSONEncoder().encode(color) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadColor(forKey key: String) -> StoredColor? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredColor.self, from: data)
    }
}
