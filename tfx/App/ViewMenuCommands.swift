#if os(macOS)
import SwiftUI

/// `View` menu commands for layout-related toggles and the split swap.
///
/// Toggles bind directly to `@AppStorage`, so the menu and the toolbar
/// controls in `TerminalFileManagerUtilityControls` stay in sync without
/// extra plumbing. The swap action posts a notification observed by
/// `TerminalFileManagerView`, because it needs access to the per-pane
/// `FileBrowserModel` instances that live on the view, not in defaults.
struct ViewMenuCommands: Commands {
    @AppStorage("TerminalFileManager.isPreviewVisible") private var isPreviewVisible = true
    @AppStorage("TerminalFileManager.isSplitViewVisible") private var isSplitViewVisible = true
    @ObservedObject var themeStore: ThemeStore

    var body: some Commands {
        CommandMenu("View") {
            Toggle("Show Preview Pane", isOn: $isPreviewVisible)
                .keyboardShortcut(Shortcuts.togglePreview)

            Toggle("Split View", isOn: $isSplitViewVisible)
                .keyboardShortcut(Shortcuts.toggleSplit)

            Divider()

            Button("Swap Left and Right Panes") {
                NotificationCenter.default.post(name: .terminalFileManagerSwapPanes, object: nil)
            }
            .keyboardShortcut(Shortcuts.swapPanes)
            .disabled(!isSplitViewVisible)

            Divider()

            // Theme submenu — built-in themes only. Selecting one
            // persists to UserDefaults via `ThemeStore.select`, and the
            // checkmark on the active row keeps the menu in sync with
            // the current store state.
            Menu("Theme") {
                ForEach(Theme.allThemes) { theme in
                    Button {
                        themeStore.select(theme)
                    } label: {
                        if theme == themeStore.activeTheme {
                            Label(theme.displayName, systemImage: "checkmark")
                        } else {
                            Text(theme.displayName)
                        }
                    }
                }
            }
        }
    }
}

#endif
