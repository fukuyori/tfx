#if os(macOS)
import Combine
import Foundation
import SwiftUI

/// Single source of truth for the active design tokens.
@MainActor
final class DesignStore: ObservableObject {
    @Published private(set) var activeDesign = DesignTokens.default
    @Published private(set) var configurationError: String?

    var activeTheme: Theme {
        activeDesign.theme
    }

    init() {
        reload()
    }

    func reload() {
        do {
            let configuration = try DesignConfigurationLoader.load()
            activeDesign = DesignTokens(
                theme: configuration.theme,
                fonts: configuration.fonts,
                opacity: configuration.opacity
            )
            configurationError = nil
        } catch {
            configurationError = error.localizedDescription
            activeDesign = .default
        }
    }

    func dismissConfigurationError() {
        configurationError = nil
    }
}

/// Environment key surfacing the currently active theme to every
/// SwiftUI view. Reading `@Environment(\.theme)` is the canonical way
/// for a view to fetch theme tokens — keeps the dependency one-way and
/// avoids each leaf view holding its own store reference.
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
