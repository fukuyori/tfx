#if os(macOS)
import SwiftUI

extension TerminalFileManagerView {
    var navigationControls: some View {
        Group {
            Button {
                model.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(!model.canGoBack)
            .keyboardShortcut(shortcutStore.info(.goBack))
            .quickHelp("Back", shortcut: shortcutStore.info(.goBack), text: $hoverHelpText)

            Button {
                model.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(!model.canGoForward)
            .keyboardShortcut(shortcutStore.info(.goForward))
            .quickHelp("Forward", shortcut: shortcutStore.info(.goForward), text: $hoverHelpText)

            Button {
                model.goUp()
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(shortcutStore.info(.goUp))
            .quickHelp("Parent folder", shortcut: shortcutStore.info(.goUp), text: $hoverHelpText)
        }
    }
}
#endif
