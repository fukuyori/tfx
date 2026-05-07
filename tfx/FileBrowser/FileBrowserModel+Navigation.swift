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
        updatesFolderTreeSelection: Bool = true
    ) {
        let target = directory.standardizedFileURL

        if searchesSubfolders {
            searchesSubfolders = false
        } else {
            stopSubfolderSearch()
        }

        guard target != currentDirectory.standardizedFileURL else { return }

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
        pendingFileSelectionURL = selectionURL?.standardizedFileURL
        if ZipArchiveBrowser.location(for: target) == nil {
            expandAncestors(of: target)
            if expandsTarget {
                expandFolder(target)
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
