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
    let executeUserCommand: (UserCommand, [FileItem]) -> Void
    @EnvironmentObject private var shortcutStore: ShortcutStore
    @EnvironmentObject private var userCommandStore: UserCommandStore

    @ViewBuilder
    var body: some View {
        Button("Open") {
            model.openFromContextMenu(item)
        }
        .keyboardShortcut(shortcutStore.info(.openItem))

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

        UserCommandMenuItems(
            model: model,
            selection: model.selectedItems.isEmpty ? [item] : model.selectedItems,
            activate: activate,
            executeUserCommand: executeUserCommand
        )

        if !userCommandStore.matchingCommands(
            selection: model.selectedItems.isEmpty ? [item] : model.selectedItems,
            currentDirectory: model.currentDirectory,
            isGitRepository: model.isCurrentDirectoryGitRepository
        ).isEmpty {
            Divider()
        }

        Button("Move to Trash") {
            model.moveSelectedItemsToTrash()
        }
        .keyboardShortcut(shortcutStore.info(.moveToTrash))

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
        .keyboardShortcut(shortcutStore.info(.rename))

        Button("Compress to Zip") {
            model.compressSelectedItemsToZip()
        }
        .keyboardShortcut(shortcutStore.info(.compressToZip))

        if ZipArchiveBrowser.isZipArchive(item.url) {
            Button("Extract Zip") {
                model.extractZipArchive(item)
            }
            .keyboardShortcut(shortcutStore.info(.extractZip))
        }

        Button("Copy Items") {
            model.copySelectedItems()
        }
        .keyboardShortcut(shortcutStore.info(.copyItems))

        Button("Cut Items") {
            model.cutSelectedItems()
        }
        .keyboardShortcut(shortcutStore.info(.cutItems))

        Button("Paste Here") {
            activate()
            model.pasteItems(into: item.isDirectory ? item.url : model.currentDirectory)
        }
        .keyboardShortcut(shortcutStore.info(.pasteItems))
        .disabled(!model.canPaste)

        Divider()

        Button("Reveal in Finder") {
            model.revealSelectedItemsInFinder()
        }
        .keyboardShortcut(shortcutStore.info(.revealInFinder))

        Button("Copy Path") {
            model.copyPath(item.url)
        }
        .keyboardShortcut(shortcutStore.info(.copyPath))

        if item.isDirectory {
            Divider()

            Button(model.isFolderPinned(item.url) ? "Unpin Folder" : "Pin Folder") {
                model.togglePinnedFolder(item.url)
            }

            Button("Open Terminal Here") {
                model.openTerminal(at: item.url)
            }
            .keyboardShortcut(shortcutStore.info(.openTerminal))
        }
    }
}

struct EmptyFileAreaContextMenu: View {
    @ObservedObject var model: FileBrowserModel
    let activate: () -> Void
    let executeUserCommand: (UserCommand, [FileItem]) -> Void
    @EnvironmentObject private var shortcutStore: ShortcutStore
    @EnvironmentObject private var userCommandStore: UserCommandStore

    @ViewBuilder
    var body: some View {
        let currentCommands = userCommandStore.matchingCommands(
            selection: [],
            currentDirectory: model.currentDirectory,
            isGitRepository: model.isCurrentDirectoryGitRepository
        )
        if !currentCommands.isEmpty {
            UserCommandMenuItems(
                model: model,
                selection: [],
                activate: activate,
                executeUserCommand: executeUserCommand
            )

            Divider()
        }

        Button("New Folder") {
            activate()
            model.createFolder()
        }
        .keyboardShortcut(shortcutStore.info(.newFolder))

        Button("New File") {
            activate()
            model.createFile()
        }
        .keyboardShortcut(shortcutStore.info(.newFile))

        Divider()

        Button("Paste Here") {
            activate()
            model.pasteItems()
        }
        .keyboardShortcut(shortcutStore.info(.pasteItems))
        .disabled(!model.canPaste)

        Divider()

        Button("Select All") {
            activate()
            model.selectAllVisibleItems()
        }
        .keyboardShortcut(shortcutStore.info(.selectAll))
        .disabled(model.items.isEmpty)

        Divider()

        Button("Reveal in Finder") {
            activate()
            model.revealInFinder(model.currentDirectory)
        }
        .keyboardShortcut(shortcutStore.info(.revealInFinder))

        Button("Copy Current Path") {
            activate()
            model.copyPath(model.currentDirectory)
        }
        .keyboardShortcut(shortcutStore.info(.copyPath))

        Divider()

        Button(model.isFolderPinned(model.currentDirectory) ? "Unpin Folder" : "Pin Folder") {
            activate()
            model.togglePinnedFolder(model.currentDirectory)
        }

        Button("Open Terminal Here") {
            activate()
            model.openTerminal()
        }
        .keyboardShortcut(shortcutStore.info(.openTerminal))
    }
}

private struct UserCommandMenuItems: View {
    @ObservedObject var model: FileBrowserModel
    let selection: [FileItem]
    let activate: () -> Void
    let executeUserCommand: (UserCommand, [FileItem]) -> Void
    @EnvironmentObject private var userCommandStore: UserCommandStore

    var body: some View {
        ForEach(matchingCommands) { command in
            if let shortcut = command.shortcut {
                Button(command.name) {
                    activate()
                    executeUserCommand(command, selection)
                }
                .keyboardShortcut(shortcut)
            } else {
                Button(command.name) {
                    activate()
                    executeUserCommand(command, selection)
                }
            }
        }
    }

    private var matchingCommands: [UserCommand] {
        userCommandStore.matchingCommands(
            selection: selection,
            currentDirectory: model.currentDirectory,
            isGitRepository: model.isCurrentDirectoryGitRepository
        )
    }
}

#endif
