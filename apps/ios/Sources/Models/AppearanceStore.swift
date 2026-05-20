import Foundation
import Observation
import SwiftUI

/// User-tunable appearance settings: chat body font, theme override,
/// and turn-collapse preference. Persisted to `UserDefaults.standard`
/// so the choice survives relaunch.
///
/// Lives at app root, injected as an `@Environment` value into any
/// view that needs to honour it (currently `ConversationView` for the
/// monospaced body font, `SettingsSheet`/`AppearanceSheet` for the UI).
@Observable
final class AppearanceStore {
    enum FontFamily: String, CaseIterable, Identifiable {
        case monospaced
        case system

        var id: String { rawValue }
        var label: String {
            switch self {
            case .monospaced: return "Monospaced"
            case .system:     return "System"
            }
        }
    }

    enum ThemeMode: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "System"
            case .light:  return "Light"
            case .dark:   return "Dark"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    private enum Keys {
        static let font = "swekitty.appearance.font"
        static let theme = "swekitty.appearance.theme"
        static let collapseTurns = "swekitty.appearance.collapseTurns"
    }

    var fontFamily: FontFamily {
        didSet { defaults.set(fontFamily.rawValue, forKey: Keys.font) }
    }

    var themeMode: ThemeMode {
        didSet { defaults.set(themeMode.rawValue, forKey: Keys.theme) }
    }

    var collapseTurns: Bool {
        didSet { defaults.set(collapseTurns, forKey: Keys.collapseTurns) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.fontFamily = (defaults.string(forKey: Keys.font)
            .flatMap(FontFamily.init(rawValue:))) ?? .monospaced
        self.themeMode = (defaults.string(forKey: Keys.theme)
            .flatMap(ThemeMode.init(rawValue:))) ?? .system
        self.collapseTurns = defaults.object(forKey: Keys.collapseTurns) as? Bool ?? false
    }

    /// SwiftUI `.font` value to use for chat body text.
    func bodyFont() -> Font {
        switch fontFamily {
        case .monospaced: return .system(.body, design: .monospaced)
        case .system:     return .system(.body)
        }
    }
}
