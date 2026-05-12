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

        if !item.isDirectory {
            Menu("Open With") {
                let apps = model.applicationsToOpen(item)
                ForEach(apps, id: \.self) { appURL in
                    Button {
                        model.openItem(item, withApplicationAt: appURL)
                    } label: {
                        Label {
                            Text(FileBrowserExternalActions.applicationDisplayName(appURL))
                        } icon: {
                            Image(nsImage: FileBrowserExternalActions.applicationIcon(appURL))
                        }
                    }
                }
                if !apps.isEmpty {
                    Divider()
                }
                Button("Other…") {
                    model.chooseApplicationAndOpen(item)
                }
            }
        }

        Divider()

        Button("Move to Trash") {
            activate()
            model.selectForContextMenu(item)
            model.moveSelectedItemsToTrash()
        }

        Divider()

        Button("Rename") {
            activate()
            model.selectForContextMenu(item)
            model.renameSelectedItem()
        }

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
            Divider()

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

struct EmptyFileAreaContextMenu: View {
    @ObservedObject var model: FileBrowserModel
    let activate: () -> Void

    @ViewBuilder
    var body: some View {
        Button("New Folder") {
            activate()
            model.createFolder()
        }

        Button("New File") {
            activate()
            model.createFile()
        }

        Divider()

        Button("Paste Here") {
            activate()
            model.pasteItems()
        }
        .disabled(!model.canPaste)

        Divider()

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

        Button("Copy Current Path") {
            activate()
            model.copyPath(model.currentDirectory)
        }

        Divider()

        Button(model.isFolderPinned(model.currentDirectory) ? "Unpin Folder" : "Pin Folder") {
            activate()
            model.togglePinnedFolder(model.currentDirectory)
        }

        Button("Open Terminal Here") {
            activate()
            model.openTerminal()
        }
    }
}

#endif
