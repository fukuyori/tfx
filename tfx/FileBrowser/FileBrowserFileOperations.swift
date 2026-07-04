#if os(macOS)
import Foundation

struct FileOperationChange {
    let originModelID: UUID
    let affectedDirectories: Set<URL>
    /// URLs that were removed from their parent directory by
    /// this operation (the source side of a move / a trashed
    /// file, etc.). Other panes pointed at the same parent use
    /// this to drop those rows from their item list immediately
    /// instead of waiting ~250 ms for the directory watcher to
    /// fire a full reload.
    let removedURLs: Set<URL>
}

enum FileOperationNotifier {
    static func notifyDirectoriesChanged(
        _ directories: [URL],
        removedURLs: [URL] = [],
        originModelID: UUID
    ) {
        let affectedDirectories = Set(directories.map(\.standardizedFileURL))
        guard !affectedDirectories.isEmpty else { return }
        let removed = Set(removedURLs.map(\.standardizedFileURL))

        NotificationCenter.default.post(
            name: .fileManagerDirectoriesDidChange,
            object: FileOperationChange(
                originModelID: originModelID,
                affectedDirectories: affectedDirectories,
                removedURLs: removed
            )
        )
    }
}

extension Notification.Name {
    static let pinnedFoldersDidChange = Notification.Name("TerminalFileManager.pinnedFoldersDidChange")
    static let fileManagerDirectoriesDidChange = Notification.Name("TerminalFileManager.directoriesDidChange")
}

struct FilePasteResult {
    let pastedURLs: [URL]
    let removedURLs: [URL]
    let affectedDirectories: Set<URL>
    let shouldClearClipboard: Bool
}

struct FilePasteOperationPlan {
    let requests: [FileOperationRequest]
    let affectedDirectories: Set<URL>
    let shouldClearClipboard: Bool
}

struct FileCreateFolderResult {
    let folderURL: URL
    let affectedDirectory: URL
}

struct FileCreateFileResult {
    let fileURL: URL
    let affectedDirectory: URL
}

struct FileRenameResult {
    let sourceURL: URL
    let destinationURL: URL
    let affectedDirectory: URL
}

struct FileTrashResult {
    let removedURLs: [URL]
    let affectedDirectories: Set<URL>
}

struct FileArchiveCreateResult {
    let archiveURL: URL
    let affectedDirectory: URL
}

struct FileArchiveExtractResult {
    let extractedURL: URL
    let affectedDirectory: URL
}

enum FileArchiveOperationError: LocalizedError {
    case noItems
    case unsupportedArchiveEntry
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .noItems:
            return String(localized: "No items selected.")
        case .unsupportedArchiveEntry:
            return String(localized: "Compressing items inside zip archives is not supported.")
        case let .commandFailed(message):
            return message.isEmpty ? String(localized: "Archive command failed.") : message
        }
    }
}

enum FileBrowserFileOperations {
    static func createFolder(in directory: URL) throws -> FileCreateFolderResult? {
        guard let name = FileOperationPrompt.text(
            title: String(localized: "New Folder"),
            message: String(localized: "Enter a folder name."),
            defaultValue: DefaultPlaceholderNames.untitledFolderName()
        ) else {
            return nil
        }

        return try createFolder(named: name, in: directory)
    }

    static func createFolder(named name: String, in directory: URL) throws -> FileCreateFolderResult? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let folderURL = FileConflictResolver.uniqueDestination(for: trimmed, in: directory)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        return FileCreateFolderResult(folderURL: folderURL, affectedDirectory: directory.standardizedFileURL)
    }

    static func createFile(in directory: URL) throws -> FileCreateFileResult? {
        guard let name = FileOperationPrompt.text(
            title: String(localized: "New File"),
            message: String(localized: "Enter a file name."),
            defaultValue: DefaultPlaceholderNames.untitledFileName()
        ) else {
            return nil
        }

        return try createFile(named: name, in: directory)
    }

    static func createFile(named name: String, in directory: URL) throws -> FileCreateFileResult? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let fileURL = FileConflictResolver.uniqueDestination(for: trimmed, in: directory)
        guard FileManager.default.createFile(atPath: fileURL.path, contents: Data()) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileCreateFileResult(fileURL: fileURL, affectedDirectory: directory.standardizedFileURL)
    }

    static func rename(_ item: FileItem) throws -> FileRenameResult? {
        guard let name = FileOperationPrompt.text(
            title: String(localized: "Rename"),
            message: String(localized: "Enter a new name."),
            defaultValue: item.name
        ) else {
            return nil
        }

        return try rename(item, to: name)
    }

    static func rename(_ item: FileItem, to name: String) throws -> FileRenameResult? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return nil }

        let affectedDirectory = item.url.deletingLastPathComponent()
        // Case-only renames (`foo` → `Foo`) need special care on
        // the default case-insensitive APFS volume: the naive
        // `fileExists` probe inside `uniqueDestination` matches
        // the item itself, so the rename silently landed on
        // "Foo 2". When the "occupied" destination is the very
        // file being renamed, use it directly — a same-directory
        // `moveItem` performs the case change fine.
        let directCandidate = affectedDirectory.appendingPathComponent(trimmed)
        let destination: URL
        if let candidateID = (try? directCandidate.resourceValues(forKeys: [.fileResourceIdentifierKey]))?.fileResourceIdentifier,
           let sourceID = (try? item.url.resourceValues(forKeys: [.fileResourceIdentifierKey]))?.fileResourceIdentifier,
           candidateID.isEqual(sourceID) {
            destination = directCandidate
        } else {
            destination = FileConflictResolver.uniqueDestination(for: trimmed, in: affectedDirectory)
        }
        try FileManager.default.moveItem(at: item.url, to: destination)
        return FileRenameResult(
            sourceURL: item.url,
            destinationURL: destination,
            affectedDirectory: affectedDirectory.standardizedFileURL
        )
    }

    static func moveToTrash(_ items: [FileItem]) throws -> FileTrashResult? {
        guard !items.isEmpty else { return nil }

        var removedURLs: [URL] = []
        var affectedDirectories = Set<URL>()

        for item in items {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultingURL)
            removedURLs.append(item.url)
            affectedDirectories.insert(item.url.deletingLastPathComponent().standardizedFileURL)
        }

        return FileTrashResult(removedURLs: removedURLs, affectedDirectories: affectedDirectories)
    }

    static func createZipArchive(from items: [FileItem], in directory: URL) throws -> FileArchiveCreateResult? {
        guard !items.isEmpty else {
            throw FileArchiveOperationError.noItems
        }
        guard !items.contains(where: { ZipArchiveBrowser.canCopyFromArchive($0.url) }) else {
            throw FileArchiveOperationError.unsupportedArchiveEntry
        }

        let archiveName = zipArchiveName(for: items)
        let archiveURL = FileConflictResolver.uniqueDestination(for: archiveName, in: directory)
        if items.count == 1, let item = items.first {
            try runArchiveCommand(
                arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", item.url.lastPathComponent, archiveURL.path],
                currentDirectory: directory.standardizedFileURL
            )
        } else {
            let stagingDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("tfx-archive-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: false)
            defer {
                try? FileManager.default.removeItem(at: stagingDirectory)
            }

            for item in items {
                let destinationURL = FileConflictResolver.uniqueDestination(for: item.url.lastPathComponent, in: stagingDirectory)
                try FileManager.default.copyItem(at: item.url, to: destinationURL)
            }

            try runArchiveCommand(
                arguments: ["-c", "-k", "--sequesterRsrc", stagingDirectory.path, archiveURL.path],
                currentDirectory: nil
            )
        }

        return FileArchiveCreateResult(
            archiveURL: archiveURL,
            affectedDirectory: directory.standardizedFileURL
        )
    }

    static func extractZipArchive(_ archiveURL: URL, into directory: URL) throws -> FileArchiveExtractResult? {
        let baseName = (archiveURL.lastPathComponent as NSString).deletingPathExtension
        let destinationName = baseName.isEmpty ? "Archive" : baseName
        let destinationURL = FileConflictResolver.uniqueDestination(for: destinationName, in: directory)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: false)

        do {
            try runArchiveCommand(arguments: ["-x", "-k", archiveURL.path, destinationURL.path], currentDirectory: nil)
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }

        return FileArchiveExtractResult(
            extractedURL: destinationURL,
            affectedDirectory: directory.standardizedFileURL
        )
    }

    static func paste(_ clipboard: FileClipboard, into targetDirectory: URL) throws -> FilePasteResult? {
        guard ZipArchiveBrowser.location(for: targetDirectory) == nil else {
            throw ZipArchiveBrowserError.unsupportedWrite
        }

        var pastedURLs: [URL] = []
        var removedURLs: [URL] = []
        var affectedDirectories = Set<URL>()
        var batchConflictResolution: ConflictResolution?

        for sourceURL in clipboard.urls {
            if ZipArchiveBrowser.canCopyFromArchive(sourceURL) {
                let copiedURLs = try ZipArchiveBrowser.copyVirtualItem(sourceURL, into: targetDirectory)
                pastedURLs.append(contentsOf: copiedURLs)
                affectedDirectories.insert(targetDirectory.standardizedFileURL)
                continue
            }

            // Enter the security scope for the source URL before any
            // file-system operation. This is what makes the call work
            // against FileProvider-backed paths (Dropbox smart-sync,
            // iCloud Drive, OneDrive, etc.): the system materializes
            // the cloud placeholder into a real file on first access
            // and only honors that request inside an active scope.
            // The drop path already does this; paste was missing it,
            // which is why copy → paste failed for Dropbox files even
            // though drag-and-drop succeeded on the same items.
            let scoped = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let decision = FileConflictResolver.destinationDecision(
                for: sourceURL,
                in: targetDirectory,
                operation: clipboard.operation,
                batchResolution: &batchConflictResolution
            )

            switch decision {
            case .cancel:
                return nil
            case .skip:
                continue
            case let .use(destinationURL, shouldReplace):
                try transferItem(
                    from: sourceURL,
                    to: destinationURL,
                    operation: clipboard.operation,
                    replacingExisting: shouldReplace
                )
                if clipboard.operation == .move {
                    removedURLs.append(sourceURL)
                    affectedDirectories.insert(sourceURL.deletingLastPathComponent().standardizedFileURL)
                }

                pastedURLs.append(destinationURL)
                affectedDirectories.insert(destinationURL.deletingLastPathComponent().standardizedFileURL)
            }
        }

        return FilePasteResult(
            pastedURLs: pastedURLs,
            removedURLs: removedURLs,
            affectedDirectories: affectedDirectories,
            shouldClearClipboard: clipboard.operation == .move
        )
    }

    static func pasteOperationPlan(_ clipboard: FileClipboard, into targetDirectory: URL) throws -> FilePasteOperationPlan? {
        guard ZipArchiveBrowser.location(for: targetDirectory) == nil else {
            throw ZipArchiveBrowserError.unsupportedWrite
        }

        var requests: [FileOperationRequest] = []
        var affectedDirectories: Set<URL> = [targetDirectory.standardizedFileURL]
        var batchConflictResolution: ConflictResolution?
        var claimedDestinations = Set<String>()

        for sourceURL in clipboard.urls {
            let decision = FileConflictResolver.destinationDecision(
                for: sourceURL,
                in: targetDirectory,
                operation: clipboard.operation,
                batchResolution: &batchConflictResolution,
                claimedDestinations: &claimedDestinations
            )

            switch decision {
            case .cancel:
                return nil
            case .skip:
                continue
            case let .use(destinationURL, shouldReplace):
                requests.append(
                    FileOperationRequest(
                        sourceURL: sourceURL,
                        destinationURL: destinationURL,
                        shouldReplaceDestination: shouldReplace
                    )
                )

                if clipboard.operation == .move {
                    affectedDirectories.insert(sourceURL.deletingLastPathComponent().standardizedFileURL)
                }
            }
        }

        guard !requests.isEmpty else { return nil }

        return FilePasteOperationPlan(
            requests: requests,
            affectedDirectories: affectedDirectories,
            shouldClearClipboard: clipboard.operation == .move
        )
    }

    static func drop(_ sourceURL: URL, to targetDirectory: URL, operation: FileClipboard.Operation) throws -> FileDropOperationResult? {
        let decision = FileConflictResolver.destinationDecision(for: sourceURL, in: targetDirectory, operation: operation)

        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationURL: URL

        switch decision {
        case .cancel, .skip:
            return nil
        case let .use(resolvedDestinationURL, shouldReplace):
            destinationURL = resolvedDestinationURL
            try transferItem(
                from: sourceURL,
                to: destinationURL,
                operation: operation,
                replacingExisting: shouldReplace
            )
        }

        var affectedDirectories: Set<URL> = [targetDirectory.standardizedFileURL]
        if operation == .move {
            affectedDirectories.insert(sourceURL.deletingLastPathComponent().standardizedFileURL)
        }

        return FileDropOperationResult(
            destinationURL: destinationURL,
            removedSourceURL: operation == .move ? sourceURL : nil,
            affectedDirectories: affectedDirectories
        )
    }

    /// Copy or move `sourceURL` to `destinationURL`. When
    /// `replacingExisting` is true, the existing destination is
    /// never deleted before the new content has fully arrived:
    /// the item is first transferred to a hidden sibling temp
    /// name and then swapped in atomically with
    /// `replaceItemAt(_:withItemAt:)`. A failure mid-transfer
    /// (disk full, unreadable cloud placeholder, …) leaves the
    /// old destination untouched instead of destroying both the
    /// old and the new version.
    /// `FileManager.copyItem` recurses forever when the
    /// destination lives inside the source (it descends into the
    /// half-written copy, nesting `a/a/a/…` until PATH_MAX).
    /// Finder supports that gesture — pasting a folder into
    /// itself yields a nested copy — so route it through
    /// `SafeFileCopier`, which snapshots the source listing
    /// before writing.
    private static func copyItemSafely(from sourceURL: URL, to destinationURL: URL) throws {
        let sourcePath = sourceURL.resolvingSymlinksInPath().path
        let destinationPath = destinationURL.resolvingSymlinksInPath().path
        if destinationPath == sourcePath || destinationPath.hasPrefix(sourcePath + "/") {
            try SafeFileCopier.copy(from: sourceURL, to: destinationURL, progress: Progress())
        } else {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }
    }

    /// True when both URLs sit on the same volume, i.e.
    /// `FileManager.moveItem` will be an atomic `rename(2)` that
    /// keeps permissions, xattrs, Finder tags, and dates intact.
    /// `destinationURL` may not exist yet — its parent decides.
    static func urlsShareVolume(_ sourceURL: URL, _ destinationURL: URL) -> Bool {
        let sourceVolume = (try? sourceURL.resourceValues(
            forKeys: [.volumeIdentifierKey]
        ))?.volumeIdentifier
        let destinationVolume = (try? destinationURL.deletingLastPathComponent().resourceValues(
            forKeys: [.volumeIdentifierKey]
        ))?.volumeIdentifier
        guard let sourceVolume, let destinationVolume else { return false }
        return sourceVolume.isEqual(destinationVolume)
    }

    static func transferItem(
        from sourceURL: URL,
        to destinationURL: URL,
        operation: FileClipboard.Operation,
        replacingExisting: Bool
    ) throws {
        guard replacingExisting else {
            switch operation {
            case .copy:
                try copyItemSafely(from: sourceURL, to: destinationURL)
            case .move:
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            }
            return
        }

        let temporaryURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.lastPathComponent).tfx-replace-\(UUID().uuidString)")

        switch operation {
        case .copy:
            do {
                try copyItemSafely(from: sourceURL, to: temporaryURL)
                _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: temporaryURL)
            } catch {
                try? FileManager.default.removeItem(at: temporaryURL)
                throw error
            }
        case .move:
            try FileManager.default.moveItem(at: sourceURL, to: temporaryURL)
            do {
                _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: temporaryURL)
            } catch {
                // The source already lives at the temp name; put
                // it back so a failed replace doesn't strand the
                // user's file under a hidden random name.
                try? FileManager.default.moveItem(at: temporaryURL, to: sourceURL)
                throw error
            }
        }
    }

    private static func zipArchiveName(for items: [FileItem]) -> String {
        if items.count == 1 {
            let baseName = items[0].url.lastPathComponent
            return baseName.isEmpty ? "Archive.zip" : "\(baseName).zip"
        }

        return "Archive.zip"
    }

    private static func runArchiveCommand(arguments: [String], currentDirectory: URL?) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw FileArchiveOperationError.commandFailed(error.localizedDescription)
        }

        // Drain stderr BEFORE waiting: `ditto` writing more than
        // the ~64 KB kernel pipe buffer of warnings would block
        // forever while we sit in `waitUntilExit()`, deadlocking
        // the operation. `readDataToEndOfFile` returns at EOF,
        // i.e. when the process exits and the write end closes.
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? ""
            throw FileArchiveOperationError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

#endif
