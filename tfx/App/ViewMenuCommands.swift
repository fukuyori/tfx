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
    @AppStorage("TerminalFileManager.isSplitViewVisible") private var isSplitViewVisible = false
    @AppStorage("TerminalFileManager.isTerminalPaneVisible") private var isTerminalPaneVisible = false
    @ObservedObject var shortcutStore: ShortcutStore

    var body: some Commands {
        CommandMenu("View") {
            Toggle("Show Preview Pane", isOn: $isPreviewVisible)
                .keyboardShortcut(shortcutStore.info(.togglePreview))

            Toggle("Split View", isOn: $isSplitViewVisible)
                .keyboardShortcut(shortcutStore.info(.toggleSplit))

            Toggle("Built-in Terminal Pane", isOn: $isTerminalPaneVisible)
                .keyboardShortcut(shortcutStore.info(.toggleTerminalPane))

            Button("Focus Built-in Terminal") {
                NotificationCenter.default.post(name: .terminalFileManagerFocusTerminalPane, object: nil)
            }
            .keyboardShortcut(shortcutStore.info(.focusTerminalPane))

            Divider()

            Button("Swap Left and Right Panes") {
                NotificationCenter.default.post(name: .terminalFileManagerSwapPanes, object: nil)
            }
            .keyboardShortcut(shortcutStore.info(.swapPanes))
            .disabled(!isSplitViewVisible)

            Divider()

            Button("New Tab") {
                NotificationCenter.default.post(name: .terminalFileManagerNewTab, object: nil)
            }
            .keyboardShortcut(shortcutStore.info(.newTab))

            Button("Close Tab") {
                NotificationCenter.default.post(name: .terminalFileManagerCloseTab, object: nil)
            }
            .keyboardShortcut(shortcutStore.info(.closeTab))

            Button("Previous Tab") {
                NotificationCenter.default.post(name: .terminalFileManagerPreviousTab, object: nil)
            }
            .keyboardShortcut(shortcutStore.info(.previousTab))

            Button("Next Tab") {
                NotificationCenter.default.post(name: .terminalFileManagerNextTab, object: nil)
            }
            .keyboardShortcut(shortcutStore.info(.nextTab))
        }
    }
}

#endif
