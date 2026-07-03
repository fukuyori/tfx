#if os(macOS)
import Foundation

enum FileConflictResolver {
    static func destinationDecision(
        for sourceURL: URL,
        in directory: URL,
        operation: FileClipboard.Operation
    ) -> FileConflictDecision {
        var batchResolution: ConflictResolution?
        var claimedDestinations = Set<String>()
        return destinationDecision(
            for: sourceURL,
            in: directory,
            operation: operation,
            batchResolution: &batchResolution,
            claimedDestinations: &claimedDestinations
        )
    }

    static func destinationDecision(
        for sourceURL: URL,
        in directory: URL,
        operation: FileClipboard.Operation,
        batchResolution: inout ConflictResolution?
    ) -> FileConflictDecision {
        var claimedDestinations = Set<String>()
        return destinationDecision(
            for: sourceURL,
            in: directory,
            operation: operation,
            batchResolution: &batchResolution,
            claimedDestinations: &claimedDestinations
        )
    }

    /// `claimedDestinations` tracks destination paths already
    /// promised to earlier items of the same batch (keys from
    /// `claimKey(_:)`). Batch planning decides every destination
    /// against the *pre-operation* disk state, so two sources
    /// named `report.txt` from different folders would otherwise
    /// both resolve to `target/report.txt` and the second copy
    /// would silently overwrite the first.
    static func destinationDecision(
        for sourceURL: URL,
        in directory: URL,
        operation: FileClipboard.Operation,
        batchResolution: inout ConflictResolution?,
        claimedDestinations: inout Set<String>
    ) -> FileConflictDecision {
        let destinationURL = directory.appendingPathComponent(sourceURL.lastPathComponent)

        // Refuse to copy or move a folder into itself or any of
        // its descendants. The batch runner implements `move` as
        // "copy the tree, then removeItem(source)" — without this
        // guard, `/a` moved into `/a/b` copies into `/a/b/a` and
        // the trailing removal deletes the entire tree, copy
        // included. Compare symlink-resolved paths so a
        // destination reached through a link to the source (or a
        // `/tmp` vs `/private/tmp` spelling) is caught too.
        let resolvedSourcePath = sourceURL.resolvingSymlinksInPath().path
        let resolvedDirectoryPath = directory.resolvingSymlinksInPath().path
        if resolvedDirectoryPath == resolvedSourcePath
            || resolvedDirectoryPath.hasPrefix(resolvedSourcePath + "/") {
            FileOperationPrompt.showCannotTransferIntoItself(itemName: sourceURL.lastPathComponent)
            return .cancel
        }

        // Same-file check: the destination resolves to the very
        // item being transferred (paste into the source's own
        // folder, or into a symlink of it). Resolve symlinks so a
        // "replace" answer can never delete the source itself.
        let resolvedDestinationPath = directory
            .appendingPathComponent(sourceURL.lastPathComponent)
            .resolvingSymlinksInPath().path

        if operation == .move && resolvedSourcePath == resolvedDestinationPath {
            return .skip
        }

        if operation == .copy && resolvedSourcePath == resolvedDestinationPath {
            return .use(uniqueDestination(for: sourceURL.lastPathComponent, in: directory), shouldReplace: false)
        }

        let destinationTaken = FileManager.default.fileExists(atPath: destinationURL.path)
            || claimedDestinations.contains(claimKey(destinationURL))
        guard destinationTaken else {
            claimedDestinations.insert(claimKey(destinationURL))
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
            claimedDestinations.insert(claimKey(destinationURL))
            return .use(destinationURL, shouldReplace: true)
        case .keepBoth:
            let unique = uniqueDestination(
                for: sourceURL.lastPathComponent,
                in: directory,
                excluding: claimedDestinations
            )
            claimedDestinations.insert(claimKey(unique))
            return .use(unique, shouldReplace: false)
        case .skip:
            return .skip
        case .cancel:
            return .cancel
        }
    }

    static func uniqueDestination(
        for fileName: String,
        in directory: URL,
        excluding claimedDestinations: Set<String> = []
    ) -> URL {
        var candidate = directory.appendingPathComponent(fileName)
        let ext = candidate.pathExtension
        let stem = candidate.deletingPathExtension().lastPathComponent
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path)
            || claimedDestinations.contains(claimKey(candidate)) {
            let renamed = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
            candidate = directory.appendingPathComponent(renamed)
            index += 1
        }

        return candidate
    }

    /// Normalized set key for `claimedDestinations`. Lowercased
    /// because the default APFS volume is case-insensitive:
    /// `Report.txt` and `report.txt` would collide on disk, so
    /// they must collide in the claim set too.
    static func claimKey(_ url: URL) -> String {
        url.standardizedFileURL.path.lowercased()
    }
}

#endif
