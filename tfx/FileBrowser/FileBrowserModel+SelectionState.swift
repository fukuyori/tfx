#if os(macOS)
import Foundation

extension FileBrowserModel {
    var selectedVisibleItems: [FileItem] {
        FileBrowserDirectoryState.selectedVisibleItems(
            selectedItemIDs: selectedItemIDs,
            allItemLookup: allItemLookup,
            visibleItemIndexLookup: visibleItemIndexLookup
        )
    }

    var selectedFileListRowID: FileListRowID? {
        FileBrowserSelectionSupport.selectedFileListRowID(
            isParentDirectorySelected: isParentDirectorySelected,
            primarySelectedItemID: primarySelectedItemID
        )
    }

    func isSelected(_ item: FileItem) -> Bool {
        selectedItemIDs.contains(item.id)
    }

    func select(_ item: FileItem, extending: Bool = false) {
        applySelection(
            FileBrowserSelectionSupport.itemSelection(
                itemID: item.id,
                extending: extending,
                selectedItemIDs: selectedItemIDs,
                primarySelectedItemID: primarySelectedItemID,
                selectionAnchorItemID: selectionAnchorItemID
            )
        )
    }

    func selectParentDirectory() {
        guard canGoUp else { return }
        applySelection(FileBrowserSelectionSupport.parentDirectorySelection())
    }

    func ensureFileSelection() {
        if isParentDirectorySelected || primarySelectedItem != nil {
            return
        }

        if canGoUp {
            selectParentDirectory()
        } else if let firstItem = items.first {
            select(firstItem)
        }
    }

    func selectForContextMenu(_ item: FileItem) {
        applySelection(
            FileBrowserSelectionSupport.contextMenuSelection(
                itemID: item.id,
                selectedItemIDs: selectedItemIDs
            )
        )
    }

    func selectAllVisibleItems() {
        applySelection(FileBrowserSelectionSupport.allItemsSelection(items: items))
    }

    func clearSelection() {
        inlineNameEdit = nil
        isParentDirectorySelected = false
        selectedItemIDs.removeAll()
        primarySelectedItemID = nil
        selectionAnchorItemID = nil
    }

    func applyPendingFileSelectionIfVisible() {
        guard let pendingFileSelectionURL else { return }
        let key = pendingFileSelectionURL.standardizedFileURL
        guard visibleItemIndexLookup[key] != nil else { return }

        selectedItemIDs = [key]
        primarySelectedItemID = key
        selectionAnchorItemID = key
        isParentDirectorySelected = false
        self.pendingFileSelectionURL = nil
    }

    func pruneSelection() {
        let result = FileBrowserSelectionSupport.prunedSelection(
            selectedItemIDs: selectedItemIDs,
            primarySelectedItemID: primarySelectedItemID,
            selectionAnchorItemID: selectionAnchorItemID,
            isParentDirectorySelected: isParentDirectorySelected,
            canGoUp: canGoUp,
            visibleItemIndexLookup: visibleItemIndexLookup
        )
        selectedItemIDs = result.selectedItemIDs
        primarySelectedItemID = result.primarySelectedItemID
        selectionAnchorItemID = result.selectionAnchorItemID
        isParentDirectorySelected = result.isParentDirectorySelected
    }

    func applySelection(_ selection: FileSelectionStateResult) {
        if let edit = inlineNameEdit, !selection.selectedItemIDs.contains(edit.url) {
            cancelInlineNameEdit()
        }

        isParentDirectorySelected = selection.isParentDirectorySelected
        selectedItemIDs = selection.selectedItemIDs
        primarySelectedItemID = selection.primarySelectedItemID
        selectionAnchorItemID = selection.selectionAnchorItemID
    }
}

#endif
