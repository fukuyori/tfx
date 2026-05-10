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
            .keyboardShortcut("[", modifiers: .command)
            .quickHelp("Back", text: $hoverHelpText)

            Button {
                model.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(!model.canGoForward)
            .keyboardShortcut("]", modifiers: .command)
            .quickHelp("Forward", text: $hoverHelpText)

            Button {
                model.goUp()
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.upArrow, modifiers: .command)
            .quickHelp("Parent folder", text: $hoverHelpText)

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
