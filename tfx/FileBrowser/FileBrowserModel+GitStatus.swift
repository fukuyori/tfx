#if os(macOS)
import Foundation

extension FileBrowserModel {
    /// Kick off a fresh Git status fetch for `currentDirectory`. Safe to
    /// call repeatedly — a previous in-flight fetch is cancelled before
    /// the new one starts, so only the most recent answer ever lands on
    /// the model.
    ///
    /// Resolution flow:
    ///
    /// 1. Look up (or probe and cache) the Git work-tree root for the
    ///    current directory. Non-Git directories cache a nil root so a
    ///    repeat call is free.
    /// 2. If there's no root, clear any stale status and return.
    /// 3. Otherwise read porcelain v2 status on a background queue and
    ///    publish the result back on the main actor, guarded by both a
    ///    cancellation token and a re-check that `currentDirectory`
    ///    still belongs to the same work tree.
    func refreshGitStatus() {
        let directory = currentDirectory.standardizedFileURL

        // Cancel any prior fetch *before* spawning the next one so the
        // late answer from the cancelled job is dropped at publish
        // time.
        gitStatusCancellation?.cancel()
        let cancellation = GitStatusCancellation()
        gitStatusCancellation = cancellation

        // Snapshot the cache off the main actor before hopping queues —
        // the cache itself is only mutated on the main thread.
        let cacheLookup: URL?? = cachedGitRoot(for: directory)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Step 1: resolve or probe the root.
            let root: URL?
            if let cached = cacheLookup {
                // `.some(URL?)` — probed previously, possibly to nil.
                root = cached
            } else {
                root = GitStatusReader.workTreeRoot(near: directory)
                DispatchQueue.main.async { [weak self] in
                    self?.gitRootCache[directory] = root
                }
            }

            guard let root else {
                // Outside any work tree — clear any stale snapshot.
                DispatchQueue.main.async { [weak self] in
                    guard
                        let self,
                        !cancellation.isCancelled,
                        self.currentDirectory.standardizedFileURL == directory
                    else { return }
                    if self.gitRepositoryStatus != nil {
                        self.gitRepositoryStatus = nil
                    }
                }
                return
            }

            if cancellation.isCancelled { return }
            let status = GitStatusReader.readStatus(root: root, cancellation: cancellation)
            if cancellation.isCancelled { return }

            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    !cancellation.isCancelled,
                    self.currentDirectory.standardizedFileURL == directory
                else { return }
                self.gitRepositoryStatus = status
            }
        }
    }

    /// Cached Git root resolution. Returns:
    /// - `.some(.some(root))` when we know the directory is in `root`.
    /// - `.some(.none)` when we know the directory is outside any work tree.
    /// - `.none` when we have not probed yet.
    private func cachedGitRoot(for directory: URL) -> URL?? {
        // Direct hit on the requested directory.
        if let cached = gitRootCache[directory] { return cached }
        // Walk up: if any cached ancestor has a known root that contains
        // `directory`, reuse it. This makes navigating around a repo
        // cheap after the first probe.
        var ancestor = directory.deletingLastPathComponent().standardizedFileURL
        while ancestor.path != "/" {
            if let cached = gitRootCache[ancestor] {
                if let root = cached, directory.path.hasPrefix(root.path) {
                    return .some(root)
                }
                // Cached ancestor knows it's outside any work tree, and
                // the requested directory is inside that ancestor —
                // therefore the requested directory is also outside.
                if cached == nil {
                    return .some(nil)
                }
                break
            }
            let next = ancestor.deletingLastPathComponent().standardizedFileURL
            if next == ancestor { break }
            ancestor = next
        }
        return .none
    }

    /// Status to surface in the Git column for one file row, or nil when
    /// the directory is non-Git or the file is unchanged.
    func gitStatus(for item: FileItem) -> GitFileStatus? {
        gitRepositoryStatus?.status(for: item.url)
    }
}

#endif
