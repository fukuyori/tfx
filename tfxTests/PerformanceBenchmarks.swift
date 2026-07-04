#if os(macOS)
import Foundation
import Testing
@testable import tfx

/// Informational performance benchmarks for the §3.1 targets in
/// `docs/development-roadmap.md`. Timings are printed to test output and
/// **not** asserted, because CI hardware varies. Inspect them manually or
/// against rolling baselines on the same machine.
///
/// To run only this suite locally:
///
/// ```sh
/// xcodebuild test \
///     -scheme tfx \
///     -destination 'platform=macOS' \
///     -only-testing:tfxTests/PerformanceBenchmarks \
///     CODE_SIGNING_ALLOWED=NO
/// ```
@Suite("PerformanceBenchmarks")
struct PerformanceBenchmarks {
    private static let clock = ContinuousClock()

    private static func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tfx-bench-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func populate(_ dir: URL, count: Int) throws {
        for i in 0..<count {
            let url = dir.appendingPathComponent("file-\(i).txt")
            try Data().write(to: url)
        }
    }

    private static func report(_ label: String, _ elapsed: Duration) {
        let milliseconds = Double(elapsed.components.seconds) * 1_000
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
        print(String(format: "[bench] %@: %.1f ms", label, milliseconds))
    }

    // MARK: - Directory loading

    @Test
    func fileItemCreation1k() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Self.populate(dir, count: 1_000)

        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )

        let elapsed = Self.clock.measure {
            for url in urls {
                _ = FileItem(url: url)
            }
        }
        Self.report("FileItem ×1000", elapsed)
    }

    @Test
    func fileItemCreation5k() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Self.populate(dir, count: 5_000)

        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )

        let elapsed = Self.clock.measure {
            for url in urls {
                _ = FileItem(url: url)
            }
        }
        Self.report("FileItem ×5000", elapsed)
    }

    @Test
    func directoryReaderLoadHeader1k() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Self.populate(dir, count: 1_000)

        let elapsed = Self.clock.measure {
            _ = FileBrowserDirectoryReader.loadHeader(for: dir)
        }
        Self.report("loadHeader 1k items", elapsed)
    }

    // MARK: - Filtering and sorting

    @Test
    func filterAndSort1k() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Self.populate(dir, count: 1_000)

        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )
        let items = urls.map(FileItem.init)

        let elapsed = Self.clock.measure {
            _ = FileBrowserFilterSort.filteredAndSortedItems(
                items,
                query: "",
                showsHiddenFiles: false,
                sortKey: .fastName,
                sortAscending: true,
                cancellation: FilterSortCancellation()
            )
        }
        Self.report("filterAndSort 1k items", elapsed)
    }

    @Test
    func filterAndSortWithQuery1k() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Self.populate(dir, count: 1_000)

        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )
        let items = urls.map(FileItem.init)

        let elapsed = Self.clock.measure {
            _ = FileBrowserFilterSort.filteredAndSortedItems(
                items,
                query: "5",
                showsHiddenFiles: false,
                sortKey: .fastName,
                sortAscending: true,
                cancellation: FilterSortCancellation()
            )
        }
        Self.report("filterAndSort 1k items + query", elapsed)
    }

    // MARK: - Large-directory hot paths (10k+)
    //
    // These cover the paths the 2026-07 performance audit flagged:
    // chunked-batch lookup accumulation, `.name` (natural order)
    // sorting, and large CSV parsing. Synthetic items avoid disk
    // I/O so the timings isolate the in-memory work.

    private static func syntheticItems(count: Int, in dir: URL) -> [FileItem] {
        (0..<count).map { index in
            FileItem(url: dir.appendingPathComponent("file-\(index).txt"))
        }
    }

    @Test
    func batchLookupAccumulation10k() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // FileItem construction tolerates missing files; only the
        // dictionary work is measured below.
        let items = Self.syntheticItems(count: 10_000, in: dir)
        let chunkSize = 300

        // Mirrors `appendLoadedDirectoryItems`: incremental
        // insertion per arriving chunk. The pre-0.9.3 behavior
        // (full `itemLookup(for:)` rebuild per chunk) is measured
        // alongside for comparison in the log.
        var incrementalLookup: [FileItem.ID: FileItem] = [:]
        let incremental = Self.clock.measure {
            for chunkStart in stride(from: 0, to: items.count, by: chunkSize) {
                let chunk = items[chunkStart..<min(chunkStart + chunkSize, items.count)]
                for item in chunk {
                    incrementalLookup[item.id] = item
                }
            }
        }
        Self.report("lookup accumulation 10k (incremental)", incremental)

        var accumulated: [FileItem] = []
        let rebuild = Self.clock.measure {
            for chunkStart in stride(from: 0, to: items.count, by: chunkSize) {
                let chunk = items[chunkStart..<min(chunkStart + chunkSize, items.count)]
                accumulated.append(contentsOf: chunk)
                _ = FileBrowserDirectoryState.itemLookup(for: accumulated)
            }
        }
        Self.report("lookup accumulation 10k (full rebuild, old behavior)", rebuild)
        #expect(incrementalLookup.count == accumulated.count)
    }

    @Test
    func naturalNameSort10k() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let items = Self.syntheticItems(count: 10_000, in: dir)

        let elapsed = Self.clock.measure {
            _ = FileBrowserFilterSort.filteredAndSortedItems(
                items,
                query: "",
                showsHiddenFiles: false,
                sortKey: .name,
                sortAscending: true,
                cancellation: FilterSortCancellation()
            )
        }
        Self.report("filterAndSort 10k items (.name natural order)", elapsed)
    }

    @Test
    func csvParse100kRows() {
        let row = "alpha,beta,\"quoted, cell\",delta,42\n"
        let text = String(repeating: row, count: 100_000)

        let full = Self.clock.measure {
            _ = CSVParser.parse(text, delimiter: ",")
        }
        Self.report("CSVParser 100k rows (full)", full)

        let capped = Self.clock.measure {
            _ = CSVParser.parse(text, delimiter: ",", maxRows: 1_001)
        }
        Self.report("CSVParser 100k rows (capped at 1,001)", capped)
    }
}
#endif
