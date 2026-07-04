#if os(macOS)
import Darwin
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
        let rootValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        // Symlinks are recreated as links (no payload bytes) and
        // never followed, so they contribute nothing to the total.
        if rootValues?.isSymbolicLink == true { return 0 }
        if rootValues?.isDirectory != true {
            return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        var total: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: []
        ) else { return 0 }

        for case let item as URL in enumerator {
            let values = try? item.resourceValues(forKeys: Set(keys))
            if values?.isSymbolicLink == true { continue }
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
        let values = try? source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        // Recreate symlinks as symlinks. `.isDirectoryKey`
        // resolves through the link, so without this check a
        // link-to-directory becomes an empty real directory and a
        // link-to-file becomes a full copy of its target —
        // silently breaking bundles (`Foo.framework/Versions/
        // Current`) and, on a move, destroying the link forever.
        if values?.isSymbolicLink == true {
            try copySymbolicLink(from: source, to: destination)
            return
        }
        if values?.isDirectory == true {
            try copyDirectory(from: source, to: destination, progress: progress)
        } else {
            try copyFile(from: source, to: destination, progress: progress)
        }
    }

    private static func copySymbolicLink(from source: URL, to destination: URL) throws {
        let target = try FileManager.default.destinationOfSymbolicLink(atPath: source.path)
        try FileManager.default.createSymbolicLink(atPath: destination.path, withDestinationPath: target)
    }

    private static func copyDirectory(
        from source: URL,
        to destination: URL,
        progress: Progress
    ) throws {
        // Snapshot the source tree BEFORE creating the
        // destination. Copying a folder into itself (a
        // Finder-legal gesture that produces a nested copy) would
        // otherwise let the live enumerator descend into the
        // half-written destination and recurse until PATH_MAX.
        // The destination-prefix check also drops entries another
        // writer sneaks under the destination mid-walk.
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        let destinationPath = destination.standardizedFileURL.path
        var entries: [(url: URL, isDirectory: Bool, isSymbolicLink: Bool)] = []
        if let enumerator = FileManager.default.enumerator(
            at: source,
            includingPropertiesForKeys: keys,
            options: []
        ) {
            for case let item as URL in enumerator {
                if progress.isCancelled { throw SafeFileCopierError.cancelled }
                let standardized = item.standardizedFileURL.path
                if standardized == destinationPath || standardized.hasPrefix(destinationPath + "/") {
                    continue
                }
                let values = try item.resourceValues(forKeys: Set(keys))
                entries.append((
                    url: item,
                    isDirectory: values.isDirectory == true && values.isSymbolicLink != true,
                    isSymbolicLink: values.isSymbolicLink == true
                ))
            }
        }

        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )

        let sourcePrefix = source.standardizedFileURL.path
        for entry in entries {
            if progress.isCancelled { throw SafeFileCopierError.cancelled }

            let standardized = entry.url.standardizedFileURL.path
            // Compute the path relative to `source`, then graft
            // it onto `destination`.
            let relative = String(standardized.dropFirst(sourcePrefix.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let target = destination.appendingPathComponent(relative)

            if entry.isSymbolicLink {
                try copySymbolicLink(from: entry.url, to: target)
            } else if entry.isDirectory {
                try FileManager.default.createDirectory(
                    at: target,
                    withIntermediateDirectories: true
                )
            } else {
                try copyFile(from: entry.url, to: target, progress: progress)
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
        // FIFOs, sockets and device nodes cannot be chunk-copied:
        // reading a FIFO with no writer blocks forever, hanging
        // the whole operation with no way to cancel. Skip them
        // (Finder refuses them too).
        let sourceValues = try? source.resourceValues(forKeys: [.isRegularFileKey])
        guard sourceValues?.isRegularFile == true else { return }

        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }

        // `O_EXCL` makes creation fail if the destination already
        // exists instead of truncating it. Upstream planning
        // guarantees a unique (or explicitly replace-via-temp)
        // destination, so an existing file here means something
        // else claimed the name after planning — surfacing an
        // error beats silently destroying it.
        let fd = Darwin.open(destination.path, O_WRONLY | O_CREAT | O_EXCL, 0o644)
        guard fd >= 0 else {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errno),
                userInfo: [NSFilePathErrorKey: destination.path]
            )
        }
        let output = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
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

        // Close explicitly on the success path so a deferred
        // flush error (network volumes often report I/O failures
        // only at close time) fails the copy instead of being
        // swallowed by the `try?` in the defer — a move would
        // otherwise delete the source of a corrupt copy.
        try output.close()
    }
}

#endif
