#if os(macOS)
import SwiftUI

extension TerminalFileManagerView {
    var utilityControls: some View {
        Group {
            Button {
                model.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(shortcutStore.info(.reload))
            .quickHelp("Reload", shortcut: shortcutStore.info(.reload), text: $hoverHelpText)

            Button {
                model.openTerminal()
            } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(shortcutStore.info(.openTerminal))
            .quickHelp("Open Terminal here", shortcut: shortcutStore.info(.openTerminal), text: $hoverHelpText)

            Toggle(isOn: $isTerminalPaneVisible) {
                Image(systemName: "terminal.fill")
            }
            .toggleStyle(.button)
            .quickHelp(
                isTerminalPaneVisible ? LocalizedStringResource("Hide built-in terminal") : LocalizedStringResource("Show built-in terminal"),
                shortcut: shortcutStore.info(.toggleTerminalPane),
                text: $hoverHelpText
            )

            Toggle(isOn: visibilityBinding(.folderTree)) {
                Image(systemName: "sidebar.left")
            }
            .toggleStyle(.button)
            .quickHelp(
                isVisible(.folderTree) ? LocalizedStringResource("Hide folder tree") : LocalizedStringResource("Show folder tree"),
                shortcut: shortcutStore.info(.toggleFolderTree),
                text: $hoverHelpText
            )

            Toggle(isOn: $isSplitViewVisible) {
                Image(systemName: "rectangle.split.2x1")
            }
            .toggleStyle(.button)
            .quickHelp(
                isSplitViewVisible ? LocalizedStringResource("Use single pane") : LocalizedStringResource("Use split panes"),
                shortcut: shortcutStore.info(.toggleSplit),
                text: $hoverHelpText
            )

            Toggle(isOn: visibilityBinding(.preview)) {
                Image(systemName: "sidebar.right")
            }
            .toggleStyle(.button)
            .quickHelp(
                isVisible(.preview) ? LocalizedStringResource("Hide preview") : LocalizedStringResource("Show preview"),
                shortcut: shortcutStore.info(.togglePreview),
                text: $hoverHelpText
            )

            Button {
                swapPanes()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.borderless)
            .disabled(!isSplitViewVisible)
            .quickHelp("Swap left and right panes", shortcut: shortcutStore.info(.swapPanes), text: $hoverHelpText)

            Button {
                isFileListSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .quickHelp("File list settings", text: $hoverHelpText)
        }
    }
}
#endif
