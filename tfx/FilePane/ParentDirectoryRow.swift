#if os(macOS)
import SwiftUI

struct ParentDirectoryRow: View {
    let isEnabled: Bool
    let isSelected: Bool
    let columns: [FileListColumn]
    let fileNameColumnWidth: Double

    var body: some View {
        HStack(spacing: 12) {
            ForEach(columns) { column in
                parentCell(for: column)
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(isSelected ? Color.green.opacity(0.35) : Color.black)
        .opacity(isEnabled ? 1 : 0.45)
    }

    @ViewBuilder
    private func parentCell(for column: FileListColumn) -> some View {
        switch column {
        case .icon:
            Image(systemName: "arrow.turn.up.left")
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(isEnabled ? .cyan : .secondary)
        case .mode:
            Text("drwx")
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(isEnabled ? .cyan : .secondary)
        case .name:
            Text("..")
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(isEnabled ? .cyan : .secondary)
        case .size:
            Text("-")
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        case .kind:
            Text("Parent Folder")
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
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
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        }
    }

    private func columnWidth(_ column: FileListColumn) -> CGFloat {
        column == .name ? CGFloat(fileNameColumnWidth) : column.defaultWidth
    }
}
#endif
