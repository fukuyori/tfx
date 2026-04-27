#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct FilePaneFileList: View {
    @ObservedObject var model: FileBrowserModel
    let isKeyboardTarget: Bool
    let visibleColumns: [FileListColumn]
    @Binding var fileNameColumnWidth: Double
    let activate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            FilePaneHeaderRow(
                visibleColumns: visibleColumns,
                fileNameColumnWidth: $fileNameColumnWidth
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        parentDirectoryRow
                        fileRows
                    }
                }
                .onChange(of: model.selectedFileListRowID) {
                    scrollToSelection(with: proxy)
                }
                .onChange(of: isKeyboardTarget) {
                    if isKeyboardTarget {
                        scrollToSelection(with: proxy)
                    }
                }
            }
            .background(Color.black)
        }
    }

    private var parentDirectoryRow: some View {
        ParentDirectoryRow(
            isEnabled: model.canGoUp,
            isSelected: model.isParentDirectorySelected,
            columns: visibleColumns,
            fileNameColumnWidth: fileNameColumnWidth
        )
        .id(FileListRowID.parentDirectory)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    activate()
                    model.selectParentDirectory()
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    activate()
                    model.selectParentDirectory()
                    model.goUp()
                }
        )
    }

    private var fileRows: some View {
        ForEach(model.items) { item in
            FileRow(
                item: item,
                isSelected: model.isSelected(item),
                isDropTarget: item.isDirectory && model.isDropTargetDirectory(item.url),
                columns: visibleColumns,
                fileNameColumnWidth: fileNameColumnWidth
            )
            .id(FileListRowID.item(item.id))
            .contentShape(Rectangle())
            .overlay(
                FileRowInteractionOverlay(
                    item: item,
                    model: model,
                    activate: activate
                )
            )
            .onDrop(
                of: [UTType.fileURL.identifier],
                delegate: FileBrowserDropDelegate(
                    model: model,
                    targetDirectory: item.isDirectory ? item.url : model.currentDirectory,
                    highlightedDirectory: item.isDirectory ? item.url : nil,
                    reloadRelatedPanes: {
                        activate()
                    }
                )
            )
            .contextMenu {
                FileItemContextMenu(
                    model: model,
                    item: item,
                    activate: activate
                )
            }
        }
    }

    private func scrollToSelection(with proxy: ScrollViewProxy) {
        guard let rowID = model.selectedFileListRowID else { return }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.08)) {
                proxy.scrollTo(rowID)
            }
        }
    }
}

#endif
