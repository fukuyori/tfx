#if os(macOS)
import AppKit
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
    let isEditingName: Bool
    let commitNameEdit: (String) -> Void
    let cancelNameEdit: () -> Void

    @Environment(\.design) private var design
    @Environment(\.theme) private var theme
    @State private var draftName = ""

    var body: some View {
        HStack(spacing: 12) {
            ForEach(columns) { column in
                fileCell(for: column)
            }
        }
        .font(design.fonts.swiftUIFont(for: .fileList))
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
                .foregroundStyle(item.isDirectory ? theme.directoryForeground : theme.secondaryForeground)
        case .name:
            nameCell
                .frame(width: columnWidth(column), alignment: column.alignment)
        case .size:
            Text(item.sizeText)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(theme.secondaryForeground)
        case .kind:
            Text(item.kindText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(theme.secondaryForeground)
        case .tags:
            tagsCell
                .frame(width: columnWidth(column), alignment: column.alignment)
        case .gitStatus:
            gitStatusCell
                .frame(width: columnWidth(column), alignment: column.alignment)
        case .modified:
            Text(item.modifiedText)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(theme.secondaryForeground)
        case .created:
            Text(item.createdText)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(theme.secondaryForeground)
        case .permissions:
            Text(item.permissionsText)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(theme.secondaryForeground)
        }
    }

    private func columnWidth(_ column: FileListColumn) -> CGFloat {
        column == .name ? CGFloat(fileNameColumnWidth) : column.defaultWidth
    }

    @ViewBuilder
    private var nameCell: some View {
        if isEditingName {
            InlineNameTextField(
                text: $draftName,
                textColor: NSColor(item.isDirectory ? theme.directoryForeground : theme.fileForeground),
                onCommit: {
                    commitNameEdit(draftName)
                },
                onCancel: {
                    cancelNameEdit()
                }
            )
            .frame(height: 18)
                .onAppear {
                    draftName = item.name
                }
                .onChange(of: isEditingName) {
                    if isEditingName {
                        draftName = item.name
                    }
                }
                .onChange(of: item.id) {
                    if isEditingName {
                        draftName = item.name
                    }
                }
        } else {
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(item.isDirectory ? theme.directoryForeground : theme.fileForeground)
        }
    }

    /// Render the macOS Finder color tags assigned to this item as a row of
    /// small filled circles. Uncolored / unknown tags fall back to the
    /// secondary foreground so they remain visible without dominating.
    private var tagsCell: some View {
        HStack(spacing: 3) {
            ForEach(Array(item.tags.enumerated()), id: \.offset) { _, tag in
                Circle()
                    .fill(tag.color ?? theme.secondaryForeground)
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
                .foregroundStyle(theme.color(for: gitStatus))
                .help(gitStatus.badge)
        } else {
            Color.clear
        }
    }

    private var rowBackground: Color {
        if isDropTarget {
            return theme.fileListRowDropTarget.opacity(design.opacity.background)
        }

        if isSelected {
            return theme.fileListRowSelected.opacity(design.opacity.background)
        }

        return .clear
    }
}

private struct InlineNameTextField: NSViewRepresentable {
    @Binding var text: String
    let textColor: NSColor
    let onCommit: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> CommitCancelTextField {
        let textField = CommitCancelTextField()
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.lineBreakMode = .byTruncatingMiddle
        textField.usesSingleLineMode = true
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        textField.delegate = context.coordinator
        context.coordinator.onCommit = onCommit
        context.coordinator.onCancel = onCancel
        textField.onTextChange = { value in
            if text != value {
                text = value
            }
        }
        textField.onCommit = onCommit
        textField.onCancel = onCancel
        return textField
    }

    func updateNSView(_ nsView: CommitCancelTextField, context: Context) {
        nsView.textColor = textColor
        context.coordinator.onCommit = onCommit
        context.coordinator.onCancel = onCancel
        nsView.onCommit = onCommit
        nsView.onCancel = onCancel
        nsView.onTextChange = { value in
            if text != value {
                text = value
            }
        }

        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if window.firstResponder !== nsView.currentEditor() {
                window.makeFirstResponder(nsView)
                nsView.currentEditor()?.selectAll(nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        var onCommit: (() -> Void)?
        var onCancel: (() -> Void)?

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            if text != textField.stringValue {
                text = textField.stringValue
            }
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                text = textView.string
                onCommit?()
                return true
            }

            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onCancel?()
                return true
            }

            return false
        }
    }
}

private final class CommitCancelTextField: NSTextField {
    var onTextChange: ((String) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        onTextChange?(stringValue)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            onCommit?()
        case 53:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }
}

#endif
