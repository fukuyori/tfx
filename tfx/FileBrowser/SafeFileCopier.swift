#if os(macOS)
import Foundation

/// Errors that the safe copier can throw in addition to whatever
/// `FileManager` / `FileHandle` raises.
enum SafeFileCopierError: Error {
    /// Raised mid-copy when the `Progress` was cancelled. The
    /// partial destination file (if any) has been deleted.
    case cancelled
}

/// File-copy primitive used by long-running tfx file operations
/// (`paste`, `drop`). Built around three Foundation pieces:
///
///   - `Progress` for reporting byte-level progress, surfacing the
///     "currently copying" file URL to the system, and exposing a
///     standard `cancel()` channel that integrates with the Dock
///     progress badge AppKit shows for documents-style operations.
///   - `NSFileCoordinator` so concurrent writers (iCloud,
///     Spotlight, the user editing the source in another app) see
///     a coordinated read/write window instead of a half-copied
///     file.
///   - A chunked `FileHandle` loop so the operation is cancellable
///     in the middle of a large file (Finder shows the same
///     responsiveness) and leaves no half-written destination
///     behind if the user cancels.
enum SafeFileCopier {
    /// Roughly the buffer size GNU `cp` uses by default — small
    /// enough to react to a cancel within a few ms even on a fast
    /// SSD, large enough that the per-chunk syscall overhead is a
    /// non-issue on multi-GB transfers.
    private static let chunkSize = 1 << 20 // 1 MiB

    /// Sum the byte size of every regular file under `url`,
    /// resolving through enumeration if `url` is a directory. Used
    /// to seed `Progress.totalUnitCount` so the UI can render a
    /// meaningful percentage.
    static func totalSize(of url: URL) -> Int64 {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if !isDirectory {
            return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        var total: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: []
        ) else { return 0 }

        for case let item as URL in enumerator {
            let values = try? item.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == false {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    /// Copy `source` to `destination` reporting byte progress on
    /// `progress` and honoring cancellation. The caller is
    /// responsible for ensuring `destination` does not already
    /// exist (use `FileConflictResolver.uniqueDestination(...)`
    /// upstream).
    static func copy(
        from source: URL,
        to destination: URL,
        progress: Progress
    ) throws {
        let isDirectory = (try? source.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if isDirectory {
            try copyDirectory(from: source, to: destination, progress: progress)
        } else {
            try copyFile(from: source, to: destination, progress: progress)
        }
    }

    private static func copyDirectory(
        from source: URL,
        to destination: URL,
        progress: Progress
    ) throws {
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )

        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: source,
            includingPropertiesForKeys: keys,
            options: []
        ) else { return }

        let sourcePrefix = source.standardizedFileURL.path
        for case let item as URL in enumerator {
            if progress.isCancelled { throw SafeFileCopierError.cancelled }

            let standardized = item.standardizedFileURL.path
            // Compute the path relative to `source`, then graft
            // it onto `destination`.
            let relative = String(standardized.dropFirst(sourcePrefix.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let target = destination.appendingPathComponent(relative)

            let values = try item.resourceValues(forKeys: Set(keys))
            if values.isDirectory == true {
                try FileManager.default.createDirectory(
                    at: target,
                    withIntermediateDirectories: true
                )
            } else {
                try copyFile(from: item, to: target, progress: progress)
            }
        }
    }

    private static func copyFile(
        from source: URL,
        to destination: URL,
        progress: Progress
    ) throws {
        var coordinationError: NSError?
        var inner: Error?

        // `NSFileCoordinator` blocks until any other coordinated
        // writer on the same file finishes (iCloud sync, another
        // app editing the document, …) and surfaces an error
        // instead of corrupting the destination if it can't be
        // satisfied. Cheap when no contention is present.
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: source,
            options: .withoutChanges,
            writingItemAt: destination,
            options: .forReplacing,
            error: &coordinationError
        ) { readURL, writeURL in
            do {
                try chunkCopy(from: readURL, to: writeURL, progress: progress)
            } catch {
                inner = error
            }
        }
        if let err = coordinationError { throw err }
        if let err = inner { throw err }
    }

    private static func chunkCopy(
        from source: URL,
        to destination: URL,
        progress: Progress
    ) throws {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }

        // `createFile` succeeds even when the file already
        // exists — overwriting is fine because the coordinator
        // gave us an `.forReplacing` window.
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }

        while true {
            if progress.isCancelled {
                // Leave no half-written destination behind on
                // user cancel. Close both handles first so the
                // delete isn't racing an open writer.
                try? input.close()
                try? output.close()
                try? FileManager.default.removeItem(at: destination)
                throw SafeFileCopierError.cancelled
            }
            let data = input.readData(ofLength: chunkSize)
            if data.isEmpty { break }
            try output.write(contentsOf: data)
            progress.completedUnitCount += Int64(data.count)
        }
    }
}

#endif
