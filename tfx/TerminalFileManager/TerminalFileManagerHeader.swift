#if os(macOS)
import SwiftUI

extension TerminalFileManagerView {
    var header: some View {
        HStack(spacing: 10) {
            navigationControls
            pathAndSearchControls
            sortAndVisibilityControls
            fileActionControls
            utilityControls
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isFileListSettingsPresented) {
            FileListSettingsView(
                configurationRaw: $fileColumnConfigurationRaw
            )
        }
        .overlay(alignment: .bottomTrailing) {
            hoverHelpOverlay
        }
    }
}

#endif
