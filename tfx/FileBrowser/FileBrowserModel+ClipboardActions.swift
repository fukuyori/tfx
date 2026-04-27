#if os(macOS)
import Foundation

extension FileBrowserModel {
    func copySelectedItems() {
        clipboard = FileBrowserClipboardActions.clipboard(for: selectedItems, operation: .copy)
    }

    func cutSelectedItems() {
        clipboard = FileBrowserClipboardActions.clipboard(for: selectedItems, operation: .move)
    }

    func pasteItems() {
        pasteItems(into: currentDirectory)
    }

    func pasteItems(into targetDirectory: URL) {
        guard let clipboard, !clipboard.urls.isEmpty else { return }

        do {
            guard let result = try FileBrowserFileOperations.paste(clipboard, into: targetDirectory) else { return }

            if result.shouldClearClipboard {
                self.clipboard = nil
            }

            refreshFolderChildren(targetDirectory)
            updateCurrentDirectoryItems(
                adding: result.pastedURLs,
                removing: result.removedURLs,
                selecting: result.pastedURLs
            )
            notifyDirectoriesChanged(Array(result.affectedDirectories))
        } catch {
            show(error)
            reload()
        }
    }
}

#endif
