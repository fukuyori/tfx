#if os(macOS)
import Foundation

extension FileBrowserModel {
    func toggleFolderExpansion(_ url: URL) {
        let key = url.standardizedFileURL

        if expandedFolders.contains(key) {
            expandedFolders.remove(key)
        } else {
            expandFolder(url)
        }
    }

    func expandFolder(_ url: URL) {
        let key = url.standardizedFileURL
        expandedFolders.insert(key)
        refreshFolderChildren(url)
    }

    /// Expand a folder WITHOUT scheduling a `loadChildren`
    /// enumeration. Used by navigation paths where a `reload()`
    /// of the same directory is about to run anyway — the reload
    /// seeds the folder-tree cache from its own listing (see
    /// `seedFolderChildrenCache`), so the extra enumeration
    /// would just read the directory from disk twice.
    func markFolderExpanded(_ url: URL) {
        expandedFolders.insert(url.standardizedFileURL)
    }

    /// Reuse the just-completed pane listing as the folder tree's
    /// children for `directory` instead of re-enumerating it.
    /// `FileItem` already resolved directory-ness (including
    /// symlinks and Finder aliases) and the localized display
    /// name, so this is pure in-memory work.
    func seedFolderChildrenCache(for directory: URL) {
        guard ZipArchiveBrowser.location(for: directory) == nil else { return }
        let key = directory.standardizedFileURL
        // Bump the generation so an in-flight background load
        // for the same key can't overwrite this fresher listing.
        folderChildrenLoadGenerations[key] = (folderChildrenLoadGenerations[key] ?? 0) + 1
        let children = allItems
            .filter { $0.isDirectory && (showHiddenFiles || !$0.isHidden) }
            .map { (url: $0.url, sortName: $0.searchName) }
            .sorted { $0.sortName < $1.sortName }
            .map(\.url)
        folderChildrenCache[key] = children
        pruneFolderChildrenCacheIfNeeded()
    }

    /// Keep the folder-children cache from growing without bound
    /// over a long session (every visited directory used to stay
    /// forever). Entries the tree can still be showing — expanded
    /// folders, the current directory and its ancestors, pinned
    /// folders, and the root — are never evicted; everything else
    /// just re-loads on the next expansion.
    private func pruneFolderChildrenCacheIfNeeded() {
        let limit = 1_024
        guard folderChildrenCache.count > limit else { return }

        var retained = expandedFolders
        retained.insert(currentDirectory.standardizedFileURL)
        retained.formUnion(FileBrowserFolderSupport.ancestors(of: currentDirectory))
        retained.formUnion(pinnedFolders.map { $0.standardizedFileURL })
        retained.insert(URL(fileURLWithPath: "/").standardizedFileURL)

        for key in folderChildrenCache.keys where !retained.contains(key) {
            folderChildrenCache.removeValue(forKey: key)
            folderChildrenLoadGenerations.removeValue(forKey: key)
        }
    }

    /// Collapse every expanded folder in the tree. The root row
    /// stays visible because the tree renders roots independently
    /// of the `expandedFolders` set.
    func collapseAllFolders() {
        guard !expandedFolders.isEmpty else { return }
        expandedFolders.removeAll()
    }

    func childrenForFolder(_ url: URL) -> [URL] {
        folderChildrenCache[url.standardizedFileURL] ?? []
    }

    func refreshFolderChildrenIfNeeded(_ url: URL) {
        let key = url.standardizedFileURL
        guard folderChildrenCache[key] == nil, folderChildrenLoadGenerations[key] == nil else {
            return
        }

        refreshFolderChildren(url)
    }

    func refreshFolderChildren(_ url: URL) {
        let key = url.standardizedFileURL
        let generation = (folderChildrenLoadGenerations[key] ?? 0) + 1
        folderChildrenLoadGenerations[key] = generation

        enqueueFolderChildrenLoad(for: key)
    }

    private func enqueueFolderChildrenLoad(for key: URL) {
        guard !queuedFolderChildrenLoads.contains(key) else { return }
        queuedFolderChildrenLoads.insert(key)
        folderChildrenLoadQueue.append(key)
        processFolderChildrenLoadQueue()
    }

    private func processFolderChildrenLoadQueue() {
        while activeFolderChildrenLoadCount < maxConcurrentFolderChildrenLoads,
              !folderChildrenLoadQueue.isEmpty {
            let key = folderChildrenLoadQueue.removeFirst()
            queuedFolderChildrenLoads.remove(key)
            activeFolderChildrenLoadCount += 1
            let generation = folderChildrenLoadGenerations[key] ?? 0
            let showsHiddenFiles = showHiddenFiles

            DispatchQueue.global(qos: .utility).async {
                let children = FileBrowserFolderSupport.loadChildren(for: key, showsHiddenFiles: showsHiddenFiles)

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.activeFolderChildrenLoadCount = max(0, self.activeFolderChildrenLoadCount - 1)

                    if self.folderChildrenLoadGenerations[key] == generation {
                        self.folderChildrenCache[key] = children
                        self.pruneFolderChildrenCacheIfNeeded()
                    }

                    self.processFolderChildrenLoadQueue()
                }
            }
        }
    }

    func refreshFolderTreeForHiddenFileSettingChange() {
        folderChildrenCache.removeAll()
        for key in folderChildrenLoadGenerations.keys {
            folderChildrenLoadGenerations[key, default: 0] += 1
        }
        queuedFolderChildrenLoads.removeAll()
        folderChildrenLoadQueue.removeAll()

        let foldersToRefresh = expandedFolders
        for folder in foldersToRefresh {
            refreshFolderChildren(folder)
        }
    }

    func rebuildFolderTree() {
        let knownFolders = Set(folderChildrenLoadGenerations.keys)
            .union(expandedFolders)
            .union(FileBrowserFolderSupport.ancestors(of: currentDirectory))
            .union([URL(fileURLWithPath: "/").standardizedFileURL])

        folderChildrenCache.removeAll()
        for key in knownFolders {
            folderChildrenLoadGenerations[key, default: 0] += 1
        }
        queuedFolderChildrenLoads.removeAll()
        folderChildrenLoadQueue.removeAll()
        activeFolderChildrenLoadCount = 0

        expandAncestors(of: currentDirectory)
        refreshFolderChildren(URL(fileURLWithPath: "/").standardizedFileURL)
        ensureFolderTreeSelection()
    }
}
#endif
