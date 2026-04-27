#if os(macOS)
import Foundation

struct FilePruneSelectionResult {
    let selectedItemIDs: Set<FileItem.ID>
    let primarySelectedItemID: FileItem.ID?
    let selectionAnchorItemID: FileItem.ID?
    let isParentDirectorySelected: Bool
}

struct FileSelectionStateResult {
    let selectedItemIDs: Set<FileItem.ID>
    let primarySelectedItemID: FileItem.ID?
    let selectionAnchorItemID: FileItem.ID?
    let isParentDirectorySelected: Bool
}

enum FileBrowserSelectionSupport {
    static func itemSelection(
        itemID: FileItem.ID,
        extending: Bool,
        selectedItemIDs: Set<FileItem.ID>,
        primarySelectedItemID: FileItem.ID?,
        selectionAnchorItemID: FileItem.ID?
    ) -> FileSelectionStateResult {
        guard extending else {
            return FileSelectionStateResult(
                selectedItemIDs: [itemID],
                primarySelectedItemID: itemID,
                selectionAnchorItemID: itemID,
                isParentDirectorySelected: false
            )
        }

        var nextSelectedItemIDs = selectedItemIDs
        var nextPrimarySelectedItemID: FileItem.ID? = primarySelectedItemID
        var nextSelectionAnchorItemID: FileItem.ID? = selectionAnchorItemID ?? primarySelectedItemID ?? itemID

        if nextSelectedItemIDs.contains(itemID) {
            nextSelectedItemIDs.remove(itemID)
            if nextPrimarySelectedItemID == itemID {
                nextPrimarySelectedItemID = nextSelectedItemIDs.first
            }
            if nextSelectedItemIDs.isEmpty {
                nextSelectionAnchorItemID = nil
            }
        } else {
            nextSelectedItemIDs.insert(itemID)
            nextPrimarySelectedItemID = itemID
            nextSelectionAnchorItemID = nextSelectionAnchorItemID ?? itemID
        }

        return FileSelectionStateResult(
            selectedItemIDs: nextSelectedItemIDs,
            primarySelectedItemID: nextPrimarySelectedItemID,
            selectionAnchorItemID: nextSelectionAnchorItemID,
            isParentDirectorySelected: false
        )
    }

    static func parentDirectorySelection() -> FileSelectionStateResult {
        FileSelectionStateResult(
            selectedItemIDs: [],
            primarySelectedItemID: nil,
            selectionAnchorItemID: nil,
            isParentDirectorySelected: true
        )
    }

    static func allItemsSelection(items: [FileItem]) -> FileSelectionStateResult {
        FileSelectionStateResult(
            selectedItemIDs: Set(items.map(\.id)),
            primarySelectedItemID: items.last?.id,
            selectionAnchorItemID: items.first?.id,
            isParentDirectorySelected: false
        )
    }

    static func contextMenuSelection(
        itemID: FileItem.ID,
        selectedItemIDs: Set<FileItem.ID>
    ) -> FileSelectionStateResult {
        if selectedItemIDs.contains(itemID) {
            return FileSelectionStateResult(
                selectedItemIDs: selectedItemIDs,
                primarySelectedItemID: itemID,
                selectionAnchorItemID: itemID,
                isParentDirectorySelected: false
            )
        }

        return itemSelection(
            itemID: itemID,
            extending: false,
            selectedItemIDs: selectedItemIDs,
            primarySelectedItemID: nil,
            selectionAnchorItemID: nil
        )
    }

    static func prunedSelection(
        selectedItemIDs: Set<FileItem.ID>,
        primarySelectedItemID: FileItem.ID?,
        selectionAnchorItemID: FileItem.ID?,
        isParentDirectorySelected: Bool,
        canGoUp: Bool,
        visibleItemIndexLookup: [FileItem.ID: Int]
    ) -> FilePruneSelectionResult {
        let visibleSelectedItemIDs = Set(
            selectedItemIDs.filter { visibleItemIndexLookup[$0.standardizedFileURL] != nil }
        )
        let nextIsParentDirectorySelected = isParentDirectorySelected && canGoUp
        let nextPrimarySelectedItemID: FileItem.ID?
        let nextSelectionAnchorItemID: FileItem.ID?

        if visibleSelectedItemIDs.isEmpty {
            nextPrimarySelectedItemID = nil
            nextSelectionAnchorItemID = nil
        } else {
            if let primarySelectedItemID, visibleSelectedItemIDs.contains(primarySelectedItemID) {
                nextPrimarySelectedItemID = primarySelectedItemID
            } else {
                nextPrimarySelectedItemID = visibleSelectedItemIDs.first
            }
            nextSelectionAnchorItemID = selectionAnchorItemID.flatMap {
                visibleItemIndexLookup[$0.standardizedFileURL] == nil ? nextPrimarySelectedItemID : $0
            }
        }

        return FilePruneSelectionResult(
            selectedItemIDs: visibleSelectedItemIDs,
            primarySelectedItemID: nextPrimarySelectedItemID,
            selectionAnchorItemID: nextSelectionAnchorItemID,
            isParentDirectorySelected: nextIsParentDirectorySelected
        )
    }

}

#endif
