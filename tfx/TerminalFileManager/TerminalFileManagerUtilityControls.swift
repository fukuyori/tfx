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
            .keyboardShortcut(Shortcuts.reload)
            .quickHelp("Reload", shortcut: Shortcuts.reload, text: $hoverHelpText)

            Button {
                model.openTerminal()
            } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(Shortcuts.openTerminal)
            .quickHelp("Open Terminal here", shortcut: Shortcuts.openTerminal, text: $hoverHelpText)

            Toggle(isOn: $isPreviewVisible) {
                Image(systemName: "sidebar.right")
            }
            .toggleStyle(.button)
            .quickHelp(
                isPreviewVisible ? LocalizedStringResource("Hide preview") : LocalizedStringResource("Show preview"),
                shortcut: Shortcuts.togglePreview,
                text: $hoverHelpText
            )

            Toggle(isOn: $isSplitViewVisible) {
                Image(systemName: "rectangle.split.2x1")
            }
            .toggleStyle(.button)
            .quickHelp(
                isSplitViewVisible ? LocalizedStringResource("Use single pane") : LocalizedStringResource("Use split panes"),
                shortcut: Shortcuts.toggleSplit,
                text: $hoverHelpText
            )

            Button {
                swapPanes()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.borderless)
            .disabled(!isSplitViewVisible)
            .quickHelp("Swap left and right panes", shortcut: Shortcuts.swapPanes, text: $hoverHelpText)

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
