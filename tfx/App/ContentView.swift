import SwiftUI

struct ContentView: View {
    var body: some View {
#if os(macOS)
        TerminalFileManagerView()
            .frame(minWidth: 980, minHeight: 640)
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
