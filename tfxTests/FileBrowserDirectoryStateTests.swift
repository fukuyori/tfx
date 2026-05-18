#if os(macOS)
import Foundation
import Testing
@testable import tfx

@Suite("FileBrowserDirectoryState")
struct FileBrowserDirectoryStateTests {
    private let directory = URL(fileURLWithPath: "/tmp/tfx-test").standardizedFileURL

    private func makeItem(_ name: String) -> FileItem {
        FileItem(url: directory.appendingPathComponent(name))
    }

    @Test
    func itemLookupKeysOnStandardizedURL() {
        let a = makeItem("a.txt")
        let b = makeItem("b.txt")

        let lookup = FileBrowserDirectoryState.itemLookup(for: [a, b])
        #expect(lookup[a.id.standardizedFileURL]?.url == a.url)
        #expect(lookup[b.id.standardizedFileURL]?.url == b.url)
    }

    @Test
    func visibleItemIndexLookupReflectsOrder() {
        let items = ["a", "b", "c"].map { makeItem("\($0).txt") }
        let lookup = FileBrowserDirectoryState.visibleItemIndexLookup(for: items)
        #expect(lookup[items[0].id.standardizedFileURL] == 0)
        #expect(lookup[items[1].id.standardizedFileURL] == 1)
        #expect(lookup[items[2].id.standardizedFileURL] == 2)
    }

    @Test
    func selectedItemsAreSortedByPath() {
        let a = makeItem("a.txt")
        let b = makeItem("b.txt")
        let c = makeItem("c.txt")
        let lookup = FileBrowserDirectoryState.itemLookup(for: [a, b, c])

        let result = FileBrowserDirectoryState.selectedItems(
            from: [c.id, a.id],
            lookup: lookup
        )

        let names = result.map(\.name)
        #expect(names == ["a.txt", "c.txt"])
    }

    @Test
    func selectedVisibleItemsRespectVisibilityAndOrder() {
        let items = ["a", "b", "c"].map { makeItem("\($0).txt") }
        let allLookup = FileBrowserDirectoryState.itemLookup(for: items)
        // Visible only includes the first two (a, b).
        let visibleLookup = FileBrowserDirectoryState.visibleItemIndexLookup(for: Array(items.prefix(2)))

        let result = FileBrowserDirectoryState.selectedVisibleItems(
            selectedItemIDs: [items[0].id, items[1].id, items[2].id],
            allItemLookup: allLookup,
            visibleItemIndexLookup: visibleLookup
        )

        let names = result.map(\.name)
        #expect(names == ["a.txt", "b.txt"])
    }

    @Test
    func previewURLsEmptyWhenParentSelected() {
        let a = makeItem("a.txt")
        let lookup = FileBrowserDirectoryState.itemLookup(for: [a])
        let result = FileBrowserDirectoryState.previewURLs(
            isParentDirectorySelected: true,
            selectedItemIDs: [a.id],
            allItemLookup: lookup
        )
        #expect(result.isEmpty)
    }

    @Test
    func previewURLsReturnSortedURLsForSelection() {
        let a = makeItem("a.txt")
        let b = makeItem("b.txt")
        let lookup = FileBrowserDirectoryState.itemLookup(for: [a, b])
        let result = FileBrowserDirectoryState.previewURLs(
            isParentDirectorySelected: false,
            selectedItemIDs: [b.id, a.id],
            allItemLookup: lookup
        )
        #expect(result.map(\.path) == [a.url.path, b.url.path])
    }
}
#endif
