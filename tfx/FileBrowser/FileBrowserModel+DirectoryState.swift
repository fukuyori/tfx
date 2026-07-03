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
        // `availableCapacityText` boils down to a `statvfs`,
        // which can block for seconds (or minutes on a dead
        // mount) against network volumes — the reload path
        // already fetches it off the main thread for exactly
        // that reason. Do the same here.
        let directory = currentDirectory
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let nextText = FileBrowserDirectoryReader.availableCapacityText(for: directory)
            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    self.currentDirectory.standardizedFileURL == directory.standardizedFileURL,
                    self.availableCapacityText != nextText
                else { return }
                self.availableCapacityText = nextText
            }
        }
    }
}

#endif
