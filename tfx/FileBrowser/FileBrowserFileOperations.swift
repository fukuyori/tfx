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
        let destination = FileConflictResolver.uniqueDestination(for: trimmed, in: affectedDirectory)
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
                operation: clipboard.operation
            )

            switch decision {
            case .cancel:
                return nil
            case .skip:
                continue
            case let .use(destinationURL, shouldReplace):
                if shouldReplace {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                switch clipboard.operation {
                case .copy:
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                case .move:
                    try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
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
            if shouldReplace {
                try FileManager.default.removeItem(at: resolvedDestinationURL)
            }
            destinationURL = resolvedDestinationURL
        }

        switch operation {
        case .copy:
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        case .move:
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
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

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? ""
            throw FileArchiveOperationError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

#endif
