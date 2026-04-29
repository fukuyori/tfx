#if os(macOS)
import Foundation

struct FileBrowserDirectoryItemsUpdate {
    let allItems: [FileItem]
    let allItemLookup: [FileItem.ID: FileItem]
    let selectedURLs: [URL]
    let shouldRefreshPreview: Bool
}

enum FileBrowserDirectoryState {
    static func itemLookup(for items: [FileItem]) -> [FileItem.ID: FileItem] {
        var lookup: [FileItem.ID: FileItem] = [:]
        lookup.reserveCapacity(items.count)
        for item in items {
            lookup[item.id.standardizedFileURL] = item
        }
        return lookup
    }

    static func visibleItemIndexLookup(for items: [FileItem]) -> [FileItem.ID: Int] {
        var lookup: [FileItem.ID: Int] = [:]
        lookup.reserveCapacity(items.count)
        for (index, item) in items.enumerated() {
            lookup[item.id.standardizedFileURL] = index
        }
        return lookup
    }

    static func selectedItems(from selectedItemIDs: Set<FileItem.ID>, lookup: [FileItem.ID: FileItem]) -> [FileItem] {
        selectedItemIDs
            .compactMap { lookup[$0.standardizedFileURL] }
            .sorted {
                $0.url.path < $1.url.path
            }
    }

    static func selectedVisibleItems(
        selectedItemIDs: Set<FileItem.ID>,
        allItemLookup: [FileItem.ID: FileItem],
        visibleItemIndexLookup: [FileItem.ID: Int]
    ) -> [FileItem] {
        selectedItemIDs
            .compactMap { id -> (index: Int, item: FileItem)? in
                let key = id.standardizedFileURL
                guard
                    let index = visibleItemIndexLookup[key],
                    let item = allItemLookup[key]
                else {
                    return nil
                }

                return (index, item)
            }
            .sorted { $0.index < $1.index }
            .map(\.item)
    }

    static func previewURLs(
        isParentDirectorySelected: Bool,
        selectedItemIDs: Set<FileItem.ID>,
        allItemLookup: [FileItem.ID: FileItem]
    ) -> [URL] {
        if isParentDirectorySelected {
            return []
        }

        return selectedItemIDs
            .compactMap { allItemLookup[$0.standardizedFileURL]?.url }
            .map { url in
                if ZipArchiveBrowser.canCopyFromArchive(url),
                   let materializedURL = try? ZipArchiveBrowser.materializedURL(for: url) {
                    return materializedURL
                }
                return url
            }
            .sorted {
                $0.path < $1.path
            }
    }

    static func applyingCurrentDirectoryChanges(
        allItems: [FileItem],
        currentDirectory: URL,
        adding addedURLs: [URL],
        removing removedURLs: [URL],
        selecting selectionURLs: [URL]
    ) -> FileBrowserDirectoryItemsUpdate {
        let removedIDs = Set(removedURLs.map { $0.standardizedFileURL })
        let addedItems = addedURLs
            .map(\.standardizedFileURL)
            .filter { $0.deletingLastPathComponent().standardizedFileURL == currentDirectory.standardizedFileURL }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map(FileItem.init)

        var nextItems = allItems
        var shouldRefreshPreview = false

        if !removedIDs.isEmpty {
            nextItems.removeAll { removedIDs.contains($0.id.standardizedFileURL) }
            shouldRefreshPreview = true
        }

        if !addedItems.isEmpty {
            let addedIDs = Set(addedItems.map { $0.id.standardizedFileURL })
            nextItems.removeAll { addedIDs.contains($0.id.standardizedFileURL) }
            nextItems.append(contentsOf: addedItems)
            shouldRefreshPreview = true
        }

        let selectedURLs = selectionURLs
            .map(\.standardizedFileURL)
            .filter { $0.deletingLastPathComponent().standardizedFileURL == currentDirectory.standardizedFileURL }

        return FileBrowserDirectoryItemsUpdate(
            allItems: nextItems,
            allItemLookup: itemLookup(for: nextItems),
            selectedURLs: selectedURLs,
            shouldRefreshPreview: shouldRefreshPreview
        )
    }
}

#endif
