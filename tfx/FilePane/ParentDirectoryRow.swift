#if os(macOS)
import SwiftUI

struct ParentDirectoryRow: View {
    let isEnabled: Bool
    let isSelected: Bool
    let columns: [FileListColumn]
    let columnWidths: FileListColumnWidths
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(columns) { column in
                parentCell(for: column)
            }
        }
        .font(design.fonts.swiftUIFont(for: .fileList))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(parentBackground)
        .opacity(isEnabled ? 1 : design.opacity.disabledItem)
    }

    @ViewBuilder
    private func parentCell(for column: FileListColumn) -> some View {
        switch column {
        case .icon:
            Image(systemName: "arrow.turn.up.left")
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(isEnabled ? theme.directoryForeground : theme.secondaryForeground)
        case .mode:
            Text("drwx")
                .lineLimit(1)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .clipped()
                .foregroundStyle(isEnabled ? theme.directoryForeground : theme.secondaryForeground)
        case .name:
            Text("..")
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .clipped()
                .foregroundStyle(isEnabled ? theme.directoryForeground : theme.secondaryForeground)
        case .size:
            Text("-")
                .lineLimit(1)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .clipped()
                .foregroundStyle(theme.secondaryForeground)
        case .kind:
            Text("Parent Folder")
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .clipped()
                .foregroundStyle(theme.secondaryForeground)
        case .tags:
            // The parent placeholder row never carries macOS Finder tags.
            Color.clear
                .frame(width: columnWidth(column), alignment: column.alignment)
        case .gitStatus:
            // ".." has no meaningful Git status — leave the cell blank
            // so the column stays aligned with the file rows below.
            Color.clear
                .frame(width: columnWidth(column), alignment: column.alignment)
        case .modified, .created, .permissions:
            Text("-")
                .lineLimit(1)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .clipped()
                .foregroundStyle(theme.secondaryForeground)
        }
    }

    private func columnWidth(_ column: FileListColumn) -> CGFloat {
        CGFloat(columnWidths.width(for: column))
    }

    private var parentBackground: Color {
        isSelected
            ? theme.folderTreeSelectedActive
                .opacity(design.opacity.selectedParentRow)
                .opacity(design.opacity.background)
            : .clear
    }
}
#endif
