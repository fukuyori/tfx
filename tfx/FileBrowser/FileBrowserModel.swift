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
    @Published var selectedItemIDs: Set<FileItem.ID> = []
    @Published var primarySelectedItemID: FileItem.ID?
    @Published var isParentDirectorySelected = false
    @Published var folderTreeSelection: URL?
    @Published var folderTreeSelectionSection: FolderTreeSelectionSection = .tree
    @Published var isShowingError = false
    @Published var errorTitle = String(localized: "File operation failed")
    @Published var errorButtonTitle = String(localized: "OK")
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
            refreshFolderTreeForHiddenFileSettingChange()
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
    /// True while a directory reload is still waiting for its first batch.
    /// The status line shows a "Loading…" hint when this stays true beyond
    /// a brief grace period, so users on slow network shares know that the
    /// app is doing something instead of looking at an empty pane.
    @Published var isLoadingDirectory = false
    @Published var pinnedFolders: [URL] = []
    @Published var pinnedFolderInsertionIndex: Int?
    @Published private(set) var highlightedDropDirectory: URL?
    /// True while a drag is hovering over the pane's empty area
    /// (rather than over a specific folder row). `FilePane` reads
    /// this to draw an extra drop-target border around the whole
    /// pane, giving the user the same kind of visual feedback
    /// that hovering a folder row already provides.
    @Published private(set) var isPaneDropTarget: Bool = false
    @Published var previewURLs: [URL] = []
    /// Latest Git status snapshot for `currentDirectory`. Nil when the
    /// directory is outside any Git work tree, when `git` is missing,
    /// or while the first status fetch for a freshly opened repo is
    /// still in flight. The file pane reads this to decorate rows and
    /// render the branch indicator in the status line.
    @Published var gitRepositoryStatus: GitRepositoryStatus?
    @Published var inlineNameEdit: InlineNameEdit?

    var allItems: [FileItem] = []
    var allItemLookup: [FileItem.ID: FileItem] = [:]
    var visibleItemIndexLookup: [FileItem.ID: Int] = [:]
    var navigationHistory = FileBrowserNavigationHistory()
    var selectionAnchorItemID: FileItem.ID?
    var mouseRangeSelectionState: FileMouseRangeSelectionState?
    var mouseBlankSelectionState: FileMouseBlankSelectionState?
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
    var currentDirectoryObserver: AnyCancellable?
    var directoryWatcher: DirectoryWatcher?
    var directoryLoadCancellation: DirectoryLoadCancellation?
    var filterSortCancellation: FilterSortCancellation?
    var subfolderSearchCancellation: SubfolderSearchCancellation?
    var metadataPrefetchCancellation: MetadataPrefetchCancellation?
    var gitStatusCancellation: GitStatusCancellation?
    /// Timestamp of the most recent successful pinned-folder external
    /// drop. While set within `Self.pinDropSuppressionWindow` of `now`,
    /// `updateExternalPinDropPreview` is a no-op so SwiftUI's spurious
    /// post-drop `dropUpdated` replays cannot re-open the accent line.
    var pinnedExternalDropCompletedAt: Date?
    static let pinDropSuppressionWindow: TimeInterval = 0.6
    /// Caches per-directory Git root resolution so re-entering a
    /// previously visited folder skips the `git rev-parse` cost. The
    /// optional value distinguishes "outside any work tree" (`.some(nil)`)
    /// from "not yet probed" (`absent`).
    var gitRootCache: [URL: URL?] = [:]
    var reloadGeneration = 0
    var filterGeneration = 0
    /// Last directory whose load completed. Drives differential reload detection.
    var lastLoadedDirectory: URL?
    /// Staging buffer for differential reloads; see `FileBrowserModel+Reload`.
    var pendingLoadAccumulator: [FileItem] = []
    /// Closure registered by the file pane's `HorizontalScrollAccess` view so
    /// the keyboard handler can drive horizontal scrolling without depending
    /// on SwiftUI's scroll view internals.
    var horizontalScrollHandler: ((CGFloat) -> Void)?

    /// Request a horizontal scroll on this pane's file list. No-op when the
    /// view hierarchy has not yet registered a handler.
    func scrollHorizontally(by delta: CGFloat) {
        horizontalScrollHandler?(delta)
    }
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
        // SwiftUI may construct this model from inside
        // `StateObject.Box.update`, which runs as part of the
        // view-update transaction. Any `@Published` write that
        // happens before this initializer returns is reported as
        // "Publishing changes from within view updates is not
        // allowed" and feeds back into an AttributeGraph cycle.
        //
        // Two mitigations:
        //   1. Initialize the storage of every `@Published` we
        //      touch here through its `_property = Published(...)`
        //      back door so the writes don't go through the
        //      publishing setter at all.
        //   2. Defer the rest of the startup work (`reload`,
        //      `expandAncestors`) to the next runloop tick via
        //      `DispatchQueue.main.async`; by then SwiftUI has
        //      finished its current update transaction and
        //      ordinary `@Published` writes are safe again.
        let standardized = initialDirectory.standardizedFileURL
        _currentDirectory = Published(initialValue: standardized)
        _folderTreeSelection = Published(initialValue: standardized)

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

                // Apply any URLs the originating pane reported
                // as removed (the source side of a cross-pane
                // move, a trash, etc.) immediately, so the row
                // disappears the moment the drop completes
                // rather than ~250 ms later when the directory
                // watcher fires a full reload. The subsequent
                // `reload()` still runs to catch any other
                // changes (renames, files added externally).
                let currentDir = self.currentDirectory.standardizedFileURL
                let removedInThisDir = change.removedURLs.filter {
                    $0.deletingLastPathComponent().standardizedFileURL == currentDir
                }
                if !removedInThisDir.isEmpty {
                    self.updateCurrentDirectoryItems(removing: Array(removedInThisDir))
                }
                self.reload()
            }
        currentDirectoryObserver = $currentDirectory
            .removeDuplicates()
            .sink { [weak self] newURL in
                self?.startWatchingDirectory(newURL)
            }
        loadPinnedFolders()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.reload()
            self.expandAncestors(of: self.currentDirectory)
        }
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

    func setPaneDropTarget(_ active: Bool) {
        guard isPaneDropTarget != active else { return }
        isPaneDropTarget = active
    }

    func show(_ error: Error) {
        show(error, title: String(localized: "File operation failed"), buttonTitle: String(localized: "OK"), onDismiss: nil)
    }

    func show(
        _ error: Error,
        title: String = String(localized: "File operation failed"),
        buttonTitle: String = String(localized: "OK"),
        onDismiss: (() -> Void)? = nil
    ) {
        errorTitle = title
        errorButtonTitle = buttonTitle
        errorMessage = Self.detailedDescription(of: error)
        errorDismissalHandler = onDismiss
        isShowingError = true
    }

    /// Build the message body for the error alert. The default
    /// `Error.localizedDescription` collapses Cocoa file errors into a
    /// short sentence that often drops the file path or the underlying
    /// reason (a NSCocoaErrorDomain `.fileReadNoSuchFile` reads as just
    /// "The file couldn't be opened.", for example). We walk
    /// `NSError.userInfo` so the dialog also shows the recovery
    /// suggestion, the chained underlying error, and the path that the
    /// operation tried to act on.
    private static func detailedDescription(of error: Error) -> String {
        let nsError = error as NSError
        var parts: [String] = [nsError.localizedDescription]
        if let recovery = nsError.localizedRecoverySuggestion {
            parts.append(recovery)
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            let underlyingText = underlying.localizedDescription
            if !underlyingText.isEmpty,
               !parts.joined(separator: "\n").contains(underlyingText) {
                parts.append(underlyingText)
            }
        }
        if let path = nsError.userInfo[NSFilePathErrorKey] as? String {
            parts.append(path)
        } else if let url = nsError.userInfo[NSURLErrorKey] as? URL {
            parts.append(url.path)
        }
        return parts.joined(separator: "\n")
    }

    func dismissError() {
        guard isShowingError else { return }
        isShowingError = false
        let handler = errorDismissalHandler
        errorTitle = String(localized: "File operation failed")
        errorButtonTitle = String(localized: "OK")
        errorDismissalHandler = nil
        handler?()
    }
}

#endif
