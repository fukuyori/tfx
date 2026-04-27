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

    func navigate(to directory: URL, recordsHistory: Bool = true, expandsTarget: Bool = true) {
        let target = directory.standardizedFileURL
        guard target != currentDirectory.standardizedFileURL else { return }

        if recordsHistory {
            navigationHistory.recordNavigation(from: currentDirectory)
        }

        currentDirectory = target
        folderTreeSelection = target
        folderTreeSelectionSection = .tree
        clearDropTargetDirectory(nil)
        clearSelection()
        expandAncestors(of: target)
        if expandsTarget {
            expandFolder(target)
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
        let parent = currentDirectory.deletingLastPathComponent()
        guard parent != currentDirectory else { return }
        navigate(to: parent)
    }
}

#endif
