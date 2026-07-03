#if os(macOS)
import Foundation

extension FileBrowserModel {
    var trimmedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }

    var hasActiveSubfolderSearchQuery: Bool {
        searchesSubfolders && !trimmedSearchQuery.isEmpty && ZipArchiveBrowser.location(for: currentDirectory) == nil
    }

    var subfolderSearchStatusText: String? {
        guard searchesSubfolders else { return nil }
        guard !trimmedSearchQuery.isEmpty else {
            return String(localized: "Subfolder search: enter a query")
        }

        if isSubfolderSearchRunning {
            if subfolderSearchSkippedFolderCount > 0 {
                return String(localized: "Searching: depth \(subfolderSearchDepth), \(subfolderSearchProcessedFolderCount) folders, \(subfolderSearchSkippedFolderCount) skipped, \(subfolderSearchHitCount) hits")
            }
            return String(localized: "Searching: depth \(subfolderSearchDepth), \(subfolderSearchProcessedFolderCount) folders, \(subfolderSearchHitCount) hits")
        } else {
            if subfolderSearchSkippedFolderCount > 0 {
                return String(localized: "Search: depth \(subfolderSearchDepth), \(subfolderSearchProcessedFolderCount) folders, \(subfolderSearchSkippedFolderCount) skipped, \(subfolderSearchHitCount) hits")
            }
            return String(localized: "Search: depth \(subfolderSearchDepth), \(subfolderSearchProcessedFolderCount) folders, \(subfolderSearchHitCount) hits")
        }
    }

    func submitSubfolderSearch() {
        guard !trimmedSearchQuery.isEmpty else {
            stopSubfolderSearch()
            return
        }

        searchesSubfolders = true
        startSubfolderSearch()
    }

    func stopSubfolderSearch() {
        searchesSubfolders = false
        subfolderSearchWorkItem?.cancel()
        subfolderSearchWorkItem = nil
        subfolderSearchCancellation?.cancel()
        subfolderSearchCancellation = nil
        subfolderSearchResumeAfterError?()
        subfolderSearchResumeAfterError = nil
        filterWorkItem?.cancel()
        filterWorkItem = nil
        filterSortCancellation?.cancel()
        filterSortCancellation = nil
        metadataPrefetchWorkItem?.cancel()
        metadataPrefetchWorkItem = nil
        metadataPrefetchCancellation?.cancel()
        metadataPrefetchCancellation = nil
        subfolderSearchGeneration += 1
        filterGeneration += 1
        isSubfolderSearchRunning = false
    }

    func startSubfolderSearch() {
        guard hasActiveSubfolderSearchQuery else { return }

        subfolderSearchGeneration += 1
        let generation = subfolderSearchGeneration
        subfolderSearchCancellation?.cancel()
        let cancellation = SubfolderSearchCancellation()
        subfolderSearchCancellation = cancellation
        directoryLoadCancellation?.cancel()
        filterSortCancellation?.cancel()
        filterWorkItem?.cancel()
        filterWorkItem = nil
        metadataPrefetchWorkItem?.cancel()
        metadataPrefetchWorkItem = nil
        metadataPrefetchCancellation?.cancel()
        metadataPrefetchCancellation = nil
        filterGeneration += 1

        allItems = []
        allItemLookup = [:]
        items = []
        clearSelection()
        refreshPreviewURLs()
        updateAvailableCapacity()
        subfolderSearchDepth = 0
        subfolderSearchProcessedFolderCount = 0
        subfolderSearchSkippedFolderCount = 0
        subfolderSearchHitCount = 0
        isSubfolderSearchRunning = true

        let rootDirectory = currentDirectory.standardizedFileURL
        let query = trimmedSearchQuery
        let showsHiddenFiles = showHiddenFiles
        let batchSize = directoryLoadChunkSize

        FileBrowserSubfolderSearch.search(
            rootDirectory: rootDirectory,
            query: query,
            showsHiddenFiles: showsHiddenFiles,
            batchSize: batchSize,
            cancellation: cancellation,
            publishProgress: { [weak self] progress in
                DispatchQueue.main.async {
                    guard
                        let self,
                        self.subfolderSearchGeneration == generation,
                        self.currentDirectory.standardizedFileURL == rootDirectory,
                        !cancellation.isCancelled
                    else {
                        return
                    }

                    self.subfolderSearchDepth = progress.depth
                    self.subfolderSearchProcessedFolderCount = progress.processedFolderCount
                    self.subfolderSearchSkippedFolderCount = progress.skippedFolderCount
                    self.subfolderSearchHitCount = progress.hitCount
                }
            },
            publishBatch: { [weak self] batch in
                DispatchQueue.main.async {
                    guard
                        let self,
                        self.subfolderSearchGeneration == generation,
                        self.currentDirectory.standardizedFileURL == rootDirectory,
                        !cancellation.isCancelled
                    else {
                        return
                    }

                    self.appendSubfolderSearchItems(batch)
                }
            },
            publishCompletion: { [weak self] completed in
                DispatchQueue.main.async {
                    guard
                        let self,
                        self.subfolderSearchGeneration == generation,
                        self.currentDirectory.standardizedFileURL == rootDirectory
                    else {
                        return
                    }

                    if completed || cancellation.isCancelled {
                        self.isSubfolderSearchRunning = false
                    }
                }
            }
        )
    }

    private func appendSubfolderSearchItems(_ loadedItems: [FileItem]) {
        guard !loadedItems.isEmpty else { return }
        allItems.append(contentsOf: loadedItems)
        // Differential inserts: rebuilding both lookups from
        // scratch per batch made long searches O(n²) on the main
        // thread. `pendingVisibleIndexAppendStart` tells the
        // `items` didSet to extend the index lookup in place.
        for item in loadedItems {
            allItemLookup[item.id] = item
        }
        pendingVisibleIndexAppendStart = items.count
        items.append(contentsOf: loadedItems)
        refreshPreviewURLs()
    }
}

#endif
