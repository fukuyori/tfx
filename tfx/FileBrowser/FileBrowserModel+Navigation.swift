#if os(macOS)
import Foundation

extension FileBrowserModel {
    var canGoBack: Bool {
        navigationHistory.canGoBack
    }

    var canGoForward: Bool {
        navigationHistory.canGoForward
    }

    var canGoUp: Bool {
        currentDirectory.deletingLastPathComponent() != currentDirectory
    }

    func navigate(
        to directory: URL,
        recordsHistory: Bool = true,
        expandsTarget: Bool = true,
        selecting selectionURL: URL? = nil,
        updatesFolderTreeSelection: Bool = true,
        anchorsFolderTreeToTop: Bool = true
    ) {
        let target = FileBrowserExternalActions.directoryURLForNavigation(directory) ?? directory.standardizedFileURL

        guard target != currentDirectory.standardizedFileURL else { return }

        // Set before any @Published write so the folder tree's
        // `.onChange` observers see the right anchor mode.
        folderTreeScrollsToTopOnChange = anchorsFolderTreeToTop

        if searchesSubfolders {
            searchesSubfolders = false
        } else {
            stopSubfolderSearch()
        }

        if !searchText.isEmpty {
            searchText = ""
        }

        if recordsHistory {
            navigationHistory.recordNavigation(from: currentDirectory)
        }

        currentDirectory = target
        if updatesFolderTreeSelection, ZipArchiveBrowser.location(for: target) == nil {
            folderTreeSelection = target
            folderTreeSelectionSection = .tree
        }
        clearDropTargetDirectory(nil)
        clearSelection()
        // A type-ahead prefix belongs to the listing it was typed in.
        typeSelectBuffer = ""
        typeSelectDisplayClearWork?.cancel()
        typeSelectDisplayClearWork = nil
        if !typeSelectDisplay.isEmpty {
            typeSelectDisplay = ""
        }
        pendingFileSelectionURL = selectionURL?.standardizedFileURL
        if ZipArchiveBrowser.location(for: target) == nil {
            // The folder tree mirrors the file listing: only the
            // path to the new target stays open, everything the
            // user expanded while browsing elsewhere collapses.
            collapseFoldersOutsidePath(to: target)
            expandAncestors(of: target)
            if expandsTarget {
                // Expand only — the `reload()` below scans the
                // same directory and seeds the folder-tree cache
                // from its results, so a separate `loadChildren`
                // enumeration would hit the disk twice.
                markFolderExpanded(target)
            }
        }
        reload()
    }

    func goBack() {
        guard let previous = navigationHistory.previous(from: currentDirectory) else { return }
        navigate(to: previous, recordsHistory: false)
    }

    func goForward() {
        guard let next = navigationHistory.next(from: currentDirectory) else { return }
        navigate(to: next, recordsHistory: false)
    }

    func goUp() {
        let previousDirectory = currentDirectory.standardizedFileURL
        let parent = previousDirectory.deletingLastPathComponent()
        guard parent != previousDirectory else { return }
        navigate(to: parent, selecting: previousDirectory)
    }
}

#endif
