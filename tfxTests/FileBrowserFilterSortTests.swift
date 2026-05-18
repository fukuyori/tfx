#if os(macOS)
import Foundation
import Testing
@testable import tfx

/// Tests for `FileBrowserFilterSort`. Uses a temporary directory with real
/// files so `FileItem` properties (`isHidden`, `searchName`, `isDirectory`)
/// reflect the values the production code reads from disk.
@Suite("FileBrowserFilterSort")
struct FileBrowserFilterSortTests {
    private static func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tfx-filtersort-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func writeFile(_ name: String, in dir: URL) throws -> FileItem {
        let url = dir.appendingPathComponent(name)
        try Data().write(to: url)
        return FileItem(url: url)
    }

    private static func writeFolder(_ name: String, in dir: URL) throws -> FileItem {
        let url = dir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return FileItem(url: url)
    }

    @Test
    func emptyInputReturnsEmpty() {
        let result = FileBrowserFilterSort.filteredAndSortedItems(
            [],
            query: "",
            showsHiddenFiles: false,
            sortKey: .fastName,
            sortAscending: true,
            cancellation: FilterSortCancellation()
        )
        #expect(result == [])
    }

    @Test
    func cancellationReturnsNil() {
        let cancellation = FilterSortCancellation()
        cancellation.cancel()
        let result = FileBrowserFilterSort.filteredAndSortedItems(
            [],
            query: "",
            showsHiddenFiles: false,
            sortKey: .fastName,
            sortAscending: true,
            cancellation: cancellation
        )
        #expect(result == nil)
    }

    @Test
    func directoriesSortBeforeFiles() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = try Self.writeFile("alpha.txt", in: dir)
        let folder = try Self.writeFolder("beta", in: dir)

        let result = FileBrowserFilterSort.filteredAndSortedItems(
            [file, folder],
            query: "",
            showsHiddenFiles: false,
            sortKey: .fastName,
            sortAscending: true,
            cancellation: FilterSortCancellation()
        )

        let names = result?.map(\.name)
        #expect(names == ["beta", "alpha.txt"])
    }

    @Test
    func hiddenFilesAreFilteredWhenDisabled() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let visible = try Self.writeFile("visible.txt", in: dir)
        let hidden = try Self.writeFile(".hidden", in: dir)

        let result = FileBrowserFilterSort.filteredAndSortedItems(
            [visible, hidden],
            query: "",
            showsHiddenFiles: false,
            sortKey: .fastName,
            sortAscending: true,
            cancellation: FilterSortCancellation()
        )

        let names = result?.map(\.name)
        #expect(names == ["visible.txt"])
    }

    @Test
    func hiddenFilesAreShownWhenEnabled() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let visible = try Self.writeFile("visible.txt", in: dir)
        let hidden = try Self.writeFile(".hidden", in: dir)

        let result = FileBrowserFilterSort.filteredAndSortedItems(
            [visible, hidden],
            query: "",
            showsHiddenFiles: true,
            sortKey: .fastName,
            sortAscending: true,
            cancellation: FilterSortCancellation()
        )

        #expect(result?.count == 2)
    }

    @Test
    func searchQueryNarrowsResults() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let alpha = try Self.writeFile("alpha.txt", in: dir)
        let beta = try Self.writeFile("beta.txt", in: dir)

        let result = FileBrowserFilterSort.filteredAndSortedItems(
            [alpha, beta],
            query: "alp",
            showsHiddenFiles: false,
            sortKey: .fastName,
            sortAscending: true,
            cancellation: FilterSortCancellation()
        )

        #expect(result?.count == 1)
        #expect(result?.first?.name == "alpha.txt")
    }

    @Test
    func descendingSortReversesOrder() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let alpha = try Self.writeFile("alpha.txt", in: dir)
        let beta = try Self.writeFile("beta.txt", in: dir)

        let result = FileBrowserFilterSort.filteredAndSortedItems(
            [alpha, beta],
            query: "",
            showsHiddenFiles: false,
            sortKey: .fastName,
            sortAscending: false,
            cancellation: FilterSortCancellation()
        )

        let names = result?.map(\.name)
        #expect(names == ["beta.txt", "alpha.txt"])
    }
}
#endif
