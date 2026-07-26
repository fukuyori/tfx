#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Sheet for choosing which editor "Edit Config File…" launches.
///
/// The choice persists as the app's bundle path in UserDefaults
/// (`ConfigFileEditor.editorDefaultsKey`); the "System Default" row
/// clears it so the OS file association decides again. Layout follows
/// `FileListSettingsView` so the two settings sheets read as one family.
struct EditorSettingsView: View {
    @AppStorage(ConfigFileEditor.editorDefaultsKey) private var configEditorPath = ""
    @Environment(\.design) private var design
    @Environment(\.dismiss) private var dismiss

    /// Snapshotted once — `ConfigFileEditor.editorCandidates()` hits
    /// LaunchServices, which is too slow to call on every body pass.
    @State private var candidates: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Editor Settings")
                    .font(design.fonts.swiftUIFont(for: .title, weight: .semibold))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Editor used by \"Edit Config File…\"")
                    .font(design.fonts.swiftUIFont(for: .header, weight: .semibold))
                    .foregroundStyle(.secondary)

                editorRow(
                    title: ConfigFileEditor.systemDefaultEditorName(),
                    icon: nil,
                    isSelected: configEditorPath.isEmpty
                ) {
                    configEditorPath = ""
                }

                ForEach(candidates, id: \.self) { appURL in
                    editorRow(
                        title: FileBrowserExternalActions.applicationDisplayName(appURL),
                        icon: FileBrowserExternalActions.applicationIcon(appURL),
                        isSelected: isSelected(appURL)
                    ) {
                        configEditorPath = appURL.path
                    }
                }
            }

            HStack {
                Button("Other…") {
                    chooseOtherApplication()
                }

                Spacer()
            }
        }
        .padding(18)
        .frame(width: 420)
        .onAppear {
            candidates = ConfigFileEditor.editorCandidates()
        }
    }

    private func isSelected(_ appURL: URL) -> Bool {
        !configEditorPath.isEmpty &&
        URL(fileURLWithPath: configEditorPath).standardizedFileURL == appURL.standardizedFileURL
    }

    private func editorRow(
        title: String,
        icon: NSImage?,
        isSelected: Bool,
        select: @escaping () -> Void
    ) -> some View {
        Button(action: select) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                }

                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .font(design.fonts.swiftUIFont(for: .fileList))
        .padding(.vertical, 3)
    }

    private func chooseOtherApplication() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = String(localized: "Choose")
        panel.message = String(localized: "Choose the editor used to open config.toml")

        guard panel.runModal() == .OK, let appURL = panel.url else { return }
        configEditorPath = appURL.path
        if !candidates.contains(where: { $0.standardizedFileURL == appURL.standardizedFileURL }) {
            candidates.insert(appURL, at: 0)
        }
    }
}
#endif
