#if os(macOS)
import SwiftUI

struct FilePaneHeaderRow: View {
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
                Text(column.headerTitle)
                Spacer(minLength: 4)
                Image(systemName: "arrow.left.and.right")
                    .font(design.fonts.swiftUIFont(for: .caption, weight: .semibold))
                    .foregroundStyle(theme.headerForeground.opacity(design.opacity.headerSecondary))
            }
            .frame(width: columnWidth(column), alignment: column.alignment)
            .contentShape(Rectangle())
            .cursor(.resizeLeftRight)
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
            .help("Drag to resize file name column")
        } else {
            Text(column.headerTitle)
                .frame(width: columnWidth(column), alignment: column.alignment)
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
