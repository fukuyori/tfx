#if os(macOS)
import Foundation
import UniformTypeIdentifiers

extension FileBrowserModel {
    func createFolder() {
        guard ZipArchiveBrowser.location(for: currentDirectory) == nil else {
            show(ZipArchiveBrowserError.unsupportedWrite)
            return
        }

        do {
            guard let result = try FileBrowserFileOperations.createFolder(named: String(localized: "Untitled Folder"), in: currentDirectory) else { return }
            let folderURL = result.folderURL
            refreshFolderChildren(currentDirectory)
            updateCurrentDirectoryItems(adding: [folderURL], selecting: [folderURL])
            notifyDirectoriesChanged([result.affectedDirectory])
            beginInlineNameEdit(url: folderURL, mode: .newItem)
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
            guard let result = try FileBrowserFileOperations.createFile(named: String(localized: "Untitled.txt"), in: currentDirectory) else { return }
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
        selectedItemIDs = [standardizedURL]
        primarySelectedItemID = standardizedURL
        selectionAnchorItemID = standardizedURL
        isParentDirectorySelected = false
    }

    func setInlineNameEditText(_ text: String) {
        guard var edit = inlineNameEdit else { return }
        edit.text = text
        inlineNameEdit = edit
    }

    func commitInlineNameEdit() {
        guard let edit = inlineNameEdit else { return }
        guard let item = allItemLookup[edit.url.standardizedFileURL] else {
            inlineNameEdit = nil
            return
        }

        let trimmed = edit.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelInlineNameEdit()
            return
        }
        guard trimmed != edit.originalName else {
            inlineNameEdit = nil
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
        guard let edit = inlineNameEdit else { return }
        inlineNameEdit = nil

        guard edit.mode == .newItem else { return }

        do {
            try FileManager.default.removeItem(at: edit.url)
            let affectedDirectory = edit.url.deletingLastPathComponent().standardizedFileURL
            refreshFolderChildren(affectedDirectory)
            updateCurrentDirectoryItems(
                removing: [edit.url],
                selecting: []
            )
            notifyDirectoriesChanged([affectedDirectory])
        } catch {
            show(error)
        }
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

        do {
            guard let result = try FileBrowserFileOperations.createZipArchive(from: itemsToArchive, in: currentDirectory) else { return }
            updateCurrentDirectoryItems(
                adding: [result.archiveURL],
                selecting: [result.archiveURL]
            )
            notifyDirectoriesChanged([result.affectedDirectory])
        } catch {
            show(error)
        }
    }

    func extractZipArchive(_ item: FileItem) {
        guard ZipArchiveBrowser.isZipArchive(item.url) else { return }
        guard ZipArchiveBrowser.location(for: currentDirectory) == nil else {
            show(ZipArchiveBrowserError.unsupportedWrite)
            return
        }

        do {
            guard let result = try FileBrowserFileOperations.extractZipArchive(item.url, into: currentDirectory) else { return }
            refreshFolderChildren(currentDirectory)
            updateCurrentDirectoryItems(
                adding: [result.extractedURL],
                selecting: [result.extractedURL]
            )
            notifyDirectoriesChanged([result.affectedDirectory])
        } catch {
            show(error)
        }
    }
}

#endif
