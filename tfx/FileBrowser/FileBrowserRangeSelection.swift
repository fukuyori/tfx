#if os(macOS)
import Foundation

struct FileRangeSelectionResult {
    let selectedItemIDs: Set<FileItem.ID>
    let primarySelectedItemID: FileItem.ID
    let anchorItemID: FileItem.ID
}

extension FileBrowserSelectionSupport {
    static func rangeSelection(
        items: [FileItem],
        visibleItemIndexLookup: [FileItem.ID: Int],
        existingAnchorID: FileItem.ID?,
        primarySelectedItemID: FileItem.ID?,
        targetRow: Int,
        fallbackCurrentRow: Int?,
        parentOffset: Int
    ) -> FileRangeSelectionResult? {
        guard !items.isEmpty else { return nil }

        let targetItemIndex = targetRow - parentOffset
        let fallbackItemIndex = (fallbackCurrentRow ?? targetRow) - parentOffset
        let anchorID = resolvedAnchorID(
            items: items,
            visibleItemIndexLookup: visibleItemIndexLookup,
            existingAnchorID: existingAnchorID,
            primarySelectedItemID: primarySelectedItemID,
            fallbackItemIndex: fallbackItemIndex,
            targetItemIndex: targetItemIndex
        )

        guard
            let anchorID,
            let anchorIndex = visibleItemIndexLookup[anchorID.standardizedFileURL]
        else {
            return nil
        }

        let clampedTargetIndex = clampedIndex(targetItemIndex, count: items.count)
        let range = min(anchorIndex, clampedTargetIndex)...max(anchorIndex, clampedTargetIndex)
        return FileRangeSelectionResult(
            selectedItemIDs: Set(items[range].map(\.id)),
            primarySelectedItemID: items[clampedTargetIndex].id,
            anchorItemID: anchorID
        )
    }

    private static func resolvedAnchorID(
        items: [FileItem],
        visibleItemIndexLookup: [FileItem.ID: Int],
        existingAnchorID: FileItem.ID?,
        primarySelectedItemID: FileItem.ID?,
        fallbackItemIndex: Int,
        targetItemIndex: Int
    ) -> FileItem.ID? {
        if existingAnchorID != nil {
            return existingAnchorID
        }

        if let primarySelectedItemID, visibleItemIndexLookup[primarySelectedItemID.standardizedFileURL] != nil {
            return primarySelectedItemID
        } else if items.indices.contains(fallbackItemIndex) {
            return items[fallbackItemIndex].id
        } else if items.indices.contains(targetItemIndex) {
            return items[targetItemIndex].id
        } else {
            return items.first?.id
        }
    }
}
#endif
