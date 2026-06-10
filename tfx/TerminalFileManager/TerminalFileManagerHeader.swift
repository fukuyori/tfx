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
        // Tint propagates to every borderless button / toggle in
        // the header so their SF Symbol labels pick up the theme
        // foreground instead of the system label color. Without
        // this, the controls become invisible against the dark
        // header background when macOS is in light mode (the
        // system label color is black and our header is dark
        // regardless of the system appearance because the app's
        // theme is independent of light/dark mode).
        //
        // `theme.headerIcon` returns `headerIconForeground` when
        // set, otherwise falls back to `headerForeground` — so a
        // user who wants a distinct toolbar-icon tint can set
        // `headerIconForeground` in `config.toml` without losing
        // legibility when they don't.
        .tint(theme.headerIcon)
        .foregroundStyle(theme.headerIcon)
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
