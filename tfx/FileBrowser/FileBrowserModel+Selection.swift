#if os(macOS)
import AppKit
import Foundation

extension FileBrowserModel {
    func selectForMouseDown(_ item: FileItem, modifiers: NSEvent.ModifierFlags) {
        isParentDirectorySelected = false

        if modifiers.contains(.shift) {
            selectRange(to: item)
        } else if modifiers.contains(.command) {
            select(item, extending: true)
        } else if !selectedItemIDs.contains(item.id) {
            select(item)
        } else {
            primarySelectedItemID = item.id
        }
    }

    func selectForMouseUp(_ item: FileItem, modifiers: NSEvent.ModifierFlags) {
        guard !modifiers.contains(.shift), !modifiers.contains(.command) else { return }
        select(item)
    }

    func dragItemsForFileRow(_ item: FileItem) -> [FileDragItem] {
        if !selectedItemIDs.contains(item.id) {
            select(item)
        }

        return FileBrowserSelectionSupport.fileDragItems(
            item: item,
            selectedItemIDs: selectedItemIDs,
            selectedVisibleItems: selectedVisibleItems
        )
    }

    func moveFileSelection(delta: Int, extendingRange: Bool = false) {
        let parentOffset = canGoUp ? 1 : 0
        let rowCount = parentOffset + items.count
        guard rowCount > 0 else { return }

        let currentIndex = FileBrowserSelectionSupport.currentFileRowIndex(
            isParentDirectorySelected: isParentDirectorySelected,
            primarySelectedItemID: primarySelectedItemID,
            visibleItemIndexLookup: visibleItemIndexLookup,
            parentOffset: parentOffset,
            rowCount: rowCount,
            delta: delta
        )

        let nextIndex = FileBrowserSelectionSupport.clampedIndex(currentIndex + delta, count: rowCount)
        if extendingRange {
            selectRange(toRow: nextIndex, fallbackCurrentRow: currentIndex)
            return
        }

        if canGoUp, nextIndex == 0 {
            selectParentDirectory()
        } else {
            select(items[nextIndex - parentOffset])
        }
    }

    func selectRange(to item: FileItem) {
        guard let itemIndex = visibleItemIndexLookup[item.id.standardizedFileURL] else {
            return
        }

        selectRange(toRow: (canGoUp ? 1 : 0) + itemIndex, fallbackCurrentRow: nil)
    }

    func activateFileSelection() {
        if isParentDirectorySelected {
            goUp()
            return
        }

        if let primarySelectedItem {
            open(primarySelectedItem)
        } else if let firstItem = items.first {
            select(firstItem)
            open(firstItem)
        }
    }

    private func selectRange(toRow targetRow: Int, fallbackCurrentRow: Int?) {
        guard let result = FileBrowserSelectionSupport.rangeSelection(
            items: items,
            visibleItemIndexLookup: visibleItemIndexLookup,
            existingAnchorID: selectionAnchorItemID,
            primarySelectedItemID: primarySelectedItemID,
            targetRow: targetRow,
            fallbackCurrentRow: fallbackCurrentRow,
            parentOffset: canGoUp ? 1 : 0
        ) else { return }

        selectionAnchorItemID = result.anchorItemID
        selectedItemIDs = result.selectedItemIDs
        primarySelectedItemID = result.primarySelectedItemID
        isParentDirectorySelected = false
    }
}

#endif
