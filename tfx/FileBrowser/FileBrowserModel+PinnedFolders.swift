#if os(macOS)
import CoreGraphics
import Foundation

extension FileBrowserModel {
    func isFolderPinned(_ url: URL) -> Bool {
        pinnedFolders.contains(url.standardizedFileURL)
    }

    func togglePinnedFolder(_ url: URL) {
        if isFolderPinned(url) {
            unpinFolder(url)
        } else {
            pinFolder(url)
        }
    }

    func pinFolder(_ url: URL) {
        let folderURL = url.standardizedFileURL
        guard FileBrowserExternalActions.isDirectory(folderURL), !isFolderPinned(folderURL) else { return }

        pinnedFolders.append(folderURL)
        savePinnedFolders()
    }

    func unpinFolder(_ url: URL) {
        let folderURL = url.standardizedFileURL
        pinnedFolders.removeAll { $0.standardizedFileURL == folderURL }
        savePinnedFolders()
    }

    func beginPinnedFolderDrag(_ url: URL) {
        pinnedFolderDrag.begin(folder: url, in: pinnedFolders)
    }

    var isDraggingPinnedFolder: Bool {
        pinnedFolderDrag.isActive
    }

    func isDraggingPinnedFolder(_ url: URL) -> Bool {
        pinnedFolderDrag.isDragging(url)
    }

    func isPinnedFolderInsertionSlotVisible(at index: Int) -> Bool {
        pinnedFolderInsertionIndex == index
    }

    func updateDraggedPinnedFolder(translationY: CGFloat, rowHeight: CGFloat) {
        pinnedFolderInsertionIndex = pinnedFolderDrag.insertionIndex(
            translationY: translationY,
            rowHeight: rowHeight,
            folderCount: pinnedFolders.count
        )
    }

    func finishPinnedFolderDrag(applyingMove: Bool = false) {
        if applyingMove, let draggedPinnedFolder = pinnedFolderDrag.folder, let pinnedFolderInsertionIndex {
            movePinnedFolder(draggedPinnedFolder, toInsertionIndex: pinnedFolderInsertionIndex)
        }

        pinnedFolderDrag.reset()
        pinnedFolderInsertionIndex = nil
    }

    func loadPinnedFolders() {
        pinnedFolders = FileBrowserFolderSupport.loadPinnedFolders(key: pinnedFoldersKey)
    }

    func savePinnedFolders() {
        FileBrowserFolderSupport.savePinnedFolders(pinnedFolders, key: pinnedFoldersKey)
    }

    private func movePinnedFolder(_ sourceURL: URL, toInsertionIndex insertionIndex: Int) {
        guard let reorderedFolders = FileBrowserFolderSupport.movingPinnedFolder(sourceURL, toInsertionIndex: insertionIndex, in: pinnedFolders) else { return }
        pinnedFolders = reorderedFolders
        savePinnedFolders()
    }
}
#endif
