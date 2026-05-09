#if os(macOS)
import SwiftUI

struct FileItemContextMenu: View {
    @ObservedObject var model: FileBrowserModel
    let item: FileItem
    let activate: () -> Void

    @ViewBuilder
    var body: some View {
        Button("Open") {
            activate()
            model.selectForContextMenu(item)
            model.openFromContextMenu(item)
        }

        Button("Rename") {
            activate()
            model.selectForContextMenu(item)
            model.renameSelectedItem()
        }

        Button("Move to Trash") {
            activate()
            model.selectForContextMenu(item)
            model.moveSelectedItemsToTrash()
        }

        Button("Copy Items") {
            activate()
            model.selectForContextMenu(item)
            model.copySelectedItems()
        }

        Button("Cut Items") {
            activate()
            model.selectForContextMenu(item)
            model.cutSelectedItems()
        }

        Button("Paste Here") {
            activate()
            model.pasteItems(into: item.isDirectory ? item.url : model.currentDirectory)
        }
        .disabled(!model.canPaste)

        Button("Compress to Zip") {
            activate()
            model.selectForContextMenu(item)
            model.compressSelectedItemsToZip()
        }

        if ZipArchiveBrowser.isZipArchive(item.url) {
            Button("Extract Zip") {
                activate()
                model.selectForContextMenu(item)
                model.extractZipArchive(item)
            }
        }

        Divider()

        Button("Reveal in Finder") {
            activate()
            model.selectForContextMenu(item)
            model.revealSelectedItemsInFinder()
        }

        Button("Copy Path") {
            model.copyPath(item.url)
        }

        if item.isDirectory {
            Button(model.isFolderPinned(item.url) ? "Unpin Folder" : "Pin Folder") {
                activate()
                model.togglePinnedFolder(item.url)
            }

            Button("Open Terminal Here") {
                activate()
                model.openTerminal(at: item.url)
            }
        }
    }
}

extension FilePane {
    @ViewBuilder
    var emptyFileAreaContextMenu: some View {
        Button("Paste Here") {
            activate()
            model.pasteItems()
        }
        .disabled(!model.canPaste)

        Button("New Folder") {
            activate()
            model.createFolder()
        }

        Button("New File") {
            activate()
            model.createFile()
        }

        Button("Select All") {
            activate()
            model.selectAllVisibleItems()
        }
        .disabled(model.items.isEmpty)

        Divider()

        Button("Reveal in Finder") {
            activate()
            model.revealInFinder(model.currentDirectory)
        }

        Button(model.isFolderPinned(model.currentDirectory) ? "Unpin Folder" : "Pin Folder") {
            activate()
            model.togglePinnedFolder(model.currentDirectory)
        }

        Button("Open Terminal Here") {
            activate()
            model.openTerminal()
        }

        Button("Copy Current Path") {
            activate()
            model.copyPath(model.currentDirectory)
        }
    }
}

#endif
