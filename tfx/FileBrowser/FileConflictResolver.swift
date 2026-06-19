#if os(macOS)
import Foundation

enum FileConflictResolver {
    static func destinationDecision(
        for sourceURL: URL,
        in directory: URL,
        operation: FileClipboard.Operation
    ) -> FileConflictDecision {
        var batchResolution: ConflictResolution?
        return destinationDecision(
            for: sourceURL,
            in: directory,
            operation: operation,
            batchResolution: &batchResolution
        )
    }

    static func destinationDecision(
        for sourceURL: URL,
        in directory: URL,
        operation: FileClipboard.Operation,
        batchResolution: inout ConflictResolution?
    ) -> FileConflictDecision {
        let destinationURL = directory.appendingPathComponent(sourceURL.lastPathComponent)

        if operation == .move && sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            return .skip
        }

        if operation == .copy && sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            return .use(uniqueDestination(for: sourceURL.lastPathComponent, in: directory), shouldReplace: false)
        }

        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            return .use(destinationURL, shouldReplace: false)
        }

        let resolution: ConflictResolution
        if let batchResolution {
            resolution = batchResolution
        } else {
            let choice = FileOperationPrompt.conflictResolutionChoice(fileName: destinationURL.lastPathComponent)
            resolution = choice.resolution
            if choice.appliesToAll {
                batchResolution = resolution
            }
        }

        switch resolution {
        case .replace:
            return .use(destinationURL, shouldReplace: true)
        case .keepBoth:
            return .use(uniqueDestination(for: sourceURL.lastPathComponent, in: directory), shouldReplace: false)
        case .skip:
            return .skip
        case .cancel:
            return .cancel
        }
    }

    static func uniqueDestination(for fileName: String, in directory: URL) -> URL {
        var candidate = directory.appendingPathComponent(fileName)
        let ext = candidate.pathExtension
        let stem = candidate.deletingPathExtension().lastPathComponent
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            let renamed = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
            candidate = directory.appendingPathComponent(renamed)
            index += 1
        }

        return candidate
    }
}

#endif
