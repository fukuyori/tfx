#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct FilePaneHeaderRow: View {
    @ObservedObject var model: FileBrowserModel
    let visibleColumns: [FileListColumn]
    @Binding var columnWidths: FileListColumnWidths
    @State private var columnDragStart: (column: FileListColumn, width: Double)?
    // Column layout is app-wide state (same key the file lists read),
    // so the header's own `@AppStorage` mirror stays in sync with the
    // panes without extra plumbing.
    @AppStorage("TerminalFileManager.fileColumnConfiguration") private var columnConfigurationRaw = FileListColumnConfiguration.defaultRawValue
    @State private var isColumnSettingsPresented = false
    @State private var draggingColumn: FileListColumn?
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    /// Two-way binding into the persisted column configuration for the
    /// reorder drop delegate.
    private var configurationBinding: Binding<FileListColumnConfiguration> {
        Binding(
            get: { FileListColumnConfiguration(rawValue: columnConfigurationRaw) },
            set: { columnConfigurationRaw = $0.rawValue }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(visibleColumns) { column in
                headerCell(for: column)
            }
        }
        .font(design.fonts.swiftUIFont(for: .header, weight: .semibold))
        .foregroundStyle(theme.headerForeground)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.headerBackground.opacity(design.opacity.background))
        // Right-clicking the column header opens column controls
        // (Finder-style visibility checklist + the full settings
        // popup) instead of doing nothing.
        .contextMenu {
            columnVisibilityMenuItems
        }
        .popover(isPresented: $isColumnSettingsPresented, arrowEdge: .bottom) {
            FileListSettingsView(configurationRaw: $columnConfigurationRaw)
        }
    }

    /// Finder-style column checklist. Toggling a column here writes the
    /// same configuration the File List Settings popup edits.
    @ViewBuilder
    private var columnVisibilityMenuItems: some View {
        let configuration = FileListColumnConfiguration(rawValue: columnConfigurationRaw)
        ForEach(configuration.orderedColumns) { column in
            Toggle(isOn: Binding(
                get: {
                    FileListColumnConfiguration(rawValue: columnConfigurationRaw).isVisible(column)
                },
                set: { isVisible in
                    var updated = FileListColumnConfiguration(rawValue: columnConfigurationRaw)
                    updated.setVisible(isVisible, for: column)
                    columnConfigurationRaw = updated.rawValue
                }
            )) {
                Text(column.title)
            }
            .disabled(!column.canHide)
        }

        Divider()

        Button("File List Settings…") {
            isColumnSettingsPresented = true
        }
    }

    @ViewBuilder
    private func headerCell(for column: FileListColumn) -> some View {
        resizableHeaderCell(for: column)
    }

    private func resizableHeaderCell(for column: FileListColumn) -> some View {
        HStack(spacing: 4) {
            sortLabel(for: column)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            resizeHandle(for: column)
        }
        .frame(width: columnWidth(column), alignment: column.alignment)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded { toggleSort(for: column) }
        )
        .opacity(draggingColumn == column ? 0.4 : 1)
        // Drag the cell body to reorder columns; the trailing handle
        // keeps the resize drag. The payload string is unused — the
        // `draggingColumn` binding carries the source column, matching
        // `FileListSettingsView`'s row reordering.
        .onDrag {
            draggingColumn = column
            return NSItemProvider(object: column.rawValue as NSString)
        }
        .onDrop(of: [UTType.text], delegate: HeaderColumnDropDelegate(
            targetColumn: column,
            targetWidth: columnWidth(column),
            draggingColumn: $draggingColumn,
            configuration: configurationBinding
        ))
        .help(column.sortKey == nil ? "Drag to reorder column" : "Drag to reorder column · Click to sort")
    }

    /// Trailing width-resize grip. The resize drag lives here (with a
    /// padded hit area) rather than on the whole cell so the cell body
    /// is free for reorder drags.
    private func resizeHandle(for column: FileListColumn) -> some View {
        Image(systemName: "arrow.left.and.right")
            .font(design.fonts.swiftUIFont(for: .caption, weight: .semibold))
            .foregroundStyle(theme.headerForeground.opacity(design.opacity.headerSecondary))
            .padding(.horizontal, 3)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if columnDragStart?.column != column {
                            columnDragStart = (column, columnWidths.width(for: column))
                        }

                        let baseWidth = columnDragStart?.width ?? columnWidths.width(for: column)
                        columnWidths.setWidth(baseWidth + Double(value.translation.width), for: column)
                    }
                    .onEnded { _ in
                        columnDragStart = nil
                    }
            )
            .help("Drag to resize column")
    }

    /// Column-title label that also shows a `↑` / `↓` indicator
    /// when this column is the active sort column.
    @ViewBuilder
    private func sortLabel(for column: FileListColumn) -> some View {
        HStack(spacing: 4) {
            Text(column.headerTitle)
            if let key = column.sortKey, key == model.sortKey {
                Image(systemName: model.sortAscending ? "chevron.up" : "chevron.down")
                    .font(design.fonts.swiftUIFont(for: .caption, weight: .semibold))
            }
        }
    }

    /// Toggle sort: clicking the active sort column flips direction,
    /// clicking a different column switches the active key and
    /// resets to ascending.
    private func toggleSort(for column: FileListColumn) {
        guard let key = column.sortKey else { return }
        if model.sortKey == key {
            model.sortAscending.toggle()
        } else {
            model.sortKey = key
            model.sortAscending = true
        }
    }

    private func columnWidth(_ column: FileListColumn) -> CGFloat {
        CGFloat(columnWidths.width(for: column))
    }
}

/// Receives a header-cell drop and reorders the column configuration.
/// The drop position inside the target cell decides the side: left half
/// inserts the dragged column before the target, right half after it —
/// so dropping onto an immediate neighbor swaps them instead of being a
/// no-op.
private struct HeaderColumnDropDelegate: DropDelegate {
    let targetColumn: FileListColumn
    let targetWidth: CGFloat
    @Binding var draggingColumn: FileListColumn?
    @Binding var configuration: FileListColumnConfiguration

    func validateDrop(info: DropInfo) -> Bool {
        draggingColumn != nil && info.hasItemsConforming(to: [UTType.text.identifier])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        validateDrop(info: info) ? DropProposal(operation: .move) : nil
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggingColumn = nil }
        guard
            let column = draggingColumn,
            let targetIndex = configuration.orderedColumns.firstIndex(of: targetColumn)
        else {
            return false
        }

        let insertsAfterTarget = targetWidth > 0 && info.location.x > targetWidth / 2
        var updated = configuration
        updated.move(column, to: insertsAfterTarget ? targetIndex + 1 : targetIndex)
        configuration = updated
        return true
    }
}
#endif
