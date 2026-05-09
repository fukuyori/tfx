#if os(macOS)
import AppKit
import Foundation

extension FileBrowserModel {
    func selectForMouseDown(_ item: FileItem, modifiers: NSEvent.ModifierFlags) {
        mouseRangeSelectionState = nil
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
        if mouseRangeSelectionState != nil {
            finishMouseRangeSelection()
            return
        }
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

    func beginMouseRangeSelection(from item: FileItem, modifiers: NSEvent.ModifierFlags) {
        isParentDirectorySelected = false
        let addsToExistingSelection = modifiers.contains(.command)
        mouseRangeSelectionState = FileMouseRangeSelectionState(
            anchorItemID: item.id,
            originalSelectedItemIDs: selectedItemIDs,
            addsToExistingSelection: addsToExistingSelection
        )
        updateMouseRangeSelection(to: item)
    }

    func updateMouseRangeSelection(to item: FileItem) {
        guard
            let state = mouseRangeSelectionState,
            let anchorIndex = visibleItemIndexLookup[state.anchorItemID.standardizedFileURL],
            let targetIndex = visibleItemIndexLookup[item.id.standardizedFileURL]
        else {
            return
        }

        let range = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        var selectedIDs = Set(items[range].map(\.id))
        if state.addsToExistingSelection {
            selectedIDs.formUnion(state.originalSelectedItemIDs)
        }

        selectedItemIDs = selectedIDs
        primarySelectedItemID = item.id
        selectionAnchorItemID = state.anchorItemID
        isParentDirectorySelected = false
    }

    func beginMouseRangeSelection(atItemIndex itemIndex: Int, modifiers: NSEvent.ModifierFlags) {
        guard items.indices.contains(itemIndex) else { return }
        beginMouseRangeSelection(from: items[itemIndex], modifiers: modifiers)
    }

    func updateMouseRangeSelection(toItemIndex itemIndex: Int) {
        guard items.indices.contains(itemIndex) else { return }
        updateMouseRangeSelection(to: items[itemIndex])
    }

    func updateMouseRangeSelection(startingAt item: FileItem, verticalOffset: CGFloat, rowHeight: CGFloat) {
        guard rowHeight > 0, let startIndex = visibleItemIndexLookup[item.id.standardizedFileURL] else { return }

        let rowOffset = Int(round(-verticalOffset / rowHeight))
        let targetIndex = FileBrowserSelectionSupport.clampedIndex(startIndex + rowOffset, count: items.count)
        updateMouseRangeSelection(to: items[targetIndex])
    }

    func finishMouseRangeSelection() {
        mouseRangeSelectionState = nil
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
