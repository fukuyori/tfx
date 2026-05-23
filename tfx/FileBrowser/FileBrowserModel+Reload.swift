#if os(macOS)
import Foundation

extension FileBrowserModel {
    func reload() {
        reloadGeneration += 1
        let generation = reloadGeneration
        let directory = currentDirectory
        let chunkSize = directoryLoadChunkSize
        // Kick off Git status resolution in parallel with the file
        // listing — the two are independent on disk, and the row
        // decorations should appear as soon as both land regardless of
        // which finishes first.
        refreshGitStatus()
        let preservingExistingItems = shouldPreserveItemsForReload(of: directory)
        let cancellation = resetDirectoryLoadState(preservingItems: preservingExistingItems)
        pendingLoadAccumulator.removeAll(keepingCapacity: true)
        // Surface the "Loading…" hint only when items are not already on
        // screen — preserving reloads keep the previous listing visible so
        // there is no empty pane to label.
        isLoadingDirectory = !preservingExistingItems

        if hasActiveSubfolderSearchQuery {
            isLoadingDirectory = false
            startSubfolderSearch()
            return
        }

        FileBrowserDirectoryLoader.load(
            directory: directory,
            chunkSize: chunkSize,
            cancellation: cancellation,
            publishHeader: { [weak self] result in
                self?.publishDirectoryHeader(result, generation: generation, directory: directory, cancellation: cancellation)
            },
            publishBatch: { [weak self] batch, isFinalBatch in
                self?.publishDirectoryBatch(
                    batch,
                    isFinalBatch: isFinalBatch,
                    generation: generation,
                    directory: directory,
                    cancellation: cancellation,
                    preservingExistingItems: preservingExistingItems
                )
            }
        )
    }

    /// Returns true when the upcoming load targets the directory we last
    /// loaded successfully *and* we still have items on screen. In that case
    /// we keep the current items visible and swap them atomically once the
    /// new listing is complete, instead of blanking the file pane.
    private func shouldPreserveItemsForReload(of directory: URL) -> Bool {
        guard let lastLoadedDirectory else { return false }
        guard !allItems.isEmpty else { return false }
        return lastLoadedDirectory.standardizedFileURL == directory.standardizedFileURL
    }

    private func resetDirectoryLoadState(preservingItems: Bool) -> DirectoryLoadCancellation {
        directoryLoadCancellation?.cancel()
        let cancellation = DirectoryLoadCancellation()
        directoryLoadCancellation = cancellation
        filterSortCancellation?.cancel()
        subfolderSearchWorkItem?.cancel()
        subfolderSearchWorkItem = nil
        subfolderSearchCancellation?.cancel()
        subfolderSearchCancellation = nil
        subfolderSearchGeneration += 1
        isSubfolderSearchRunning = false
        filterWorkItem?.cancel()
        filterWorkItem = nil
        metadataPrefetchWorkItem?.cancel()
        metadataPrefetchWorkItem = nil
        metadataPrefetchCancellation?.cancel()
        metadataPrefetchCancellation = nil
        filterGeneration += 1

        if !preservingItems {
            allItems = []
            allItemLookup = [:]
            items = []
            refreshPreviewURLs()
            availableCapacityText = "-"
        }
        return cancellation
    }

    private func publishDirectoryHeader(
        _ result: Result<DirectoryHeader, Error>,
        generation: Int,
        directory: URL,
        cancellation: DirectoryLoadCancellation
    ) {
        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                self.reloadGeneration == generation,
                self.currentDirectory.standardizedFileURL == directory.standardizedFileURL
            else {
                return
            }

            switch result {
            case let .success(header):
                self.availableCapacityText = header.availableCapacityText
                // Volume capacity is no longer fetched inline by
                // `loadHeader` because the underlying `statvfs` can be slow
                // on network volumes. Fire a deferred fetch here so the
                // status-line "Free X" updates once the answer arrives.
                self.fetchVolumeCapacity(for: directory, generation: generation)
            case let .failure(error):
                self.show(error)
                cancellation.cancel()
                self.isLoadingDirectory = false
            }
        }
    }

    private func fetchVolumeCapacity(for directory: URL, generation: Int) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let capacityText = FileBrowserDirectoryReader.availableCapacityText(for: directory)
            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    self.reloadGeneration == generation,
                    self.currentDirectory.standardizedFileURL == directory.standardizedFileURL
                else {
                    return
                }
                self.availableCapacityText = capacityText
            }
        }
    }

    private func publishDirectoryBatch(
        _ batch: [FileItem],
        isFinalBatch: Bool,
        generation: Int,
        directory: URL,
        cancellation: DirectoryLoadCancellation,
        preservingExistingItems: Bool
    ) {
        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                !cancellation.isCancelled,
                self.reloadGeneration == generation,
                self.currentDirectory.standardizedFileURL == directory.standardizedFileURL
            else {
                return
            }

            if preservingExistingItems {
                self.pendingLoadAccumulator.append(contentsOf: batch)
                if isFinalBatch {
                    self.commitPreservedReload(directory: directory)
                }
            } else {
                self.appendLoadedDirectoryItems(batch, pruneAfterUpdate: isFinalBatch)
                // First items have landed (or the load completed with
                // zero items) — drop the "Loading…" hint.
                self.isLoadingDirectory = false
                if isFinalBatch {
                    self.lastLoadedDirectory = directory
                }
            }
        }
    }

    private func appendLoadedDirectoryItems(_ loadedItems: [FileItem], pruneAfterUpdate: Bool) {
        if !loadedItems.isEmpty {
            allItems.append(contentsOf: loadedItems)
            allItemLookup = FileBrowserDirectoryState.itemLookup(for: allItems)
            refreshPreviewURLs()
        }

        if pruneAfterUpdate {
            applyFiltersAndSortAsync(pruneAfterUpdate: true)
        } else {
            scheduleFilterAndSort(pruneAfterUpdate: false)
        }
    }

    /// Atomically swap in the newly loaded listing for a same-directory
    /// reload. Until this runs, the existing `items` array remains on screen,
    /// so SwiftUI animates from the old listing to the new one without
    /// flashing an empty pane.
    private func commitPreservedReload(directory: URL) {
        let loadedItems = pendingLoadAccumulator
        pendingLoadAccumulator.removeAll(keepingCapacity: true)

        allItems = loadedItems
        allItemLookup = FileBrowserDirectoryState.itemLookup(for: allItems)
        refreshPreviewURLs()

        // `applyFiltersAndSortAsync(pruneAfterUpdate: true)` updates `items`
        // and prunes selection entries that no longer exist, mirroring the
        // non-preserving final-batch path.
        applyFiltersAndSortAsync(pruneAfterUpdate: true)
        lastLoadedDirectory = directory
    }
}

#endif
