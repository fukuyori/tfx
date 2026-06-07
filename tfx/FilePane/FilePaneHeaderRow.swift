#if os(macOS)
import SwiftUI

struct FilePaneHeaderRow: View {
    @ObservedObject var model: FileBrowserModel
    let visibleColumns: [FileListColumn]
    @Binding var fileNameColumnWidth: Double
    @State private var nameColumnDragStartWidth: Double?
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
        if column == .name {
            HStack(spacing: 4) {
                sortLabel(for: column)
                Spacer(minLength: 4)
                Image(systemName: "arrow.left.and.right")
                    .font(design.fonts.swiftUIFont(for: .caption, weight: .semibold))
                    .foregroundStyle(theme.headerForeground.opacity(design.opacity.headerSecondary))
            }
            .frame(width: columnWidth(column), alignment: column.alignment)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if nameColumnDragStartWidth == nil {
                            nameColumnDragStartWidth = fileNameColumnWidth
                        }

                        let baseWidth = nameColumnDragStartWidth ?? fileNameColumnWidth
                        fileNameColumnWidth = clampFileNameColumnWidth(baseWidth + Double(value.translation.width))
                    }
                    .onEnded { _ in
                        nameColumnDragStartWidth = nil
                    }
            )
            .simultaneousGesture(
                // Tap fires only when the drag gesture above did NOT
                // engage (mouse released within the minimumDistance
                // threshold), so resize and click-to-sort coexist on
                // the same cell.
                TapGesture().onEnded { toggleSort(for: column) }
            )
            .help("Drag to resize file name column · Click to sort")
        } else if column.sortKey != nil {
            sortLabel(for: column)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .contentShape(Rectangle())
                .onTapGesture { toggleSort(for: column) }
                .help("Click to sort")
        } else {
            Text(column.headerTitle)
                .frame(width: columnWidth(column), alignment: column.alignment)
        }
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
        column == .name ? CGFloat(fileNameColumnWidth) : column.defaultWidth
    }

    private func clampFileNameColumnWidth(_ width: Double) -> Double {
        min(max(width, 160), 720)
    }
}
#endif
