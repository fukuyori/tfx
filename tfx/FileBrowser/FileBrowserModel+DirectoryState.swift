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

    var canPaste: Bool {
        clipboard?.urls.isEmpty == false || FileBrowserExternalActions.fileClipboardFromPasteboard() != nil
    }

    var primarySelectedItem: FileItem? {
        guard !isParentDirectorySelected else { return nil }
        guard let primarySelectedItemID else { return nil }
        return allItemLookup[primarySelectedItemID.standardizedFileURL]
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
