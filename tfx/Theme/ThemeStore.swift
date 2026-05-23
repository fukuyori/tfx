#if os(macOS)
import Combine
import Foundation
import SwiftUI

/// Single source of truth for the active color theme.
///
/// Held by `tfxApp` and threaded into the SwiftUI view tree via
/// `EnvironmentKey`. Persists the selected theme id under
/// `Theme.activeThemeID` so the choice survives relaunches; missing or
/// unknown ids fall back to `Theme.default` (terminal-classic).
///
/// `@Published var activeTheme` triggers a SwiftUI refresh whenever the
/// theme changes, so every view that reads from the environment value
/// re-renders automatically.
@MainActor
final class ThemeStore: ObservableObject {
    static let userDefaultsKey = "TerminalFileManager.activeTheme"

    @Published private(set) var activeTheme: Theme

    init(userDefaults: UserDefaults = .standard) {
        let savedID = userDefaults.string(forKey: Self.userDefaultsKey)
        self.activeTheme = savedID.map(Theme.theme(forID:)) ?? .default
        self.userDefaults = userDefaults
    }

    private let userDefaults: UserDefaults

    func select(_ theme: Theme) {
        guard theme != activeTheme else { return }
        activeTheme = theme
        userDefaults.set(theme.id, forKey: Self.userDefaultsKey)
    }
}

/// Environment key surfacing the currently active theme to every
/// SwiftUI view. Reading `@Environment(\.theme)` is the canonical way
/// for a view to fetch theme tokens — keeps the dependency one-way and
/// avoids each leaf view holding its own `ThemeStore` reference.
private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Theme = .default
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}
#endif
