#if os(macOS)
import Foundation

enum BrowserPaneID: String {
    case left
    case right

    var title: String {
        switch self {
        case .left:
            return "LEFT"
        case .right:
            return "RIGHT"
        }
    }
}

enum ActiveArea: String {
    case files
    case folderTree
}

enum FolderTreeSelectionSection: Hashable {
    case pinned
    case tree
}

struct FolderTreeRowID: Hashable {
    let url: URL
    let section: FolderTreeSelectionSection
}

enum FileListRowID: Hashable {
    case parentDirectory
    case item(URL)
}

struct DirectoryHeader {
    let urls: [URL]
    let availableCapacityText: String
}

enum FileSortKey: String, CaseIterable, Identifiable {
    case fastName
    case name
    case size
    case kind
    case modified
    case created

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .fastName:
            return "Name"
        case .name:
            return "Name (Natural)"
        case .size:
            return "Size"
        case .kind:
            return "Kind"
        case .modified:
            return "Modified"
        case .created:
            return "Created"
        }
    }
}

struct FileClipboard {
    enum Operation: Equatable {
        case copy
        case move
    }

    let urls: [URL]
    let operation: Operation
}

struct FileDropOperationResult {
    let destinationURL: URL
    let removedSourceURL: URL?
    let affectedDirectories: Set<URL>
}

struct FileMouseRangeSelectionState {
    let anchorItemID: FileItem.ID
    let originalSelectedItemIDs: Set<FileItem.ID>
    let addsToExistingSelection: Bool
}

struct FileMouseBlankSelectionState {
    let originalSelectedItemIDs: Set<FileItem.ID>
    let addsToExistingSelection: Bool
}

struct FileDragItem {
    let url: URL
    let iconCacheKey: String
}

enum FileConflictDecision {
    case use(URL, shouldReplace: Bool)
    case skip
    case cancel
}

enum ConflictResolution {
    case replace
    case keepBoth
    case skip
    case cancel
}
#endif
