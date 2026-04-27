#if os(macOS)
import Foundation
import UniformTypeIdentifiers

extension FileBrowserModel {
    func createFolder() {
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

    func renameSelectedItem() {
        guard selectedItemIDs.count == 1, let selectedItem = primarySelectedItem else { return }

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
}

#endif
