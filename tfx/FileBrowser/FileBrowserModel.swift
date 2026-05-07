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
    @Published var errorTitle = "File operation failed"
    @Published var errorButtonTitle = "OK"
    @Published var errorMessage = ""
    @Published var searchText = "" {
        didSet {
            if isSubfolderSearchRunning {
                stopSubfolderSearch()
            }
        }
    }
    @Published var searchesSubfolders = false
    @Published var isSubfolderSearchRunning = false
    @Published var subfolderSearchDepth = 0
    @Published var subfolderSearchProcessedFolderCount = 0
    @Published var subfolderSearchSkippedFolderCount = 0
    @Published var subfolderSearchHitCount = 0
    @Published var showHiddenFiles = false {
        didSet {
            if !isSubfolderSearchRunning {
                applyFiltersAndSortImmediately()
            }
        }
    }
    @Published var sortKey = FileSortKey.fastName {
        didSet {
            if !isSubfolderSearchRunning {
                applyFiltersAndSortImmediately()
            }
        }
    }
    @Published var sortAscending = true {
        didSet {
            if !isSubfolderSearchRunning {
                applyFiltersAndSortImmediately()
            }
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
    var subfolderSearchWorkItem: DispatchWorkItem?
    var metadataPrefetchWorkItem: DispatchWorkItem?
    var errorDismissalHandler: (() -> Void)?
    var subfolderSearchResumeAfterError: (() -> Void)?
    var pendingFileSelectionURL: URL?
    private var pinnedFoldersObserver: AnyCancellable?
    private var fileOperationObserver: AnyCancellable?
    var directoryLoadCancellation: DirectoryLoadCancellation?
    var filterSortCancellation: FilterSortCancellation?
    var subfolderSearchCancellation: SubfolderSearchCancellation?
    var metadataPrefetchCancellation: MetadataPrefetchCancellation?
    var reloadGeneration = 0
    var filterGeneration = 0
    var subfolderSearchGeneration = 0
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
        show(error, title: "File operation failed", buttonTitle: "OK", onDismiss: nil)
    }

    func show(
        _ error: Error,
        title: String = "File operation failed",
        buttonTitle: String = "OK",
        onDismiss: (() -> Void)? = nil
    ) {
        errorTitle = title
        errorButtonTitle = buttonTitle
        errorMessage = error.localizedDescription
        errorDismissalHandler = onDismiss
        isShowingError = true
    }

    func dismissError() {
        guard isShowingError else { return }
        isShowingError = false
        let handler = errorDismissalHandler
        errorTitle = "File operation failed"
        errorButtonTitle = "OK"
        errorDismissalHandler = nil
        handler?()
    }
}

#endif
