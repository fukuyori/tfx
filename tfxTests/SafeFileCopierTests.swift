#if os(macOS)
import Foundation
import Testing
@testable import tfx

@Suite("SafeFileCopier")
struct SafeFileCopierTests {
    private func makeFixtureDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tfx-copier-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test
    func copiesDirectoryIntoItselfWithoutRecursing() throws {
        let root = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        // headline/
        //   a.txt
        //   sub/b.txt
        let source = root.appendingPathComponent("headline", isDirectory: true)
        try FileManager.default.createDirectory(
            at: source.appendingPathComponent("sub", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data("a".utf8).write(to: source.appendingPathComponent("a.txt"))
        try Data("b".utf8).write(to: source.appendingPathComponent("sub/b.txt"))

        // Finder-style paste of the folder into itself: destination
        // lives inside the source. Must produce exactly ONE nested
        // level, not recurse until PATH_MAX.
        let destination = source.appendingPathComponent("headline", isDirectory: true)
        try SafeFileCopier.copy(from: source, to: destination, progress: Progress())

        let copiedA = destination.appendingPathComponent("a.txt")
        let copiedB = destination.appendingPathComponent("sub/b.txt")
        #expect(FileManager.default.fileExists(atPath: copiedA.path))
        #expect(FileManager.default.fileExists(atPath: copiedB.path))
        #expect(try String(contentsOf: copiedA, encoding: .utf8) == "a")
        // No second nesting level: the snapshot must not have
        // picked up the half-written destination.
        let doubleNested = destination.appendingPathComponent("headline", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: doubleNested.path))
    }

    @Test
    func preservesSymbolicLinksAsLinks() throws {
        let root = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("payload".utf8).write(to: source.appendingPathComponent("real.txt"))
        try FileManager.default.createSymbolicLink(
            atPath: source.appendingPathComponent("link.txt").path,
            withDestinationPath: "real.txt"
        )

        let destination = root.appendingPathComponent("bundle-copy", isDirectory: true)
        try SafeFileCopier.copy(from: source, to: destination, progress: Progress())

        let copiedLinkPath = destination.appendingPathComponent("link.txt").path
        let linkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: copiedLinkPath)
        #expect(linkTarget == "real.txt")
    }

    @Test
    func refusesToOverwriteExistingDestinationFile() throws {
        let root = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source.txt")
        let destination = root.appendingPathComponent("destination.txt")
        try Data("new".utf8).write(to: source)
        try Data("precious".utf8).write(to: destination)

        // O_EXCL: a destination that appeared after planning must
        // surface an error, not silently truncate the existing file.
        #expect(throws: (any Error).self) {
            try SafeFileCopier.copy(from: source, to: destination, progress: Progress())
        }
        #expect(try String(contentsOf: destination, encoding: .utf8) == "precious")
    }
}
#endif
