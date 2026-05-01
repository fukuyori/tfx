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
            guard let result = try FileBrowserFileOperations.createFolder(in: currentDirectory) else { return }
            let folderURL = result.folderURL
            refreshFolderChildren(currentDirectory)
            updateCurrentDirectoryItems(adding: [folderURL], selecting: [folderURL])
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
            guard let result = try FileBrowserFileOperations.createFile(in: currentDirectory) else { return }
            updateCurrentDirectoryItems(adding: [result.fileURL], selecting: [result.fileURL])
            notifyDirectoriesChanged([result.affectedDirectory])
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

        do {
            guard let result = try FileBrowserFileOperations.rename(selectedItem) else { return }
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
