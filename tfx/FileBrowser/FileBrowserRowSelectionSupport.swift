#if os(macOS)
import Foundation

extension FileBrowserSelectionSupport {
    static func selectedFileListRowID(
        isParentDirectorySelected: Bool,
        primarySelectedItemID: FileItem.ID?
    ) -> FileListRowID? {
        if isParentDirectorySelected {
            return .parentDirectory
        }

        guard let primarySelectedItemID else { return nil }
        return .item(primarySelectedItemID)
    }

    static func fileDragItems(
        item: FileItem,
        selectedItemIDs: Set<FileItem.ID>,
        selectedVisibleItems: [FileItem]
    ) -> [FileDragItem] {
        if selectedItemIDs.contains(item.id) {
            return selectedVisibleItems.map { item in
                FileDragItem(url: item.url, iconCacheKey: item.iconCacheKey)
            }
        }

        return [FileDragItem(url: item.url, iconCacheKey: item.iconCacheKey)]
    }

    static func clampedIndex(_ index: Int, count: Int) -> Int {
        min(max(index, 0), count - 1)
    }

    static func currentFileRowIndex(
        isParentDirectorySelected: Bool,
        primarySelectedItemID: FileItem.ID?,
        visibleItemIndexLookup: [FileItem.ID: Int],
        parentOffset: Int,
        rowCount: Int,
        delta: Int
    ) -> Int {
        if isParentDirectorySelected {
            return 0
        } else if let primarySelectedItemID,
                  let itemIndex = visibleItemIndexLookup[primarySelectedItemID.standardizedFileURL] {
            return parentOffset + itemIndex
        } else {
            return delta >= 0 ? -1 : rowCount
        }
    }
}
#endif
