#if os(macOS)
import Foundation
import Testing
@testable import tfx

@Suite("FileBrowserSelectionSupport")
struct FileBrowserSelectionSupportTests {
    private let a = URL(fileURLWithPath: "/tmp/tfx-test/a").standardizedFileURL
    private let b = URL(fileURLWithPath: "/tmp/tfx-test/b").standardizedFileURL
    private let c = URL(fileURLWithPath: "/tmp/tfx-test/c").standardizedFileURL

    @Test
    func nonExtendingSelectionReplaces() {
        let result = FileBrowserSelectionSupport.itemSelection(
            itemID: a,
            extending: false,
            selectedItemIDs: [b, c],
            primarySelectedItemID: b,
            selectionAnchorItemID: b
        )
        #expect(result.selectedItemIDs == [a])
        #expect(result.primarySelectedItemID == a)
        #expect(result.selectionAnchorItemID == a)
        #expect(!result.isParentDirectorySelected)
    }

    @Test
    func extendingSelectionAddsNewItem() {
        let result = FileBrowserSelectionSupport.itemSelection(
            itemID: c,
            extending: true,
            selectedItemIDs: [a, b],
            primarySelectedItemID: b,
            selectionAnchorItemID: a
        )
        #expect(result.selectedItemIDs == [a, b, c])
        #expect(result.primarySelectedItemID == c)
        #expect(result.selectionAnchorItemID == a)
    }

    @Test
    func extendingSelectionTogglesExistingItem() {
        let result = FileBrowserSelectionSupport.itemSelection(
            itemID: b,
            extending: true,
            selectedItemIDs: [a, b],
            primarySelectedItemID: b,
            selectionAnchorItemID: a
        )
        #expect(result.selectedItemIDs == [a])
        // Removed b was primary; primary falls back to remaining item.
        #expect(result.primarySelectedItemID == a)
    }

    @Test
    func extendingSelectionFromEmptyStartsAnchor() {
        let result = FileBrowserSelectionSupport.itemSelection(
            itemID: a,
            extending: true,
            selectedItemIDs: [],
            primarySelectedItemID: nil,
            selectionAnchorItemID: nil
        )
        #expect(result.selectedItemIDs == [a])
        #expect(result.selectionAnchorItemID == a)
    }

    @Test
    func contextMenuKeepsMultiSelectionWhenTargetInside() {
        let result = FileBrowserSelectionSupport.contextMenuSelection(
            itemID: b,
            selectedItemIDs: [a, b, c]
        )
        #expect(result.selectedItemIDs == [a, b, c])
        #expect(result.primarySelectedItemID == b)
        #expect(result.selectionAnchorItemID == b)
    }

    @Test
    func contextMenuNarrowsToTargetWhenOutsideSelection() {
        let result = FileBrowserSelectionSupport.contextMenuSelection(
            itemID: a,
            selectedItemIDs: [b, c]
        )
        #expect(result.selectedItemIDs == [a])
        #expect(result.primarySelectedItemID == a)
    }

    @Test
    func parentDirectorySelectionClearsItems() {
        let result = FileBrowserSelectionSupport.parentDirectorySelection()
        #expect(result.selectedItemIDs.isEmpty)
        #expect(result.primarySelectedItemID == nil)
        #expect(result.isParentDirectorySelected)
    }

    @Test
    func prunedSelectionDropsInvisibleItems() {
        let result = FileBrowserSelectionSupport.prunedSelection(
            selectedItemIDs: [a, b, c],
            primarySelectedItemID: b,
            selectionAnchorItemID: a,
            isParentDirectorySelected: false,
            canGoUp: true,
            visibleItemIndexLookup: [a: 0, c: 1]
        )
        #expect(result.selectedItemIDs == [a, c])
        // Primary `b` no longer visible — falls back to one of the visible items.
        if let primary = result.primarySelectedItemID {
            #expect(result.selectedItemIDs.contains(primary))
        } else {
            Issue.record("Expected a fallback primary selection")
        }
    }

    @Test
    func prunedSelectionKeepsPrimaryWhenStillVisible() {
        let result = FileBrowserSelectionSupport.prunedSelection(
            selectedItemIDs: [a, b],
            primarySelectedItemID: a,
            selectionAnchorItemID: a,
            isParentDirectorySelected: false,
            canGoUp: true,
            visibleItemIndexLookup: [a: 0, b: 1]
        )
        #expect(result.primarySelectedItemID == a)
        #expect(result.selectionAnchorItemID == a)
    }

    @Test
    func prunedSelectionClearsParentWhenCannotGoUp() {
        let result = FileBrowserSelectionSupport.prunedSelection(
            selectedItemIDs: [],
            primarySelectedItemID: nil,
            selectionAnchorItemID: nil,
            isParentDirectorySelected: true,
            canGoUp: false,
            visibleItemIndexLookup: [:]
        )
        #expect(!result.isParentDirectorySelected)
    }
}
#endif
