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
        setSelectionState(
            selectedItemIDs: [],
            primarySelectedItemID: nil,
            selectionAnchorItemID: nil,
            isParentDirectorySelected: false
        )
    }

    func applyPendingFileSelectionIfVisible() {
        guard let pendingFileSelectionURL else { return }
        let key = pendingFileSelectionURL.standardizedFileURL
        guard visibleItemIndexLookup[key] != nil else { return }

        setSelectionState(
            selectedItemIDs: [key],
            primarySelectedItemID: key,
            selectionAnchorItemID: key,
            isParentDirectorySelected: false
        )
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
        setSelectionState(
            selectedItemIDs: result.selectedItemIDs,
            primarySelectedItemID: result.primarySelectedItemID,
            selectionAnchorItemID: result.selectionAnchorItemID,
            isParentDirectorySelected: result.isParentDirectorySelected
        )
    }

    func applySelection(_ selection: FileSelectionStateResult) {
        if let edit = inlineNameEdit, !selection.selectedItemIDs.contains(edit.url) {
            cancelInlineNameEdit()
        }

        setSelectionState(
            selectedItemIDs: selection.selectedItemIDs,
            primarySelectedItemID: selection.primarySelectedItemID,
            selectionAnchorItemID: selection.selectionAnchorItemID,
            isParentDirectorySelected: selection.isParentDirectorySelected
        )
    }

    /// Centralized selection-state mutator. Each setter is
    /// guarded so identical writes don't republish; this
    /// matters because `selectedItemIDs.didSet` used to chain
    /// into `refreshPreviewURLs` and the duplicate work was
    /// triggering "Publishing changes from within view updates"
    /// runtime warnings on rapid selection updates (drop,
    /// new-folder, etc.).
    func setSelectionState(
        selectedItemIDs nextSelectedItemIDs: Set<FileItem.ID>,
        primarySelectedItemID nextPrimarySelectedItemID: FileItem.ID?,
        selectionAnchorItemID nextSelectionAnchorItemID: FileItem.ID?,
        isParentDirectorySelected nextIsParentDirectorySelected: Bool
    ) {
        if isParentDirectorySelected != nextIsParentDirectorySelected {
            isParentDirectorySelected = nextIsParentDirectorySelected
        }
        if selectedItemIDs != nextSelectedItemIDs {
            selectedItemIDs = nextSelectedItemIDs
        }
        if primarySelectedItemID != nextPrimarySelectedItemID {
            primarySelectedItemID = nextPrimarySelectedItemID
        }
        if selectionAnchorItemID != nextSelectionAnchorItemID {
            selectionAnchorItemID = nextSelectionAnchorItemID
        }
        refreshPreviewURLs()
    }
}

#endif
