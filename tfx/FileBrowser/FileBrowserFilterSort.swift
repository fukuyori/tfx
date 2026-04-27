#if os(macOS)
import Foundation

enum FileBrowserFilterSort {
    nonisolated static func filteredAndSortedItems(
        _ sourceItems: [FileItem],
        query: String,
        showsHiddenFiles: Bool,
        sortKey: FileSortKey,
        sortAscending: Bool,
        cancellation: FilterSortCancellation
    ) -> [FileItem]? {
        let filterStart = PerformanceTrace.now()
        var filteredItems: [FileItem] = []
        filteredItems.reserveCapacity(sourceItems.count)

        for (index, item) in sourceItems.enumerated() {
            if index.isMultiple(of: 256), cancellation.isCancelled {
                return nil
            }

            if (showsHiddenFiles || !item.isHidden)
                && (query.isEmpty || item.searchName.contains(query)) {
                filteredItems.append(item)
            }
        }

        guard !cancellation.isCancelled else { return nil }
        guard filteredItems.count > 1 else {
            PerformanceTrace.log("filter-sort", startedAt: filterStart, detail: "\(sourceItems.count)->\(filteredItems.count) items \(sortKey.rawValue)")
            return filteredItems
        }

        let sortedItems = filteredItems.sorted { lhs, rhs in
            compareForSort(lhs, rhs, sortKey: sortKey, sortAscending: sortAscending)
        }

        guard !cancellation.isCancelled else { return nil }
        PerformanceTrace.log("filter-sort", startedAt: filterStart, detail: "\(sourceItems.count)->\(sortedItems.count) items \(sortKey.rawValue)")
        return sortedItems
    }

    nonisolated private static func compareForSort(
        _ lhs: FileItem,
        _ rhs: FileItem,
        sortKey: FileSortKey,
        sortAscending: Bool
    ) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }

        let result: ComparisonResult

        switch sortKey {
        case .name:
            result = lhs.name.localizedStandardCompare(rhs.name)
        case .fastName:
            result = comparePlainStrings(lhs.searchName, rhs.searchName)
        case .size:
            result = lhs.size == rhs.size ? .orderedSame : (lhs.size < rhs.size ? .orderedAscending : .orderedDescending)
        case .kind:
            result = comparePlainStrings(lhs.kindSortKey, rhs.kindSortKey)
        case .modified:
            result = compareDates(lhs.modified, rhs.modified)
        case .created:
            result = compareDates(lhs.created, rhs.created)
        }

        if result == .orderedSame, sortKey != .name {
            return comparePlainStrings(lhs.searchName, rhs.searchName) == .orderedAscending
        }

        return sortAscending ? result == .orderedAscending : result == .orderedDescending
    }

    nonisolated private static func comparePlainStrings(_ lhs: String, _ rhs: String) -> ComparisonResult {
        if lhs == rhs {
            return .orderedSame
        }

        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    nonisolated private static func compareDates(_ lhs: Date?, _ rhs: Date?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            if lhs == rhs {
                return .orderedSame
            }
            return lhs < rhs ? .orderedAscending : .orderedDescending
        case (nil, nil):
            return .orderedSame
        case (nil, _):
            return .orderedAscending
        case (_, nil):
            return .orderedDescending
        }
    }
}

#endif
