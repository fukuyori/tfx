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
    @ObservedObject var shortcutStore: ShortcutStore

    var body: some Commands {
        CommandMenu("View") {
            Toggle("Show Preview Pane", isOn: $isPreviewVisible)
                .keyboardShortcut(shortcutStore.info(.togglePreview))

            Toggle("Split View", isOn: $isSplitViewVisible)
                .keyboardShortcut(shortcutStore.info(.toggleSplit))

            Divider()

            Button("Swap Left and Right Panes") {
                NotificationCenter.default.post(name: .terminalFileManagerSwapPanes, object: nil)
            }
            .keyboardShortcut(shortcutStore.info(.swapPanes))
            .disabled(!isSplitViewVisible)
        }
    }
}

#endif
