#if os(macOS)
import Foundation

/// Resolves the localized placeholder names used by the "New
/// File", "New Folder", and clipboard-paste flows. The chosen
/// language is read from `[naming] language = ...` in
/// `config.toml`:
///
/// * `auto` — follow `String(localized:)`, i.e. whatever macOS
///   Settings → Language & Region picks. Default.
/// * `en`   — always English (`Untitled.txt`, `Untitled Folder`,
///   `clipboard`).
/// * `ja`   — always Japanese (`名称未設定.txt`, `名称未設定フォルダ`,
///   `クリップボード`).
///
/// The TOML file is parsed once per process. Reaching back to
/// `AppLaunchConfigurationLoader.load()` on every user action
/// would re-read the file from disk on every new-file / paste
/// click; the cache avoids that without preventing the user
/// from changing the value (a restart picks the new setting up).
enum DefaultPlaceholderNames {
    static func untitledFileName() -> String {
        switch resolvedLanguage() {
        case .english: return "Untitled.txt"
        case .japanese: return "名称未設定.txt"
        }
    }

    static func untitledFolderName() -> String {
        switch resolvedLanguage() {
        case .english: return "Untitled Folder"
        case .japanese: return "名称未設定フォルダ"
        }
    }

    static func clipboardBaseName() -> String {
        switch resolvedLanguage() {
        case .english: return "clipboard"
        case .japanese: return "クリップボード"
        }
    }

    /// Visible for tests. Resets the in-process cache so the
    /// next lookup re-parses `config.toml`.
    static func resetCacheForTesting() {
        cache.reset()
    }

    private enum ResolvedLanguage {
        case english
        case japanese
    }

    private static let cache = Cache()

    private static func resolvedLanguage() -> ResolvedLanguage {
        let language = cache.cachedOrLoadedLanguage()
        switch language {
        case .english: return .english
        case .japanese: return .japanese
        case .auto:
            // `Bundle.main.preferredLocalizations` is the
            // canonical "what language is the bundle resolving
            // strings into" — accounts for the system language
            // preference plus the bundle's available locales.
            // We map anything starting with `ja` to Japanese
            // and everything else to English.
            let preferred = Bundle.main.preferredLocalizations.first?.lowercased() ?? "en"
            return preferred.hasPrefix("ja") ? .japanese : .english
        }
    }

    /// Tiny thread-safe wrapper so SwiftUI views / model
    /// callbacks invoked from different threads don't race the
    /// first-time load.
    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var language: NamingLanguage?

        func cachedOrLoadedLanguage() -> NamingLanguage {
            lock.lock()
            defer { lock.unlock() }
            if let language { return language }
            let loaded = (try? AppLaunchConfigurationLoader.load())?.namingLanguage ?? .auto
            language = loaded
            return loaded
        }

        func reset() {
            lock.lock()
            language = nil
            lock.unlock()
        }
    }
}

#endif
