#if os(macOS)
import Foundation

extension FileBrowserModel {
    /// Hover time before a collapsed tree row spring-expands during a
    /// file drag. Finder uses a similar sub-second delay.
    static let folderTreeSpringExpansionDelay: TimeInterval = 0.7

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
        // In-tree selections keep the viewport where it is; a
        // `navigate()` that follows (pinned click, DISKS click) flips
        // this back to true for the external-navigation top-anchor.
        folderTreeScrollsToTopOnChange = false
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
                updatesFolderTreeSelection: target.section == .tree,
                anchorsFolderTreeToTop: target.section != .tree
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
            updatesFolderTreeSelection: folderTreeSelectionSection == .tree,
            anchorsFolderTreeToTop: folderTreeSelectionSection != .tree
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

    /// Spring-loaded expansion while dragging files over a collapsed
    /// tree row: after hovering for a beat the row expands so the drag
    /// can continue into subfolders, like Finder's spring-loaded
    /// folders. The expansion only fires if the row is still the
    /// active drop target when the delay elapses.
    func scheduleFolderTreeSpringExpansion(of url: URL) {
        cancelFolderTreeSpringExpansion()
        let key = url.standardizedFileURL
        guard !isFolderExpanded(key) else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.folderTreeSpringExpansionWork = nil
            guard self.isDropTargetDirectory(key) else { return }
            self.expandFolder(key)
        }
        folderTreeSpringExpansionWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.folderTreeSpringExpansionDelay,
            execute: work
        )
    }

    func cancelFolderTreeSpringExpansion() {
        folderTreeSpringExpansionWork?.cancel()
        folderTreeSpringExpansionWork = nil
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
