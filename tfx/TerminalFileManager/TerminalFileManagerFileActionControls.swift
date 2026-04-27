#if os(macOS)
import SwiftUI

extension TerminalFileManagerView {
    var fileActionControls: some View {
        Group {
            Button {
                model.createFolder()
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("n", modifiers: .command)
            .quickHelp("New folder", text: $hoverHelpText)

            Button {
                model.renameSelectedItem()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .disabled(model.selectionCount != 1)
            .keyboardShortcut(.return, modifiers: [])
            .quickHelp("Rename", text: $hoverHelpText)

            Button {
                model.moveSelectedItemsToTrash()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(!model.hasSelection)
            .keyboardShortcut(.delete, modifiers: [])
            .quickHelp("Move to Trash", text: $hoverHelpText)

            Button {
                model.copySelectedItems()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .disabled(!model.hasSelection)
            .keyboardShortcut("c", modifiers: .command)
            .quickHelp("Copy selected items", text: $hoverHelpText)

            Button {
                model.cutSelectedItems()
            } label: {
                Image(systemName: "scissors")
            }
            .buttonStyle(.borderless)
            .disabled(!model.hasSelection)
            .keyboardShortcut("x", modifiers: .command)
            .quickHelp("Cut selected items", text: $hoverHelpText)

            Button {
                model.pasteItems()
            } label: {
                Image(systemName: "clipboard")
            }
            .buttonStyle(.borderless)
            .disabled(!model.canPaste)
            .keyboardShortcut("v", modifiers: .command)
            .quickHelp("Paste into current folder", text: $hoverHelpText)
        }
    }
}
#endif
