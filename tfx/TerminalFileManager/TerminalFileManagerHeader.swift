#if os(macOS)
import SwiftUI

extension TerminalFileManagerView {
    var header: some View {
        HStack(spacing: 10) {
            navigationControls
            pathAndSearchControls
            sortAndVisibilityControls
            utilityControls
        }
        .padding(10)
        .background(theme.headerBackground.opacity(design.opacity.background))
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
