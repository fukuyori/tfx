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
        // Throttle with a trailing run: `reload()` calls this on
        // every navigation AND on every directory-watcher event
        // (builds, terminal work, log writers), and each call
        // spawns a `git status` process. During write storms that
        // kept a status process running near-continuously. The
        // trailing work item guarantees the *final* state is
        // always fetched, so badges never go permanently stale.
        let minimumInterval: TimeInterval = 1.0
        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lastGitStatusFetchTime
        if elapsed < minimumInterval {
            guard pendingGitStatusWorkItem == nil else { return }
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pendingGitStatusWorkItem = nil
                self.performGitStatusFetch()
            }
            pendingGitStatusWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + (minimumInterval - elapsed),
                execute: workItem
            )
            return
        }
        performGitStatusFetch()
    }

    private func performGitStatusFetch() {
        lastGitStatusFetchTime = CFAbsoluteTimeGetCurrent()
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
                    guard let self else { return }
                    // Plain dictionary with no eviction — reset
                    // wholesale once it grows past any plausible
                    // working set so a long session can't grow it
                    // monotonically. Repopulates on demand (one
                    // `rev-parse` per directory) and the ancestor
                    // walk in `cachedGitRoot` keeps hit rates high
                    // right after a reset.
                    if self.gitRootCache.count > 512 {
                        self.gitRootCache.removeAll(keepingCapacity: true)
                    }
                    self.gitRootCache[directory] = root
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
            // Scope the walk to the pane's directory — row badges
            // only need entries under it, and this lets git skip
            // the rest of a large work tree.
            let status = GitStatusReader.readStatus(root: root, scope: directory, cancellation: cancellation)
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

    var isCurrentDirectoryGitRepository: Bool {
        if gitRepositoryStatus != nil {
            return true
        }
        // Fallback was previously a synchronous
        // `GitStatusReader.workTreeRoot(near:)` call, which spawns
        // `/usr/bin/git rev-parse` and blocks the main thread with
        // `Process.waitUntilExit()`. SwiftUI calls this getter
        // from menu / view body evaluation, so the blocking call
        // would spin a nested `CFRunLoop` that drained pending
        // `DispatchQueue.main.async` blocks DURING the current
        // view-update transaction — every `@Published` write in
        // those blocks (`items`, `availableCapacityText`,
        // `selectedItemIDs`, ...) then surfaced as the
        // "Publishing changes from within view updates" warning
        // / AttributeGraph cycle burst that hit on `⌘N` and
        // other reload-bearing actions.
        //
        // Use the already-populated `gitRootCache` so the getter
        // stays non-blocking. The background Git status path
        // populates the cache; until it has run for this
        // directory we conservatively return `false`. That can
        // briefly hide Git-only menu items on the very first
        // visit to a repo, which is acceptable — they reappear
        // as soon as the asynchronous status read lands.
        let key = currentDirectory.standardizedFileURL
        if let cached = gitRootCache[key] {
            return cached != nil
        }
        return false
    }
}

#endif
