#if os(macOS)
import SwiftUI

struct FileListSettingsView: View {
    @Binding var configurationRaw: String
    @Environment(\.design) private var design
    @Environment(\.dismiss) private var dismiss

    private var configuration: FileListColumnConfiguration {
        get {
            FileListColumnConfiguration(rawValue: configurationRaw)
        }
        nonmutating set {
            configurationRaw = newValue.rawValue
        }
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

                ForEach(configuration.orderedColumns) { column in
                    columnSettingRow(for: column)
                }
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
#endif
