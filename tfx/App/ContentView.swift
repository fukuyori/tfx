import SwiftUI

struct ContentView: View {
#if os(macOS)
    @EnvironmentObject private var designStore: DesignStore
#endif

    var body: some View {
#if os(macOS)
        TerminalFileManagerView()
            .environment(\.theme, designStore.activeTheme)
            .environment(\.design, designStore.activeDesign)
            .frame(minWidth: 980, minHeight: 640)
            .alert("Configuration Error", isPresented: Binding(
                get: { designStore.configurationError != nil },
                set: { isPresented in
                    if !isPresented {
                        designStore.dismissConfigurationError()
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    designStore.dismissConfigurationError()
                }
            } message: {
                Text(designStore.configurationError ?? "")
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
}
