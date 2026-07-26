#if os(macOS)
import SwiftUI

/// App-menu entry for opening `config.toml` in a text editor. Replaces
/// the standard "Settings…" slot so the configurable shortcut (default
/// ⌘,) lands where macOS users expect app settings to live — tfx has no
/// settings window; the TOML file is the settings surface.
struct ConfigMenuCommands: Commands {
    @ObservedObject var shortcutStore: ShortcutStore

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Edit Config File…") {
                ConfigFileEditor.openConfigFile()
            }
            .keyboardShortcut(shortcutStore.info(.editConfig))
        }
    }
}
#endif
