#if os(macOS)
import Foundation

extension FileBrowserModel {
    /// Run a copy / move on a background queue with per-byte
    /// progress reporting and a Cancel-safe cleanup pass. The
    /// completion handler runs on the main queue after every
    /// item has been processed (or aborted by Cancel) and
    /// receives the list of URLs that successfully landed at
    /// the destination.
    ///
    /// Per-item failure policy: log to `failures`, continue with
    /// the next item. Cancel policy: stop after the currently
    /// in-flight chunk's enclosing file is rewound and deleted —
    /// the destination directory may still contain successfully
    /// copied earlier items, the source side is left untouched
    /// for any item we didn't finish.
    func runFileOperation(
        kind: FileOperationProgressViewModel.Kind,
        items: [URL],
        destination: URL,
        completion: @escaping (_ added: [URL], _ removedFromSource: [URL]) -> Void
    ) {
        var claimedDestinations = Set<String>()
        let requests = items.map { source in
            let destinationURL = FileConflictResolver.uniqueDestination(
                for: source.lastPathComponent,
                in: destination,
                excluding: claimedDestinations
            )
            claimedDestinations.insert(FileConflictResolver.claimKey(destinationURL))
            return FileOperationRequest(
                sourceURL: source,
                destinationURL: destinationURL,
                shouldReplaceDestination: false
            )
        }

        runFileOperation(kind: kind, requests: requests, completion: completion)
    }

    func runFileOperation(
        kind: FileOperationProgressViewModel.Kind,
        requests: [FileOperationRequest],
        completion: @escaping (_ added: [URL], _ removedFromSource: [URL]) -> Void
    ) {
        // The byte tally happens on the background queue below —
        // it walks every source tree, which for a 100k-file
        // folder or a slow network volume takes long enough to
        // beachball the main thread. Start with a placeholder
        // total; `Progress` is KVO-safe to update from any
        // thread and the card simply shows a fuller picture once
        // the tally lands.
        let progress = Progress(totalUnitCount: 1)
        progress.kind = .file
        // `Progress.FileOperationKind` defines `.copying` and
        // `.downloading` but not `.moving`; pick the closest
        // semantic for both kinds. The user-facing label comes
        // from `FileOperationProgressViewModel.kind` anyway.
        progress.fileOperationKind = .copying
        // The current file URL is updated per-item below.
        let viewModel = FileOperationProgressViewModel(kind: kind, progress: progress)
        let shouldRemoveSource = kind == .moving
        activeOperations.append(viewModel)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Pre-flight: tally the total byte size so the
            // progress bar reflects actual work rather than item
            // count.
            let totalBytes = requests.reduce(Int64(0)) { total, request in
                let source = request.sourceURL
                let scoped = source.startAccessingSecurityScopedResource()
                defer {
                    if scoped {
                        source.stopAccessingSecurityScopedResource()
                    }
                }
                return total + SafeFileCopier.totalSize(of: source)
            }
            progress.totalUnitCount = max(totalBytes, 1)

            var added: [URL] = []
            var removed: [URL] = []

            for request in requests {
                if progress.isCancelled { break }
                let source = request.sourceURL
                let destURL = request.destinationURL
                progress.fileURL = source

                do {
                    let scoped = source.startAccessingSecurityScopedResource()
                    defer {
                        if scoped {
                            source.stopAccessingSecurityScopedResource()
                        }
                    }

                    if request.shouldReplaceDestination {
                        // "Replace" must never destroy the old
                        // version before the new one is fully
                        // written: copy into a hidden sibling
                        // temp name first, then swap atomically.
                        // A mid-copy failure (disk full, source
                        // unreadable, cancel) leaves the existing
                        // destination untouched.
                        let temporaryURL = destURL
                            .deletingLastPathComponent()
                            .appendingPathComponent(".\(destURL.lastPathComponent).tfx-replace-\(UUID().uuidString)")
                        do {
                            try SafeFileCopier.copy(from: source, to: temporaryURL, progress: progress)
                            _ = try FileManager.default.replaceItemAt(destURL, withItemAt: temporaryURL)
                        } catch {
                            try? FileManager.default.removeItem(at: temporaryURL)
                            throw error
                        }
                    } else {
                        try SafeFileCopier.copy(from: source, to: destURL, progress: progress)
                    }
                    added.append(destURL)
                    if shouldRemoveSource {
                        // Source-side cleanup only after the
                        // destination is fully written and
                        // verified by `copy(...)` returning
                        // without throwing. This preserves the
                        // copy-verify-delete invariant.
                        try FileManager.default.removeItem(at: source)
                        removed.append(source)
                    }
                } catch SafeFileCopierError.cancelled {
                    // `SafeFileCopier` already removed the
                    // partially-written destination *file*, but a
                    // cancelled directory copy leaves a partial
                    // tree under its final name — indistinguishable
                    // from a completed copy. Remove it so the user
                    // can't mistake it for the real thing. (Replace
                    // requests copied into a temp name that the
                    // inner catch already cleaned up; the existing
                    // destination must stay.)
                    if !request.shouldReplaceDestination {
                        try? FileManager.default.removeItem(at: destURL)
                    }
                    break
                } catch {
                    // Per-item failure: leave the source where
                    // it is, drop whatever partial destination
                    // may exist, and move on to the next item.
                    // Never remove the destination of a replace
                    // request — that is the user's pre-existing
                    // file, still intact because the swap above
                    // didn't happen.
                    if !request.shouldReplaceDestination {
                        try? FileManager.default.removeItem(at: destURL)
                    }
                    DispatchQueue.main.async { [weak self] in
                        self?.show(error)
                    }
                }
            }

            DispatchQueue.main.async { [weak self] in
                // Remove only this operation's card — another
                // operation started meanwhile keeps its own.
                self?.activeOperations.removeAll { $0 === viewModel }
                completion(added, removed)
            }
        }
    }
}

#endif
