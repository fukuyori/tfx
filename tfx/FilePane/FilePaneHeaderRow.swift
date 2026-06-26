#if os(macOS)
import SwiftUI

struct FilePaneHeaderRow: View {
    @ObservedObject var model: FileBrowserModel
    let visibleColumns: [FileListColumn]
    @Binding var columnWidths: FileListColumnWidths
    @State private var columnDragStart: (column: FileListColumn, width: Double)?
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

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
            Image(systemName: "arrow.left.and.right")
                .font(design.fonts.swiftUIFont(for: .caption, weight: .semibold))
                .foregroundStyle(theme.headerForeground.opacity(design.opacity.headerSecondary))
        }
        .frame(width: columnWidth(column), alignment: column.alignment)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
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
        .simultaneousGesture(
            TapGesture().onEnded { toggleSort(for: column) }
        )
        .help(column.sortKey == nil ? "Drag to resize column" : "Drag to resize column · Click to sort")
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
#endif
