#if os(macOS)
import Foundation

extension FileBrowserModel {
    func scheduleFilterAndSort(pruneAfterUpdate: Bool = true) {
        filterWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.applyFiltersAndSortAsync(pruneAfterUpdate: pruneAfterUpdate)
        }
        filterWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    func applyFiltersAndSortImmediately() {
        filterWorkItem?.cancel()
        filterWorkItem = nil
        applyFiltersAndSortAsync(pruneAfterUpdate: true)
    }

    func applyFiltersAndSortAsync(pruneAfterUpdate: Bool) {
        filterGeneration += 1
        let generation = filterGeneration
        filterSortCancellation?.cancel()
        let cancellation = FilterSortCancellation()
        filterSortCancellation = cancellation
        let sourceItems = allItems
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        let showsHiddenFiles = showHiddenFiles
        let key = sortKey
        let ascending = sortAscending

        DispatchQueue.global(qos: .userInitiated).async {
            let filteredItems = FileBrowserFilterSort.filteredAndSortedItems(
                sourceItems,
                query: query,
                showsHiddenFiles: showsHiddenFiles,
                sortKey: key,
                sortAscending: ascending,
                cancellation: cancellation
            )

            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    self.filterGeneration == generation,
                    !cancellation.isCancelled,
                    let filteredItems
                else {
                    return
                }

                self.items = filteredItems
                if pruneAfterUpdate {
                    self.pruneSelection()
                }
            }
        }
    }
}

#endif
