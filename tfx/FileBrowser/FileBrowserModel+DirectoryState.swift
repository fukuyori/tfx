#if os(macOS)
import Foundation

extension FileBrowserModel {
    var allItemCount: Int {
        allItems.count
    }

    var hasSelection: Bool {
        !selectedItemIDs.isEmpty
    }

    var selectionCount: Int {
        selectedItemIDs.count
    }

    /// Whether "Paste as Plain Text" should be enabled in the
    /// context menu. Plain text is the only required shape, so
    /// this is just a shortcut for "does the pasteboard have
    /// any text-shaped content at all?" — true for rich text
    /// from Word, plain `.string`, and anything else where
    /// NSPasteboard's `.string` accessor returns a non-empty
    /// rendering.
    var canPasteAsText: Bool {
        FileBrowserClipboardContent.plainTextSource() != nil
    }

    var canPaste: Bool {
        // File URLs (internal clipboard or NSPasteboard
        // file-URL) take priority because that's the
        // copy/move-files path. Otherwise enable the menu
        // whenever the clipboard exposes anything we can turn
        // into a file (text, image, URL shortcut, etc.) —
        // mirrors the runtime behavior of `pasteItems()`.
        if clipboard?.urls.isEmpty == false { return true }
        if FileBrowserExternalActions.fileClipboardFromPasteboard() != nil { return true }
        return FileBrowserClipboardContent.defaultSource() != nil
    }

    var primarySelectedItem: FileItem? {
        guard !isParentDirectorySelected else { return nil }
        guard let primarySelectedItemID else { return nil }
        return allItemLookup[primarySelectedItemID]
    }

    var selectedItems: [FileItem] {
        FileBrowserDirectoryState.selectedItems(from: selectedItemIDs, lookup: allItemLookup)
    }

    func updateCurrentDirectoryItems(
        adding addedURLs: [URL] = [],
        removing removedURLs: [URL] = [],
        selecting selectionURLs: [URL] = [],
        pruneAfterUpdate: Bool = true
    ) {
        let update = FileBrowserDirectoryState.applyingCurrentDirectoryChanges(
            allItems: allItems,
            currentDirectory: currentDirectory,
            adding: addedURLs,
            removing: removedURLs,
            selecting: selectionURLs
        )
        allItems = update.allItems
        allItemLookup = update.allItemLookup

        if update.shouldRefreshPreview {
            refreshPreviewURLs()
        }

        updateAvailableCapacity()

        if !update.selectedURLs.isEmpty {
            setSelectionState(
                selectedItemIDs: Set(update.selectedURLs),
                primarySelectedItemID: update.selectedURLs.last,
                selectionAnchorItemID: update.selectedURLs.first,
                isParentDirectorySelected: false
            )
        }

        applyFiltersAndSortAsync(pruneAfterUpdate: pruneAfterUpdate)
    }

    func rebuildVisibleItemIndexes() {
        visibleItemIndexLookup = FileBrowserDirectoryState.visibleItemIndexLookup(for: items)
    }

    func refreshPreviewURLs() {
        let nextPreviewURLs = FileBrowserDirectoryState.previewURLs(
            isParentDirectorySelected: isParentDirectorySelected,
            selectedItemIDs: selectedItemIDs,
            allItemLookup: allItemLookup
        )
        if previewURLs != nextPreviewURLs {
            previewURLs = nextPreviewURLs
        }
    }

    func notifyDirectoriesChanged(_ directories: [URL], removedURLs: [URL] = []) {
        FileOperationNotifier.notifyDirectoriesChanged(directories, removedURLs: removedURLs, originModelID: modelID)
    }

    func updateAvailableCapacity() {
        let nextText = FileBrowserDirectoryReader.availableCapacityText(for: currentDirectory)
        if availableCapacityText != nextText {
            availableCapacityText = nextText
        }
    }
}

#endif
