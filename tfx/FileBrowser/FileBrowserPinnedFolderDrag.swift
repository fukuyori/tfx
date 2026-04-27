#if os(macOS)
import CoreGraphics
import Foundation

struct FileBrowserPinnedFolderDrag {
    private(set) var folder: URL?
    private(set) var originalIndex: Int?

    var isActive: Bool {
        folder != nil
    }

    mutating func begin(folder url: URL, in pinnedFolders: [URL]) {
        let folderURL = url.standardizedFileURL
        guard folder != folderURL else { return }

        folder = folderURL
        originalIndex = pinnedFolders.firstIndex { $0.standardizedFileURL == folderURL }
    }

    func isDragging(_ url: URL) -> Bool {
        folder == url.standardizedFileURL
    }

    func insertionIndex(translationY: CGFloat, rowHeight: CGFloat, folderCount: Int) -> Int? {
        guard
            let originalIndex,
            rowHeight > 0,
            folderCount > 0
        else {
            return nil
        }

        let rowOffset = Int((translationY / rowHeight).rounded())
        let dropDirectionOffset = translationY > 0 ? 1 : 0
        return min(max(originalIndex + rowOffset + dropDirectionOffset, 0), folderCount)
    }

    mutating func reset() {
        folder = nil
        originalIndex = nil
    }
}

#endif
