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

            Button {
                model.pickFolder()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .quickHelp("Open folder", text: $hoverHelpText)

            Button {
                model.togglePinnedFolder(model.currentDirectory)
            } label: {
                Image(systemName: model.isFolderPinned(model.currentDirectory) ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .quickHelp(model.isFolderPinned(model.currentDirectory) ? LocalizedStringResource("Unpin current folder") : LocalizedStringResource("Pin current folder"), text: $hoverHelpText)
        }
    }
}
#endif
