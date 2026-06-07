#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FilePane: View {
    @ObservedObject var model: FileBrowserModel
    let paneID: BrowserPaneID
    let isActivePane: Bool
    let isKeyboardTarget: Bool
    @Binding var fileNameColumnWidth: Double
    let columnConfiguration: FileListColumnConfiguration
    let activate: () -> Void
    let executeUserCommand: (UserCommand, [FileItem]) -> Void
    let reloadRelatedPanes: () -> Void

    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    private var visibleColumns: [FileListColumn] {
        columnConfiguration.visibleOrderedColumns
    }

    private var rowMinWidth: CGFloat {
        let columnsWidth = visibleColumns.reduce(0) { partialResult, column in
            partialResult + columnWidth(column)
        }
        let spacingWidth = max(0, visibleColumns.count - 1) * 12
        return columnsWidth + CGFloat(spacingWidth) + 24
    }

    var body: some View {
        VStack(spacing: 0) {
            FilePaneTitleBar(
                model: model,
                paneID: paneID,
                isActivePane: isActivePane,
                isKeyboardTarget: isKeyboardTarget,
                activate: activate
            )

            // `GeometryReader` here absorbs the intrinsic minimum of
            // the file list content so it does not propagate up to the
            // pane's parent (and onward to the window). Inside the
            // reader we pin the content width to `max(rowMinWidth,
            // geometry.size.width)`: the rows always reserve enough
            // room for every visible column (no row-internal column
            // truncation), but the pane itself can be any width the
            // user has dragged it to — when the pane is narrower than
            // the rows, the surrounding `ScrollView(.horizontal)`
            // takes over and scrolls. Without this wrap, the bare
            // `.frame(minWidth: rowMinWidth)` makes SwiftUI report the
            // pane's minimum width as `rowMinWidth`, which is what
            // prevented the window from being shrunk below the total
            // column width.
            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    FilePaneFileList(
                        model: model,
                        isKeyboardTarget: isKeyboardTarget,
                        visibleColumns: visibleColumns,
                        fileNameColumnWidth: $fileNameColumnWidth,
                        activate: activate,
                        executeUserCommand: executeUserCommand
                    )
                    .frame(width: max(rowMinWidth, geometry.size.width))
                    .background(HorizontalScrollAccess(model: model))
                }
                .scrollIndicators(.visible, axes: .horizontal)
                .background(ScrollViewScrollerConfiguration(axes: .horizontal, autohidesScrollers: false))
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .onTapGesture {
                activate()
            }
            .onDrop(
                of: [UTType.fileURL.identifier],
                delegate: FileBrowserDropDelegate(
                    model: model,
                    targetDirectory: model.currentDirectory,
                    highlightedDirectory: nil,
                    reloadRelatedPanes: {
                        activate()
                    }
                )
            )
            .contextMenu {
                EmptyFileAreaContextMenu(
                    model: model,
                    activate: activate,
                    executeUserCommand: executeUserCommand
                )
            }

            FilePaneStatusLine(
                model: model,
                isKeyboardTarget: isKeyboardTarget,
                activate: activate
            )
        }
        .background(theme.fileListBackground.opacity(design.opacity.background))
        .overlay(
            // `strokeBorder` draws the stroke fully INSIDE the
            // frame; plain `stroke` straddles the edge (half
            // inside, half outside). With the NSHostingView's
            // `masksToBounds = true` and the file area starting
            // at window x=0 when the folder tree is hidden, the
            // outside-half clips to the window edge and the
            // inside-half is too thin to see — the left border
            // disappears entirely. `strokeBorder` keeps the line
            // fully painted regardless of where the pane sits.
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(
                    isKeyboardTarget
                        ? theme.paneBorderKeyboardTarget
                        : (isActivePane ? theme.paneBorderActive : theme.paneBorderInactive),
                    lineWidth: isKeyboardTarget ? 2 : 1
                )
        )
        .onAppear {
            model.prefetchVisibleMetadata(for: visibleColumns)
        }
        .onReceive(model.$items) { _ in
            model.prefetchVisibleMetadata(for: visibleColumns)
        }
        .onChange(of: columnConfiguration.rawValue) {
            model.prefetchVisibleMetadata(for: visibleColumns)
        }
    }

    private func columnWidth(_ column: FileListColumn) -> CGFloat {
        column == .name ? CGFloat(fileNameColumnWidth) : column.defaultWidth
    }
}

#endif
