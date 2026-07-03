#if os(macOS)
import Foundation
import UniformTypeIdentifiers

extension FileBrowserModel {
    func createFolder() {
        guard ZipArchiveBrowser.location(for: currentDirectory) == nil else {
            show(ZipArchiveBrowserError.unsupportedWrite)
            return
        }

        let targetDirectory = currentDirectory.standardizedFileURL
        do {
            // Use the modal name-input dialog (matches the
            // pre-inline-edit behavior): the user types a name
            // into an `NSAlert`-hosted text field and presses OK,
            // then we create the folder with that name.
            guard let result = try FileBrowserFileOperations.createFolder(in: targetDirectory) else { return }
            let folderURL = result.folderURL
            refreshFolderChildren(targetDirectory)
            if self.currentDirectory.standardizedFileURL == targetDirectory {
                updateCurrentDirectoryItems(adding: [folderURL], selecting: [folderURL])
            }
            notifyDirectoriesChanged([result.affectedDirectory])
        } catch {
            show(error)
        }
    }

    func createFile() {
        guard ZipArchiveBrowser.location(for: currentDirectory) == nil else {
            show(ZipArchiveBrowserError.unsupportedWrite)
            return
        }

        do {
            guard let result = try FileBrowserFileOperations.createFile(named: DefaultPlaceholderNames.untitledFileName(), in: currentDirectory) else { return }
            updateCurrentDirectoryItems(adding: [result.fileURL], selecting: [result.fileURL])
            notifyDirectoriesChanged([result.affectedDirectory])
            beginInlineNameEdit(url: result.fileURL, mode: .newItem)
        } catch {
            show(error)
        }
    }

    func renameSelectedItem() {
        guard selectedItemIDs.count == 1, let selectedItem = primarySelectedItem else { return }
        guard !ZipArchiveBrowser.canCopyFromArchive(selectedItem.url) else {
            show(ZipArchiveBrowserError.unsupportedWrite)
            return
        }

        beginInlineNameEdit(url: selectedItem.url, mode: .rename)
    }

    func beginInlineNameEdit(url: URL, mode: InlineNameEdit.Mode) {
        let standardizedURL = url.standardizedFileURL
        inlineNameEdit = InlineNameEdit(
            url: standardizedURL,
            originalName: standardizedURL.lastPathComponent,
            text: standardizedURL.lastPathComponent,
            mode: mode
        )
        setSelectionState(
            selectedItemIDs: [standardizedURL],
            primarySelectedItemID: standardizedURL,
            selectionAnchorItemID: standardizedURL,
            isParentDirectorySelected: false
        )
    }

    func setInlineNameEditText(_ text: String) {
        guard var edit = inlineNameEdit else { return }
        // Suppress no-op writes. SwiftUI's TextField fires its
        // binding setter once on mount with the SAME text it
        // just read via the getter; without this guard the
        // model would publish a change, SwiftUI would re-render
        // the row, the TextField would re-mount, fire its
        // setter again — an infinite loop that manifests as
        // continuous "Publishing changes from within view
        // updates" warnings + AttributeGraph cycle, and causes
        // the inline-name edit to appear to auto-commit on
        // creation.
        guard edit.text != text else { return }
        edit.text = text
        inlineNameEdit = edit
    }

    func commitInlineNameEdit() {
        commitInlineNameEdit(text: inlineNameEdit?.text)
    }

    func commitInlineNameEdit(text: String?) {
        guard let edit = inlineNameEdit else { return }
        // `edit.url` is standardized at `beginInlineNameEdit`, so
        // it already matches `allItemLookup`'s key shape.
        guard let item = allItemLookup[edit.url] else {
            inlineNameEdit = nil
            return
        }

        let trimmed = (text ?? edit.text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelInlineNameEdit()
            return
        }
        guard trimmed != edit.originalName else {
            inlineNameEdit = nil
            if edit.mode == .newItem {
                let affectedDirectory = edit.url.deletingLastPathComponent().standardizedFileURL
                if FileBrowserExternalActions.isDirectory(edit.url) {
                    refreshFolderChildren(affectedDirectory)
                }
                notifyDirectoriesChanged([affectedDirectory])
            }
            return
        }

        do {
            guard let result = try FileBrowserFileOperations.rename(item, to: trimmed) else {
                inlineNameEdit = nil
                return
            }
            inlineNameEdit = nil
            refreshFolderChildren(result.affectedDirectory)
            updateCurrentDirectoryItems(
                adding: [result.destinationURL],
                removing: [result.sourceURL],
                selecting: [result.destinationURL]
            )
            notifyDirectoriesChanged([result.affectedDirectory])
        } catch {
            show(error)
        }
    }

    func cancelInlineNameEdit() {
        // Dismiss the inline-edit overlay without altering the
        // file on disk. This matches Finder: pressing Escape
        // during a "New File" / "New Folder" inline edit keeps
        // the just-created item with its default name; only an
        // explicit Delete (or trashing the file) removes it.
        // For `.rename` the file simply keeps its original name
        // because we never issued the rename.
        guard inlineNameEdit != nil else { return }
        inlineNameEdit = nil
    }

    func moveSelectedItemsToTrash() {
        let itemsToTrash = selectedItems
        guard !itemsToTrash.contains(where: { ZipArchiveBrowser.canCopyFromArchive($0.url) }) else {
            show(ZipArchiveBrowserError.unsupportedWrite)
            return
        }

        do {
            guard let result = try FileBrowserFileOperations.moveToTrash(itemsToTrash) else { return }
            for directory in result.affectedDirectories {
                refreshFolderChildren(directory)
            }
            clearSelection()
            updateCurrentDirectoryItems(removing: result.removedURLs)
            notifyDirectoriesChanged(Array(result.affectedDirectories))
        } catch {
            show(error)
        }
    }

    func compressSelectedItemsToZip() {
        let itemsToArchive = selectedItems
        guard ZipArchiveBrowser.location(for: currentDirectory) == nil else {
            show(ZipArchiveBrowserError.unsupportedWrite)
            return
        }
        guard !isArchiveOperationInProgress else { return }
        isArchiveOperationInProgress = true

        // `ditto` runs until the whole tree is compressed —
        // seconds to minutes for large folders. Run it off the
        // main thread so the app doesn't beachball, then hop
        // back for the item-list bookkeeping.
        let directory = currentDirectory
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = Result {
                try FileBrowserFileOperations.createZipArchive(from: itemsToArchive, in: directory)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isArchiveOperationInProgress = false
                switch outcome {
                case let .success(result):
                    guard let result else { return }
                    self.updateCurrentDirectoryItems(
                        adding: [result.archiveURL],
                        selecting: [result.archiveURL]
                    )
                    self.notifyDirectoriesChanged([result.affectedDirectory])
                case let .failure(error):
                    self.show(error)
                }
            }
        }
    }

    func extractZipArchive(_ item: FileItem) {
        guard ZipArchiveBrowser.isZipArchive(item.url) else { return }
        guard ZipArchiveBrowser.location(for: currentDirectory) == nil else {
            show(ZipArchiveBrowserError.unsupportedWrite)
            return
        }
        guard !isArchiveOperationInProgress else { return }
        isArchiveOperationInProgress = true

        let directory = currentDirectory
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome = Result {
                try FileBrowserFileOperations.extractZipArchive(item.url, into: directory)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isArchiveOperationInProgress = false
                switch outcome {
                case let .success(result):
                    guard let result else { return }
                    self.refreshFolderChildren(directory)
                    self.updateCurrentDirectoryItems(
                        adding: [result.extractedURL],
                        selecting: [result.extractedURL]
                    )
                    self.notifyDirectoriesChanged([result.affectedDirectory])
                case let .failure(error):
                    self.show(error)
                }
            }
        }
    }
}

#endif
