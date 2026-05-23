#if os(macOS)
import SwiftUI

/// Context menu for a file row.
///
/// `FileRowInteractionView.rightMouseDown` has already called `activate()`
/// and `selectForContextMenu(item)` before this menu opens, so the actions
/// here can operate directly on the model's current selection without
/// repeating that wiring. The `activate` closure is retained for the few
/// actions (Paste Here) that need to refresh the active pane after a
/// non-selection-based mutation.
struct FileItemContextMenu: View {
    @ObservedObject var model: FileBrowserModel
    let item: FileItem
    let activate: () -> Void

    @ViewBuilder
    var body: some View {
        Button("Open") {
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
            model.moveSelectedItemsToTrash()
        }

        Menu("Tags") {
            Button("Add Custom Tag…") {
                model.addCustomTagFromPrompt()
            }

            Divider()

            ForEach(FileTag.systemTagOptions) { option in
                Button {
                    model.toggleSystemTag(colorID: option.colorID)
                } label: {
                    Label {
                        Text(option.localizedName)
                    } icon: {
                        // `Image(nsImage:)` with a non-template image
                        // preserves the baked-in color in the menu;
                        // `Image(systemName:)` + `.foregroundStyle()` gets
                        // re-tinted by macOS to the menu foreground color.
                        Image(nsImage: option.menuIcon)
                    }
                }
            }

            // Custom tags surfaced from items currently loaded in this
            // pane. We intentionally do not enumerate the user's full tag
            // library (would require Spotlight or Finder's private plist) —
            // surfacing the in-view tags is enough to re-apply them to
            // sibling files without leaving tfx.
            let customTags = model.customTagsInCurrentDirectory
            if !customTags.isEmpty {
                Divider()
                ForEach(customTags, id: \.name) { tag in
                    Button {
                        model.toggleCustomTag(tag)
                    } label: {
                        if let icon = tag.menuIcon {
                            Label {
                                Text(tag.name)
                            } icon: {
                                Image(nsImage: icon)
                            }
                        } else {
                            Text(tag.name)
                        }
                    }
                }
            }
        }

        Divider()

        Button("Rename") {
            model.renameSelectedItem()
        }

        Button("Compress to Zip") {
            model.compressSelectedItemsToZip()
        }

        if ZipArchiveBrowser.isZipArchive(item.url) {
            Button("Extract Zip") {
                model.extractZipArchive(item)
            }
        }

        Button("Copy Items") {
            model.copySelectedItems()
        }

        Button("Cut Items") {
            model.cutSelectedItems()
        }

        Button("Paste Here") {
            activate()
            model.pasteItems(into: item.isDirectory ? item.url : model.currentDirectory)
        }
        .disabled(!model.canPaste)

        Divider()

        Button("Reveal in Finder") {
            model.revealSelectedItemsInFinder()
        }

        Button("Copy Path") {
            model.copyPath(item.url)
        }

        if item.isDirectory {
            Divider()

            Button(model.isFolderPinned(item.url) ? "Unpin Folder" : "Pin Folder") {
                model.togglePinnedFolder(item.url)
            }

            Button("Open Terminal Here") {
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
