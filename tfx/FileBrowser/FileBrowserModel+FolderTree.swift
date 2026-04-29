#if os(macOS)
import Foundation

extension FileBrowserModel {
    var selectedFolderTreeURL: URL {
        folderTreeSelection ?? currentDirectory
    }

    var selectedFolderTreeRowID: FolderTreeRowID {
        FolderTreeRowID(url: selectedFolderTreeURL.standardizedFileURL, section: folderTreeSelectionSection)
    }

    func isFolderExpanded(_ url: URL) -> Bool {
        expandedFolders.contains(url.standardizedFileURL)
    }

    func hasFolderChildren(_ url: URL) -> Bool {
        childrenForFolder(url).isEmpty == false
    }

    func isFolderTreeSelected(_ url: URL, in section: FolderTreeSelectionSection) -> Bool {
        FileBrowserFolderSupport.isSelected(
            url: url,
            section: section,
            selectedURL: selectedFolderTreeURL,
            selectedSection: folderTreeSelectionSection
        )
    }

    func selectFolderTree(_ url: URL, in section: FolderTreeSelectionSection) {
        folderTreeSelection = url.standardizedFileURL
        folderTreeSelectionSection = section
        clearDropTargetDirectory(nil)
    }

    func ensureFolderTreeSelection() {
        expandAncestors(of: currentDirectory)
        if let target = FileBrowserFolderSupport.fallbackSelection(
            selectedURL: selectedFolderTreeURL,
            selectedSection: folderTreeSelectionSection,
            currentDirectory: currentDirectory,
            pinnedFolders: pinnedFolders,
            foldersForSection: { [weak self] section in self?.visibleFolderTreeFolders(in: section) ?? [] }
        ) {
            selectFolderTree(target.url, in: target.section)
        }
    }

    func moveFolderTreeSelection(delta: Int) {
        let folders = visibleFolderTreeFolders(in: folderTreeSelectionSection)
        if let target = FileBrowserFolderSupport.nextSelection(
            folders: folders,
            selectedURL: selectedFolderTreeURL,
            section: folderTreeSelectionSection,
            delta: delta
        ) {
            selectFolderTree(target.url, in: target.section)
            expandAncestors(of: target.url)
            navigate(
                to: target.url,
                expandsTarget: false,
                updatesFolderTreeSelection: target.section == .tree
            )
        }
    }

    func moveFolderTreeLeft() {
        guard folderTreeSelectionSection == .tree else { return }
        let selectedURL = selectedFolderTreeURL.standardizedFileURL

        if isFolderExpanded(selectedURL) {
            toggleFolderExpansion(selectedURL)
            return
        }

        let parent = selectedURL.deletingLastPathComponent()
        guard parent != selectedURL else { return }
        expandAncestors(of: parent)
        selectFolderTree(parent, in: .tree)
    }

    func moveFolderTreeRight() {
        guard folderTreeSelectionSection == .tree else { return }
        let selectedURL = selectedFolderTreeURL.standardizedFileURL

        if !isFolderExpanded(selectedURL) {
            expandFolder(selectedURL)
            return
        }

        if let firstChild = childrenForFolder(selectedURL).first {
            selectFolderTree(firstChild, in: .tree)
        }
    }

    func activateFolderTreeSelection() {
        let selectedURL = selectedFolderTreeURL.standardizedFileURL
        guard FileBrowserExternalActions.isDirectory(selectedURL) else { return }
        expandAncestors(of: selectedURL)
        navigate(
            to: selectedURL,
            expandsTarget: false,
            updatesFolderTreeSelection: folderTreeSelectionSection == .tree
        )
        if folderTreeSelectionSection == .tree {
            toggleFolderExpansion(selectedURL)
        }
    }

    func visibleFolderTreeFolders(in section: FolderTreeSelectionSection) -> [URL] {
        switch section {
        case .pinned:
            return pinnedFolders
        case .tree:
            return visibleDefaultTreeFolders()
        }
    }

    func expandAncestors(of url: URL) {
        for ancestor in FileBrowserFolderSupport.ancestors(of: url) {
            expandFolder(ancestor)
        }
    }

    private func visibleDefaultTreeFolders() -> [URL] {
        FileBrowserFolderSupport.visibleFolders(
            roots: FileBrowserFolderSupport.defaultTreeRoots(),
            isExpanded: { [weak self] url in self?.isFolderExpanded(url) == true },
            children: { [weak self] url in self?.childrenForFolder(url) ?? [] }
        )
    }
}

#endif
