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

    /// Cmd+Shift+V style paste. Ignores RTF / image / CSV /
    /// URL detection and forces the plain-text representation
    /// of whatever is on the clipboard into a `.txt` file.
    /// When the clipboard holds rich text, NSPasteboard's
    /// `.string` type already exposes the rendered text-only
    /// form, so this drops formatting cleanly. Returns silently
    /// when no text is on the clipboard at all (e.g. only files
    /// or a raw image were copied).
    func pasteAsText() {
        pasteAsText(into: currentDirectory)
    }

    func pasteAsText(into directory: URL) {
        guard let source = FileBrowserClipboardContent.plainTextSource() else { return }
        pasteClipboardContent(source: source, into: directory)
    }

    func pasteItems(into targetDirectory: URL) {
        pasteItems(into: targetDirectory, forcedOperation: nil)
    }

    private func pasteItems(into targetDirectory: URL, forcedOperation: FileClipboard.Operation?) {
        if let fileClipboard = clipboard ?? FileBrowserExternalActions.fileClipboardFromPasteboard(defaultOperation: forcedOperation ?? .copy),
           !fileClipboard.urls.isEmpty {
            pasteFileClipboard(fileClipboard, into: targetDirectory, forcedOperation: forcedOperation)
            return
        }

        // No file URLs on the pasteboard — fall through to the
        // "create a file from clipboard content" path. The
        // generic detector picks the most natural shape (image,
        // CSV, URL, RTF, plain text). HTML is intentionally
        // skipped here and reserved for the Paste Special menu
        // so a Cmd+V on a Word selection lands as `.rtf` rather
        // than a wrapped HTML blob.
        guard let source = FileBrowserClipboardContent.defaultSource() else { return }
        pasteClipboardContent(source: source, into: targetDirectory)
    }

    private func pasteFileClipboard(
        _ clipboard: FileClipboard,
        into targetDirectory: URL,
        forcedOperation: FileClipboard.Operation?
    ) {
        var clipboard = clipboard
        if let forcedOperation {
            clipboard = FileClipboard(urls: clipboard.urls, operation: forcedOperation)
        }

        guard !clipboard.urls.contains(where: { ZipArchiveBrowser.canCopyFromArchive($0) }) else {
            pasteArchiveClipboard(clipboard, into: targetDirectory)
            return
        }

        do {
            guard let plan = try FileBrowserFileOperations.pasteOperationPlan(clipboard, into: targetDirectory) else { return }

            let kind: FileOperationProgressViewModel.Kind = (clipboard.operation == .copy) ? .copying : .moving
            runFileOperation(kind: kind, requests: plan.requests) { [weak self] added, removed in
                guard let self else { return }
                if plan.shouldClearClipboard {
                    self.clipboard = nil
                }
                for directory in plan.affectedDirectories {
                    self.refreshFolderChildren(directory)
                }
                self.updateCurrentDirectoryItems(
                    adding: added,
                    removing: removed,
                    selecting: added
                )
                self.notifyDirectoriesChanged(Array(plan.affectedDirectories), removedURLs: removed)
            }
        } catch {
            show(error)
            reload()
        }
    }

    private func pasteArchiveClipboard(_ clipboard: FileClipboard, into targetDirectory: URL) {
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

    /// Materialize a non-file clipboard payload (image, CSV,
    /// URL, RTF, HTML, plain text) into a new file under
    /// `directory`, surface it in the file list, and start
    /// inline rename so the user can replace the localized
    /// "clipboard" placeholder name immediately.
    func pasteClipboardContent(source: ClipboardContentSource, into directory: URL) {
        guard ZipArchiveBrowser.location(for: directory) == nil else {
            show(ZipArchiveBrowserError.unsupportedWrite)
            return
        }

        let baseName = DefaultPlaceholderNames.clipboardBaseName()
        do {
            let fileURL = try FileBrowserClipboardContent.writeFile(source, in: directory, baseName: baseName)
            refreshFolderChildren(directory)
            updateCurrentDirectoryItems(
                adding: [fileURL],
                removing: [],
                selecting: [fileURL]
            )
            notifyDirectoriesChanged([directory.standardizedFileURL])
            beginInlineNameEdit(url: fileURL, mode: .newItem)
        } catch {
            show(error)
        }
    }
}

#endif
