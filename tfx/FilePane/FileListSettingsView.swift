#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct FileListSettingsView: View {
    @Binding var configurationRaw: String
    @Environment(\.design) private var design
    @Environment(\.dismiss) private var dismiss

    @State private var draggingColumn: FileListColumn?

    private var configuration: FileListColumnConfiguration {
        get {
            FileListColumnConfiguration(rawValue: configurationRaw)
        }
        nonmutating set {
            configurationRaw = newValue.rawValue
        }
    }

    /// Two-way binding into `configuration` that the drop
    /// delegate can mutate without going through the View's
    /// computed property.
    private var configurationBinding: Binding<FileListColumnConfiguration> {
        Binding(
            get: { self.configuration },
            set: { self.configuration = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("File List Settings")
                    .font(design.fonts.swiftUIFont(for: .title, weight: .semibold))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Columns")
                    .font(design.fonts.swiftUIFont(for: .header, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(Array(configuration.orderedColumns.enumerated()), id: \.element) { index, column in
                    columnSettingRow(for: column)
                        .opacity(draggingColumn == column ? 0.4 : 1)
                        .onDrag {
                            draggingColumn = column
                            return NSItemProvider(object: column.rawValue as NSString)
                        }
                        .onDrop(of: [UTType.text],
                                delegate: ColumnDropDelegate(
                                    targetIndex: index,
                                    draggingColumn: $draggingColumn,
                                    configuration: configurationBinding
                                ))
                }
                // Drop zone at the end of the list so the user can
                // drop a column past the last row (target index =
                // orderedColumns.count).
                Color.clear
                    .frame(height: 4)
                    .onDrop(of: [UTType.text],
                            delegate: ColumnDropDelegate(
                                targetIndex: configuration.orderedColumns.count,
                                draggingColumn: $draggingColumn,
                                configuration: configurationBinding
                            ))
            }

            HStack {
                Button("Reset") {
                    var updated = configuration
                    updated.reset()
                    configuration = updated
                }

                Spacer()
            }
        }
        .padding(18)
        .frame(width: 420)
    }

    private func columnSettingRow(for column: FileListColumn) -> some View {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: {
                    configuration.isVisible(column)
                },
                set: { isVisible in
                    var updated = configuration
                    updated.setVisible(isVisible, for: column)
                    configuration = updated
                }
            )) {
                Text(column.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(!column.canHide)

            Button {
                var updated = configuration
                updated.move(column, direction: -1)
                configuration = updated
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(configuration.orderedColumns.first == column)
            .help("Move up")

            Button {
                var updated = configuration
                updated.move(column, direction: 1)
                configuration = updated
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(configuration.orderedColumns.last == column)
            .help("Move down")
        }
        .font(design.fonts.swiftUIFont(for: .fileList))
        .padding(.vertical, 3)
    }
}

/// Receives a row drop and reorders the column configuration.
/// Hovering a row highlights nothing on its own — the dragged
/// row's reduced opacity is the visual cue — but drop processing
/// updates the configuration immediately on release.
private struct ColumnDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var draggingColumn: FileListColumn?
    @Binding var configuration: FileListColumnConfiguration

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text.identifier])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        validateDrop(info: info) ? DropProposal(operation: .move) : nil
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggingColumn = nil }
        guard let column = draggingColumn else { return false }
        var updated = configuration
        updated.move(column, to: targetIndex)
        configuration = updated
        return true
    }

    func dropExited(info: DropInfo) {
        // Keep `draggingColumn` set — entering a different row's
        // drop area should not clear the drag-source highlight.
    }
}
#endif
