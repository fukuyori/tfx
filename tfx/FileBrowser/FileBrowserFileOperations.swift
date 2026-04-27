#if os(macOS)
import Foundation

struct FileOperationChange {
    let originModelID: UUID
    let affectedDirectories: Set<URL>
}

enum FileOperationNotifier {
    static func notifyDirectoriesChanged(_ directories: [URL], originModelID: UUID) {
        let affectedDirectories = Set(directories.map(\.standardizedFileURL))
        guard !affectedDirectories.isEmpty else { return }

        NotificationCenter.default.post(
            name: .fileManagerDirectoriesDidChange,
            object: FileOperationChange(originModelID: originModelID, affectedDirectories: affectedDirectories)
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

struct FileMoveResult {
    let destinationURL: URL
    let affectedDirectories: Set<URL>
}

struct FileCreateFolderResult {
    let folderURL: URL
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

enum FileBrowserFileOperations {
    static func createFolder(in directory: URL) throws -> FileCreateFolderResult? {
        guard let name = FileOperationPrompt.text(title: "New Folder", message: "Enter a folder name.", defaultValue: "Untitled Folder") else {
            return nil
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let folderURL = FileConflictResolver.uniqueDestination(for: trimmed, in: directory)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        return FileCreateFolderResult(folderURL: folderURL, affectedDirectory: directory.standardizedFileURL)
    }

    static func rename(_ item: FileItem) throws -> FileRenameResult? {
        guard let name = FileOperationPrompt.text(title: "Rename", message: "Enter a new name.", defaultValue: item.name) else {
            return nil
        }

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

    static func paste(_ clipboard: FileClipboard, into targetDirectory: URL) throws -> FilePasteResult? {
        var pastedURLs: [URL] = []
        var removedURLs: [URL] = []
        var affectedDirectories = Set<URL>()

        for sourceURL in clipboard.urls {
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

    static func move(_ sourceURL: URL, to targetDirectory: URL) throws -> FileMoveResult? {
        let decision = FileConflictResolver.destinationDecision(for: sourceURL, in: targetDirectory, operation: .move)

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

        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        return FileMoveResult(
            destinationURL: destinationURL,
            affectedDirectories: [
                sourceURL.deletingLastPathComponent().standardizedFileURL,
                targetDirectory.standardizedFileURL
            ]
        )
    }
}

#endif
