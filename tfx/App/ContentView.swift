import SwiftUI

struct ContentView: View {
#if os(macOS)
    @EnvironmentObject private var designStore: DesignStore
    @EnvironmentObject private var shortcutStore: ShortcutStore
    @EnvironmentObject private var userCommandStore: UserCommandStore
    @EnvironmentObject private var previewConfigurationStore: PreviewConfigurationStore
#endif

    var body: some View {
#if os(macOS)
        TerminalFileManagerView()
            .environment(\.theme, designStore.activeTheme)
            .environment(\.design, designStore.activeDesign)
            .frame(minWidth: 980, minHeight: 640)
            .alert("Configuration Error", isPresented: Binding(
                get: { configurationError != nil },
                set: { isPresented in
                    if !isPresented {
                        dismissConfigurationErrors()
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    dismissConfigurationErrors()
                }
            } message: {
                Text(configurationError ?? "")
            }
#else
        ContentUnavailableView(
            "tfx is a macOS file manager",
            systemImage: "terminal",
            description: Text("Drag and drop, preview, and terminal integration require macOS.")
        )
        .padding()
#endif
    }

#if os(macOS)
    private var configurationError: String? {
        [
            designStore.configurationError,
            shortcutStore.configurationError,
            userCommandStore.configurationError,
            previewConfigurationStore.configurationError,
        ]
            .compactMap { $0 }
            .joined(separator: "\n\n")
            .nilIfEmpty
    }

    private func dismissConfigurationErrors() {
        designStore.dismissConfigurationError()
        shortcutStore.dismissConfigurationError()
        userCommandStore.dismissConfigurationError()
        previewConfigurationStore.dismissConfigurationError()
    }
#endif
}

#if os(macOS)
private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
#endif
