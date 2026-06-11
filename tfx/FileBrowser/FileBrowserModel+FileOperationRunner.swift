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
        // Pre-flight: tally the total byte size so the progress
        // bar reflects actual work rather than item count.
        let totalBytes = items.reduce(0) { $0 + SafeFileCopier.totalSize(of: $1) }
        let progress = Progress(totalUnitCount: max(totalBytes, 1))
        progress.kind = .file
        // `Progress.FileOperationKind` defines `.copying` and
        // `.downloading` but not `.moving`; pick the closest
        // semantic for both kinds. The user-facing label comes
        // from `FileOperationProgressViewModel.kind` anyway.
        progress.fileOperationKind = .copying
        // The current file URL is updated per-item below.
        let viewModel = FileOperationProgressViewModel(kind: kind, progress: progress)
        activeOperation = viewModel

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var added: [URL] = []
            var removed: [URL] = []

            for source in items {
                if progress.isCancelled { break }
                progress.fileURL = source

                let destURL = FileConflictResolver.uniqueDestination(
                    for: source.lastPathComponent,
                    in: destination
                )
                do {
                    try SafeFileCopier.copy(from: source, to: destURL, progress: progress)
                    added.append(destURL)
                    if kind == .moving {
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
