#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct FilePaneFileList: View {
    private let rowHeight: CGFloat = 26

    @ObservedObject var model: FileBrowserModel
    let isKeyboardTarget: Bool
    let visibleColumns: [FileListColumn]
    @Binding var fileNameColumnWidth: Double
    let activate: () -> Void
    let executeUserCommand: (UserCommand, [FileItem]) -> Void
    @State private var blankSelectionStartY: CGFloat?
    var body: some View {
        // Outer alignment is `.leading` so the column-header row hugs
        // the left edge of the pane; without it, `VStack`'s default
        // `.center` parks the row in the middle of any pane wider than
        // the row itself.
        VStack(alignment: .leading, spacing: 0) {
            FilePaneHeaderRow(
                model: model,
                visibleColumns: visibleColumns,
                fileNameColumnWidth: $fileNameColumnWidth
            )

            ScrollViewReader { proxy in
                GeometryReader { geometry in
                    ScrollView {
                        // `alignment: .leading` keeps each file row
                        // pinned to the left edge of the pane (matching
                        // the header) instead of centering it.
                        LazyVStack(alignment: .leading, spacing: 0) {
                            parentDirectoryRow
                            fileRows
                        }
                        .frame(minHeight: geometry.size.height, alignment: .topLeading)
                        .contentShape(Rectangle())
                        .coordinateSpace(name: "file-list-content")
                        .simultaneousGesture(fileRangeSelectionGesture)
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
        }
    }

    private var fileRangeSelectionGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("file-list-content"))
            .onChanged { value in
                guard blankSelectionStartY != nil || isBlankArea(y: value.startLocation.y) else {
                    return
                }

                activate()
                if blankSelectionStartY == nil {
                    blankSelectionStartY = value.startLocation.y
                    model.beginMouseBlankSelection(modifiers: NSEvent.modifierFlags)
                }

                guard let startY = blankSelectionStartY else { return }
                model.updateMouseBlankSelection(itemIndexes: itemIndexRange(from: startY, to: value.location.y))
            }
            .onEnded { _ in
                blankSelectionStartY = nil
                model.finishMouseBlankSelection()
            }
    }

    private func isBlankArea(y: CGFloat) -> Bool {
        y >= rowAreaHeight
    }

    private var rowAreaHeight: CGFloat {
        CGFloat((model.canGoUp ? 1 : 0) + model.items.count) * rowHeight
    }

    private func itemIndexRange(from startY: CGFloat, to currentY: CGFloat) -> ClosedRange<Int>? {
        let parentOffset = model.canGoUp ? 1 : 0
        guard !model.items.isEmpty else { return nil }

        let lowerY = max(0, min(startY, currentY))
        let upperY = max(startY, currentY)
        let firstRow = Int(floor(lowerY / rowHeight))
        let lastRow = Int(floor(max(lowerY, upperY - 0.5) / rowHeight))
        let firstItemIndex = max(0, firstRow - parentOffset)
        let lastItemIndex = min(model.items.count - 1, lastRow - parentOffset)

        guard firstItemIndex <= lastItemIndex else { return nil }
        return firstItemIndex...lastItemIndex
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
            let isEditingName = model.inlineNameEdit?.url == item.url.standardizedFileURL
            FileRow(
                item: item,
                isSelected: model.isSelected(item),
                isDropTarget: item.isDirectory && model.isDropTargetDirectory(item.url),
                columns: visibleColumns,
                fileNameColumnWidth: fileNameColumnWidth,
                gitStatus: model.gitStatus(for: item),
                isEditingName: isEditingName,
                commitNameEdit: { model.commitInlineNameEdit(text: $0) },
                cancelNameEdit: model.cancelInlineNameEdit
            )
            .id(FileListRowID.item(item.id))
            .contentShape(Rectangle())
            .overlay {
                if !isEditingName {
                    FileRowInteractionOverlay(
                        item: item,
                        model: model,
                        activate: activate
                    )
                }
            }
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
                // Always show the per-row menu for file rows. The
                // `FileRowInteractionView.rightMouseDown` handler already
                // activates the pane and selects the right-clicked row
                // (preserving an existing multi-selection that includes it),
                // so the menu actions operate on the expected target. The
                // empty-area menu is attached to the file pane background in
                // `FilePane`, so right-clicks outside any row still reach it.
                FileItemContextMenu(
                    model: model,
                    item: item,
                    activate: activate,
                    executeUserCommand: executeUserCommand
                )
            }
        }
    }

    private func scrollToSelection(with proxy: ScrollViewProxy) {
        guard let rowID = model.selectedFileListRowID else { return }
        // `DispatchQueue.main.async` (not `Task { ... Task.yield() }`)
        // because `ScrollViewProxy.scrollTo` rejects calls made
        // during a view update with `Fatal error: ScrollViewProxy
        // may not be accessed during view updates`. Only the
        // GCD-style next-runloop-tick deferral reliably lands
        // outside SwiftUI's current update transaction; an
        // `await Task.yield()` resume can still surface inside
        // the same update phase.
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.08)) {
                proxy.scrollTo(rowID)
            }
        }
    }
}

#endif
