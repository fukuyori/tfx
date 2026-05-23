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
    let reloadRelatedPanes: () -> Void

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

            ScrollView(.horizontal) {
                FilePaneFileList(
                    model: model,
                    isKeyboardTarget: isKeyboardTarget,
                    visibleColumns: visibleColumns,
                    fileNameColumnWidth: $fileNameColumnWidth,
                    activate: activate
                )
                .frame(minWidth: rowMinWidth)
                .background(HorizontalScrollAccess(model: model))
            }
            .scrollIndicators(.visible, axes: .horizontal)
            .background(ScrollViewScrollerConfiguration(axes: .horizontal, autohidesScrollers: false))
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
                EmptyFileAreaContextMenu(model: model, activate: activate)
            }

            FilePaneStatusLine(
                model: model,
                isKeyboardTarget: isKeyboardTarget,
                activate: activate
            )
        }
        .background(theme.fileListBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(
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
