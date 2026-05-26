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

    /// Update the insertion-slot preview during an external drag (a
    /// folder dragged from the file list over the pinned section).
    /// Reuses `pinnedFolderInsertionIndex` so the same expanding-slot
    /// animation used for reorder drag also applies here.
    ///
    /// `y` is in the coordinate space of the row-stack view that the
    /// `DropDelegate` is attached to (slots + rows). `rowHeight` is the
    /// nominal row height (matches the value used by the reorder drag).
    func updateExternalPinDropPreview(y: CGFloat, rowHeight: CGFloat) {
        guard rowHeight > 0 else { return }
        // SwiftUI ships a stray `dropUpdated` shortly after `performDrop`;
        // it appears to replay the last-known cursor position when the
        // drop target view re-renders due to the new pinned folder
        // entry landing. Without this suppression, that replay would
        // re-paint the accent line at the old insertion index even
        // though no drag is active.
        if let completedAt = pinnedExternalDropCompletedAt,
           Date().timeIntervalSince(completedAt) < Self.pinDropSuppressionWindow {
            return
        }
        let folderCount = pinnedFolders.count
        let rawIndex = Int((y / rowHeight).rounded())
        let clamped = min(max(rawIndex, 0), folderCount)
        if pinnedFolderInsertionIndex != clamped {
            pinnedFolderInsertionIndex = clamped
        }
    }

    /// Clear the external-drop slot preview. Called from `dropExited`
    /// or when the drop completes / fails.
    ///
    /// Also resets the in-section reorder gesture state so a latent
    /// `updateDraggedPinnedFolder` call (e.g. SwiftUI delivering a
    /// straggler `DragGesture.onChanged` after `performDrop`) cannot
    /// re-open the accent line. Without this, `originalIndex` stays set
    /// and the next gesture event recomputes the insertion index from
    /// the cursor position, repainting the slot after we just cleared
    /// it.
    func cancelExternalPinDropPreview() {
        if pinnedFolderInsertionIndex != nil {
            pinnedFolderInsertionIndex = nil
        }
        if pinnedFolderDrag.isActive {
            pinnedFolderDrag.reset()
        }
    }

    /// Accept a set of URLs as new pinned folders at `insertionIndex`.
    /// Non-directory URLs and ZIP-virtual entries are skipped silently.
    /// URLs already pinned are *moved* to the new position (treated as
    /// a reorder), matching Finder's sidebar behavior.
    func acceptExternalPinDrop(urls: [URL], at insertionIndex: Int) {
        var index = max(0, insertionIndex)
        var folders = pinnedFolders
        for url in urls {
            let folderURL = url.standardizedFileURL
            guard
                FileBrowserExternalActions.isDirectory(folderURL),
                ZipArchiveBrowser.location(for: folderURL) == nil
            else {
                continue
            }
            if let existing = folders.firstIndex(where: { $0.standardizedFileURL == folderURL }) {
                folders.remove(at: existing)
                if existing < index { index -= 1 }
            }
            folders.insert(folderURL, at: min(index, folders.count))
            index += 1
        }
        guard folders != pinnedFolders else { return }
        pinnedFolders = folders
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
        return pinnedFolderInsertionIndex == index
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
