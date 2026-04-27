#if os(macOS)
import AppKit

extension TerminalFileManagerView {
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        let unsupportedModifiers = event.modifierFlags.intersection([.command, .option, .control])
        guard unsupportedModifiers.isEmpty else { return false }
        let isRangeSelection = event.modifierFlags.contains(.shift)

        switch event.keyCode {
        case 126:
            activeArea == .folderTree ? activeModel.moveFolderTreeSelection(delta: -1) : activeModel.moveFileSelection(delta: -1, extendingRange: isRangeSelection)
            return true
        case 125:
            activeArea == .folderTree ? activeModel.moveFolderTreeSelection(delta: 1) : activeModel.moveFileSelection(delta: 1, extendingRange: isRangeSelection)
            return true
        case 123:
            moveKeyboardFocusLeft()
            return true
        case 124:
            moveKeyboardFocusRight()
            return true
        case 36, 76:
            activeArea == .folderTree ? activeModel.activateFolderTreeSelection() : activeModel.activateFileSelection()
            return true
        default:
            return false
        }
    }

    private func moveKeyboardFocusLeft() {
        guard activeArea == .files else { return }

        if isSplitViewVisible, activePane == .right {
            activePane = .left
        } else {
            activeArea = .folderTree
            activeModel.ensureFolderTreeSelection()
        }
    }

    private func moveKeyboardFocusRight() {
        if activeArea == .folderTree {
            activeArea = .files
            activeModel.ensureFileSelection()
            return
        }

        guard isSplitViewVisible, activePane == .left else { return }
        activePane = .right
        activeModel.ensureFileSelection()
    }
}
#endif
