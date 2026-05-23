#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct FolderTreeRow: View {
    @ObservedObject var model: FileBrowserModel
    let url: URL
    let depth: Int
    let isTreeActive: Bool
    let selectionSection: FolderTreeSelectionSection
    var allowsExpansion = true
    let activateTree: () -> Void
    @Environment(\.theme) private var theme

    private var isCurrent: Bool {
        model.currentDirectory.standardizedFileURL == url.standardizedFileURL
    }

    private var isSelected: Bool {
        model.isFolderTreeSelected(url, in: selectionSection)
    }

    private var isExpanded: Bool {
        model.isFolderExpanded(url)
    }

    private var hasChildFolders: Bool {
        model.hasFolderChildren(url)
    }

    private var showsExpansionControl: Bool {
        allowsExpansion && hasChildFolders
    }

    private var isDropTarget: Bool {
        model.isDropTargetDirectory(url)
    }

    var body: some View {
        VStack(spacing: 0) {
            rowContent

            if allowsExpansion && isExpanded {
                ForEach(model.childrenForFolder(url), id: \.self) { child in
                    FolderTreeRow(
                        model: model,
                        url: child,
                        depth: depth + 1,
                        isTreeActive: isTreeActive,
                        selectionSection: .tree,
                        activateTree: activateTree
                    )
                }
            }
        }
        .onChange(of: model.items) {
            if allowsExpansion && isExpanded && !model.isSubfolderSearchRunning {
                model.refreshFolderChildren(url)
            }
        }
        .onAppear {
            if allowsExpansion {
                model.refreshFolderChildrenIfNeeded(url)
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 6) {
            FolderTreeExpansionButton(
                isExpanded: isExpanded,
                showsExpansionControl: showsExpansionControl,
                action: {
                    activateTree()
                    model.selectFolderTree(url, in: selectionSection)
                    model.toggleFolderExpansion(url)
                }
            )

            Image(systemName: "folder")
                .foregroundStyle(theme.folderTreeFolderIcon)
                .frame(width: 16)

            Text(displayName(for: url))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle((isCurrent || isSelected) ? theme.folderTreeSelectedForeground : theme.folderTreeForeground)
        .padding(.leading, CGFloat(depth * 14 + 8))
        .padding(.trailing, 8)
        .padding(.vertical, 5)
        .background(rowBackground)
        .id(FolderTreeRowID(url: url, section: selectionSection))
        .contentShape(Rectangle())
        .onTapGesture {
            handleSingleClick()
        }
        .onTapGesture(count: 2) {
            handleDoubleClick()
        }
        .contextMenu {
            FolderTreeRowContextMenu(
                model: model,
                url: url,
                selectionSection: selectionSection,
                allowsExpansion: allowsExpansion,
                activateTree: activateTree
            )
        }
        .onDrop(
            of: [UTType.fileURL.identifier],
            delegate: FileBrowserDropDelegate(
                model: model,
                targetDirectory: url,
                highlightedDirectory: url,
                reloadRelatedPanes: {
                    activateTree()
                    model.selectFolderTree(url, in: selectionSection)
                }
            )
        )
    }

    private func displayName(for url: URL) -> String {
        FolderDisplayNameCache.shared.displayName(for: url)
    }

    private func handleSingleClick() {
        activateTree()
        model.selectFolderTree(url, in: selectionSection)
        model.expandAncestors(of: url)
        model.navigate(
            to: url,
            expandsTarget: false,
            updatesFolderTreeSelection: selectionSection == .tree
        )
    }

    private func handleDoubleClick() {
        activateTree()
        model.selectFolderTree(url, in: selectionSection)
        guard showsExpansionControl else { return }
        model.toggleFolderExpansion(url)
    }

    private var rowBackground: Color {
        if isDropTarget {
            return theme.fileListRowDropTarget
        }

        if isTreeActive && isSelected {
            return theme.folderTreeSelectedActive
        }

        if isSelected {
            return theme.folderTreeSelectedInactive
        }

        return theme.folderTreeBackground
    }
}
#endif
