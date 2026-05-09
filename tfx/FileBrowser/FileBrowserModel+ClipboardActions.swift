#if os(macOS)
import Foundation

extension FileBrowserModel {
    func copySelectedItems() {
        clipboard = FileBrowserClipboardActions.clipboard(for: selectedItems, operation: .copy)
    }

    func cutSelectedItems() {
        guard !selectedItems.contains(where: { ZipArchiveBrowser.canCopyFromArchive($0.url) }) else {
            clipboard = FileBrowserClipboardActions.clipboard(for: selectedItems, operation: .copy)
            return
        }
        clipboard = FileBrowserClipboardActions.clipboard(for: selectedItems, operation: .move)
    }

    func pasteItems() {
        pasteItems(into: currentDirectory)
    }

    func pasteItemsMoving() {
        pasteItems(into: currentDirectory, forcedOperation: .move)
    }

    func pasteItems(into targetDirectory: URL) {
        pasteItems(into: targetDirectory, forcedOperation: nil)
    }

    private func pasteItems(into targetDirectory: URL, forcedOperation: FileClipboard.Operation?) {
        guard var clipboard = clipboard ?? FileBrowserExternalActions.fileClipboardFromPasteboard(defaultOperation: forcedOperation ?? .copy),
              !clipboard.urls.isEmpty else { return }
        if let forcedOperation {
            clipboard = FileClipboard(urls: clipboard.urls, operation: forcedOperation)
        }

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
