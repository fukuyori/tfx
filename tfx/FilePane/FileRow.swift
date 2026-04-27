#if os(macOS)
import SwiftUI

struct FileRow: View {
    let item: FileItem
    let isSelected: Bool
    let isDropTarget: Bool
    let columns: [FileListColumn]
    let fileNameColumnWidth: Double

    var body: some View {
        HStack(spacing: 12) {
            ForEach(columns) { column in
                fileCell(for: column)
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(rowBackground)
    }

    @ViewBuilder
    private func fileCell(for column: FileListColumn) -> some View {
        switch column {
        case .icon:
            FileIcon(url: item.url, cacheKey: item.iconCacheKey)
                .frame(width: columnWidth(column), alignment: column.alignment)
        case .mode:
            Text(item.mode)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(item.isDirectory ? .cyan : .secondary)
        case .name:
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(item.isDirectory ? .cyan : .primary)
        case .size:
            Text(item.sizeText)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        case .kind:
            Text(item.kindText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        case .modified:
            Text(item.modifiedText)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        case .created:
            Text(item.createdText)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        case .permissions:
            Text(item.permissionsText)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        }
    }

    private func columnWidth(_ column: FileListColumn) -> CGFloat {
        column == .name ? CGFloat(fileNameColumnWidth) : column.defaultWidth
    }

    private var rowBackground: Color {
        if isDropTarget {
            return Color.green.opacity(0.55)
        }

        if isSelected {
            return Color.accentColor.opacity(0.55)
        }

        return Color.black
    }
}

#endif
