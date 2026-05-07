#if os(macOS)
import Foundation

extension FileBrowserModel {
    func reload() {
        reloadGeneration += 1
        let generation = reloadGeneration
        let directory = currentDirectory
        let chunkSize = directoryLoadChunkSize
        let cancellation = resetDirectoryLoadState()

        if hasActiveSubfolderSearchQuery {
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
                    cancellation: cancellation
                )
            }
        )
    }

    private func resetDirectoryLoadState() -> DirectoryLoadCancellation {
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

        allItems = []
        allItemLookup = [:]
        items = []
        refreshPreviewURLs()
        availableCapacityText = "-"
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
            case let .failure(error):
                self.show(error)
                cancellation.cancel()
            }
        }
    }

    private func publishDirectoryBatch(
        _ batch: [FileItem],
        isFinalBatch: Bool,
        generation: Int,
        directory: URL,
        cancellation: DirectoryLoadCancellation
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

            self.appendLoadedDirectoryItems(batch, pruneAfterUpdate: isFinalBatch)
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
}

#endif
