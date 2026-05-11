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
            .keyboardShortcut("r", modifiers: .command)
            .quickHelp("Reload", text: $hoverHelpText)

            Button {
                model.openTerminal()
            } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .quickHelp("Open Terminal here", text: $hoverHelpText)

            Toggle(isOn: $isPreviewVisible) {
                Image(systemName: "sidebar.right")
            }
            .toggleStyle(.button)
            .keyboardShortcut("p", modifiers: [.command, .option])
            .quickHelp(isPreviewVisible ? LocalizedStringResource("Hide preview") : LocalizedStringResource("Show preview"), text: $hoverHelpText)

            Toggle(isOn: Binding(
                get: { isSplitViewVisible },
                set: { setSplitViewVisible($0) }
            )) {
                Image(systemName: "rectangle.split.2x1")
            }
            .toggleStyle(.button)
            .keyboardShortcut("s", modifiers: [.command, .option])
            .quickHelp(isSplitViewVisible ? LocalizedStringResource("Use single pane") : LocalizedStringResource("Use split panes"), text: $hoverHelpText)

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
