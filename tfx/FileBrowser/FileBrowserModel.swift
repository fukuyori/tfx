#if os(macOS)
import AppKit
import Combine
import Foundation
import SwiftUI

final class FileBrowserModel: ObservableObject {
    @Published var currentDirectory = URL(fileURLWithPath: NSHomeDirectory())
    @Published var items: [FileItem] = [] {
        didSet {
            rebuildVisibleItemIndexes()
        }
    }
    @Published var selectedItemIDs: Set<FileItem.ID> = [] {
        didSet {
            refreshPreviewURLs()
        }
    }
    @Published var primarySelectedItemID: FileItem.ID?
    @Published var isParentDirectorySelected = false {
        didSet {
            refreshPreviewURLs()
        }
    }
    @Published var folderTreeSelection: URL?
    @Published var folderTreeSelectionSection: FolderTreeSelectionSection = .tree
    @Published var isShowingError = false
    @Published var errorMessage = ""
    @Published var searchText = "" {
        didSet {
            scheduleFilterAndSort()
        }
    }
    @Published var showHiddenFiles = false {
        didSet {
            applyFiltersAndSortImmediately()
        }
    }
    @Published var sortKey = FileSortKey.fastName {
        didSet {
            applyFiltersAndSortImmediately()
        }
    }
    @Published var sortAscending = true {
        didSet {
            applyFiltersAndSortImmediately()
        }
    }
    @Published var expandedFolders: Set<URL> = []
    @Published var folderChildrenCache: [URL: [URL]] = [:]
    @Published var availableCapacityText = "-"
    @Published var pinnedFolders: [URL] = []
    @Published var pinnedFolderInsertionIndex: Int?
    @Published private(set) var highlightedDropDirectory: URL?
    @Published var previewURLs: [URL] = []

    var allItems: [FileItem] = []
    var allItemLookup: [FileItem.ID: FileItem] = [:]
    var visibleItemIndexLookup: [FileItem.ID: Int] = [:]
    var navigationHistory = FileBrowserNavigationHistory()
    var selectionAnchorItemID: FileItem.ID?
    var clipboard: FileClipboard?
    var pinnedFolderDrag = FileBrowserPinnedFolderDrag()
    var filterWorkItem: DispatchWorkItem?
    var metadataPrefetchWorkItem: DispatchWorkItem?
    private var pinnedFoldersObserver: AnyCancellable?
    private var fileOperationObserver: AnyCancellable?
    var directoryLoadCancellation: DirectoryLoadCancellation?
    var filterSortCancellation: FilterSortCancellation?
    var metadataPrefetchCancellation: MetadataPrefetchCancellation?
    var reloadGeneration = 0
    var filterGeneration = 0
    var folderChildrenLoadGenerations: [URL: Int] = [:]
    var folderChildrenLoadQueue: [URL] = []
    var queuedFolderChildrenLoads: Set<URL> = []
    var activeFolderChildrenLoadCount = 0
    let maxConcurrentFolderChildrenLoads = 4
    let directoryLoadChunkSize = 300
    let modelID = UUID()
    let pinnedFoldersKey = "TerminalFileManager.pinnedFolders"

    init(initialDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        currentDirectory = initialDirectory.standardizedFileURL
        folderTreeSelection = currentDirectory
        pinnedFoldersObserver = NotificationCenter.default
            .publisher(for: .pinnedFoldersDidChange)
            .sink { [weak self] _ in
                self?.loadPinnedFolders()
        }
        fileOperationObserver = NotificationCenter.default
            .publisher(for: .fileManagerDirectoriesDidChange)
            .sink { [weak self] notification in
                guard
                    let self,
                    let change = notification.object as? FileOperationChange,
                    change.originModelID != self.modelID,
                    change.affectedDirectories.contains(self.currentDirectory.standardizedFileURL)
                else {
                    return
                }

                self.reload()
            }
        loadPinnedFolders()
        reload()
        expandAncestors(of: currentDirectory)
        expandFolder(currentDirectory)
    }

    func isDropTargetDirectory(_ url: URL) -> Bool {
        FileBrowserDropTargetState.isTarget(highlightedDropDirectory, matching: url)
    }

    func setDropTargetDirectory(_ url: URL?) {
        let nextTarget = FileBrowserDropTargetState.setting(url, current: highlightedDropDirectory)
        guard highlightedDropDirectory != nextTarget else { return }
        highlightedDropDirectory = nextTarget
    }

    func clearDropTargetDirectory(_ url: URL?) {
        let nextTarget = FileBrowserDropTargetState.clearing(url, current: highlightedDropDirectory)
        guard highlightedDropDirectory != nextTarget else { return }
        highlightedDropDirectory = nextTarget
    }

    func show(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }
}

#endif
