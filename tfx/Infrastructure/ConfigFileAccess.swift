#if os(macOS)
import AppKit
import Combine
import Foundation

/// Opens `config.toml` in the user's editor. Resolution order: the app
/// chosen in Editor Settings (when it still exists on disk), then the
/// system's default handler for the file, then TextEdit so the action
/// always produces an editable window (a bare `.toml` file frequently
/// has no default app on a fresh macOS install).
enum ConfigFileEditor {
    /// UserDefaults key holding the chosen editor's bundle path.
    /// Empty / absent = follow the OS file association.
    static let editorDefaultsKey = "TerminalFileManager.configEditorPath"

    /// The editor picked in Editor Settings, or nil when unset or the
    /// app has since been deleted (deleted apps silently fall back to
    /// the OS association instead of failing the menu action).
    static var configuredEditorURL: URL? {
        let path = UserDefaults.standard.string(forKey: editorDefaultsKey) ?? ""
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func openConfigFile() {
        guard let configURL = try? DesignConfigurationLoader.ensureConfigFile() else { return }

        NSWorkspace.shared.open(
            [configURL],
            withApplicationAt: configuredEditorURL ?? defaultEditorURL(for: configURL),
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            guard error != nil else { return }
            // The resolved handler failed to launch — last resort:
            // let LaunchServices pick anything that claims the file.
            DispatchQueue.main.async {
                NSWorkspace.shared.open(configURL)
            }
        }
    }

    /// Name shown for the "System Default" row in Editor Settings.
    static func systemDefaultEditorName() -> String {
        guard let configURL = try? DesignConfigurationLoader.ensureConfigFile() else {
            return String(localized: "System Default")
        }
        let appURL = defaultEditorURL(for: configURL)
        return String(localized: "System Default (\(FileBrowserExternalActions.applicationDisplayName(appURL)))")
    }

    /// Editor candidates offered in Editor Settings: every app that
    /// claims the config file, always including TextEdit, and the
    /// currently configured app even when LaunchServices doesn't list
    /// it (e.g. an editor picked via the Other… panel).
    static func editorCandidates() -> [URL] {
        var candidates: [URL] = []
        if let configURL = try? DesignConfigurationLoader.ensureConfigFile() {
            candidates = FileBrowserExternalActions.applicationsToOpen(configURL)
        }

        let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app", isDirectory: true)
        if FileManager.default.fileExists(atPath: textEdit.path),
           !candidates.contains(where: { $0.standardizedFileURL == textEdit.standardizedFileURL }) {
            candidates.append(textEdit)
        }

        if let configured = configuredEditorURL,
           !candidates.contains(where: { $0.standardizedFileURL == configured.standardizedFileURL }) {
            candidates.insert(configured, at: 0)
        }

        return candidates
    }

    private static func defaultEditorURL(for fileURL: URL) -> URL {
        if let appURL = NSWorkspace.shared.urlForApplication(toOpen: fileURL) {
            return appURL
        }
        return URL(fileURLWithPath: "/System/Applications/TextEdit.app", isDirectory: true)
    }
}

/// Watches the config directory and fires a callback (debounced) whenever
/// `config.toml` changes on disk, so edits apply without switching away
/// from and back to the app.
///
/// The watcher observes the *directory* rather than the file's vnode:
/// editors that save atomically (write-to-temp + rename) replace the file,
/// which silently detaches a file-descriptor watch, while the directory
/// keeps reporting every save. `DirectoryWatcher` already debounces and
/// delivers on the main queue, and its `deinit`/`stop` cancels the
/// dispatch source before closing the descriptor, so a change event that
/// races app shutdown cannot fire into a torn-down store graph.
final class ConfigFileWatcher: ObservableObject {
    private var watcher: DirectoryWatcher?
    private var lastModificationDate: Date?

    func start(onChange: @escaping () -> Void) {
        guard watcher == nil else { return }
        guard let configURL = try? DesignConfigurationLoader.ensureConfigFile() else { return }

        lastModificationDate = Self.modificationDate(of: configURL)
        let directoryWatcher = DirectoryWatcher(
            url: configURL.deletingLastPathComponent(),
            debounce: .milliseconds(400)
        ) { [weak self] in
            guard let self else { return }
            // The directory watch fires for any entry in
            // Application Support/tfx — gate on config.toml's
            // modification date so unrelated files there don't
            // trigger spurious full config reloads.
            let current = Self.modificationDate(of: configURL)
            guard current != self.lastModificationDate else { return }
            self.lastModificationDate = current
            onChange()
        }
        directoryWatcher.start()
        watcher = directoryWatcher
    }

    func stop() {
        watcher?.stop()
        watcher = nil
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
#endif
