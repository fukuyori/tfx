#if os(macOS)
import Foundation

enum FileBrowserFolderSupport {
    struct SelectionTarget {
        let url: URL
        let section: FolderTreeSelectionSection
    }

    static func isSelected(
        url: URL,
        section: FolderTreeSelectionSection,
        selectedURL: URL,
        selectedSection: FolderTreeSelectionSection
    ) -> Bool {
        selectedSection == section && selectedURL.standardizedFileURL == url.standardizedFileURL
    }

    static func nextSelection(
        folders: [URL],
        selectedURL: URL,
        section: FolderTreeSelectionSection,
        delta: Int
    ) -> SelectionTarget? {
        guard !folders.isEmpty else { return nil }

        let selectedKey = selectedURL.standardizedFileURL
        let currentIndex = folders.firstIndex { $0.standardizedFileURL == selectedKey } ?? (delta >= 0 ? -1 : folders.count)
        let nextIndex = FileBrowserSelectionSupport.clampedIndex(currentIndex + delta, count: folders.count)
        return SelectionTarget(url: folders[nextIndex], section: section)
    }

    static func fallbackSelection(
        selectedURL: URL,
        selectedSection: FolderTreeSelectionSection,
        currentDirectory: URL,
        pinnedFolders: [URL],
        foldersForSection: (FolderTreeSelectionSection) -> [URL]
    ) -> SelectionTarget? {
        if foldersForSection(selectedSection).contains(selectedURL.standardizedFileURL) {
            return nil
        }

        if selectedSection == .pinned, let firstPinnedFolder = pinnedFolders.first {
            return SelectionTarget(url: firstPinnedFolder, section: .pinned)
        }

        let folders = foldersForSection(.tree)
        if folders.contains(currentDirectory.standardizedFileURL) {
            return SelectionTarget(url: currentDirectory, section: .tree)
        }

        if let firstFolder = folders.first {
            return SelectionTarget(url: firstFolder, section: .tree)
        }

        return nil
    }
}

#endif
