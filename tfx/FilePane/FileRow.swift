#if os(macOS)
import SwiftUI

struct FileRow: View {
    let item: FileItem
    let isSelected: Bool
    let isDropTarget: Bool
    let columns: [FileListColumn]
    let fileNameColumnWidth: Double
    /// Git status for this row, looked up by the file pane before the
    /// view is constructed. Nil when the directory is not in a Git work
    /// tree, when the file is clean, or while the first status fetch
    /// after navigating into a repo is still in flight.
    let gitStatus: GitFileStatus?

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
            FileIcon(item: item)
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
        case .tags:
            tagsCell
                .frame(width: columnWidth(column), alignment: column.alignment)
        case .gitStatus:
            gitStatusCell
                .frame(width: columnWidth(column), alignment: column.alignment)
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

    /// Render the macOS Finder color tags assigned to this item as a row of
    /// small filled circles. Uncolored / unknown tags fall back to the
    /// secondary foreground so they remain visible without dominating.
    private var tagsCell: some View {
        HStack(spacing: 3) {
            ForEach(Array(item.tags.enumerated()), id: \.offset) { _, tag in
                Circle()
                    .fill(tag.color ?? Color.secondary)
                    .frame(width: 9, height: 9)
                    .help(tag.name)
            }
            Spacer(minLength: 0)
        }
    }

    /// Single-character Git status badge in the row's status color.
    /// Stays empty when the row carries no status, which is the common
    /// case both outside Git repos and for clean files inside them.
    @ViewBuilder
    private var gitStatusCell: some View {
        if let gitStatus {
            Text(gitStatus.badge)
                .foregroundStyle(gitStatus.color)
                .help(gitStatus.badge)
        } else {
            Color.clear
        }
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
