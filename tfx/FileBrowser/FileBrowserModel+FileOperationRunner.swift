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
        let requests = items.map { source in
            FileOperationRequest(
                sourceURL: source,
                destinationURL: FileConflictResolver.uniqueDestination(
                    for: source.lastPathComponent,
                    in: destination
                ),
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
        // Pre-flight: tally the total byte size so the progress
        // bar reflects actual work rather than item count.
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
        let progress = Progress(totalUnitCount: max(totalBytes, 1))
        progress.kind = .file
        // `Progress.FileOperationKind` defines `.copying` and
        // `.downloading` but not `.moving`; pick the closest
        // semantic for both kinds. The user-facing label comes
        // from `FileOperationProgressViewModel.kind` anyway.
        progress.fileOperationKind = .copying
        // The current file URL is updated per-item below.
        let viewModel = FileOperationProgressViewModel(kind: kind, progress: progress)
        let shouldRemoveSource = kind == .moving
        activeOperation = viewModel

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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
                        try FileManager.default.removeItem(at: destURL)
                    }

                    try SafeFileCopier.copy(from: source, to: destURL, progress: progress)
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
                    // partially-written destination file. Stop
                    // touching anything else.
                    break
                } catch {
                    // Per-item failure: leave the source where
                    // it is, drop whatever partial destination
                    // may exist, and move on to the next item.
                    try? FileManager.default.removeItem(at: destURL)
                    DispatchQueue.main.async { [weak self] in
                        self?.show(error)
                    }
                }
            }

            DispatchQueue.main.async { [weak self] in
                self?.activeOperation = nil
                completion(added, removed)
            }
        }
    }
}

#endif
