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

        let rowOffset = translationY / rowHeight
        guard abs(rowOffset) >= 0.5 else {
            return originalIndex
        }

        let insertionIndex: Int
        if rowOffset > 0 {
            insertionIndex = originalIndex + Int(floor(rowOffset + 0.5)) + 1
        } else {
            insertionIndex = originalIndex + Int(ceil(rowOffset - 0.5))
        }

        let clampedIndex = min(max(insertionIndex, 0), folderCount)
        if clampedIndex == originalIndex || clampedIndex == originalIndex + 1 {
            return nil
        }
        return clampedIndex
    }

    mutating func reset() {
        folder = nil
        originalIndex = nil
    }
}

#endif
