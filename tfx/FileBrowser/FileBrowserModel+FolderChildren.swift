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
