#if os(macOS)
import SwiftUI

struct FolderTreeExpansionButton: View {
    let isExpanded: Bool
    let showsExpansionControl: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard showsExpansionControl else { return }
            action()
        } label: {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
        }
        .buttonStyle(.plain)
        .frame(width: 14)
        .opacity(showsExpansionControl ? 1 : 0)
        .disabled(!showsExpansionControl)
        .help(isExpanded ? "Collapse" : "Expand")
    }
}

struct FolderTreeRowContextMenu: View {
    @ObservedObject var model: FileBrowserModel
    let url: URL
    let selectionSection: FolderTreeSelectionSection
    let allowsExpansion: Bool
    let activateTree: () -> Void

    var body: some View {
        Button("Open") {
            activateTree()
            model.selectFolderTree(url, in: selectionSection)
            model.navigate(to: url)
            if allowsExpansion {
                model.expandFolder(url)
            }
        }

        Button("Reveal in Finder") {
            model.revealInFinder(url)
        }

        Button("Copy Path") {
            model.copyPath(url)
        }

        Button(model.isFolderPinned(url) ? "Unpin Folder" : "Pin Folder") {
            activateTree()
            model.selectFolderTree(url, in: selectionSection)
            model.togglePinnedFolder(url)
        }

        Button("Open Terminal Here") {
            model.openTerminal(at: url)
        }
    }
}
#endif
