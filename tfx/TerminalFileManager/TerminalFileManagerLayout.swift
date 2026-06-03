#if os(macOS)
import CoreGraphics

/// Single source of truth for window-, pane-, and column-sized layout
/// constants used by the terminal file manager surface. Every magic
/// pixel value that decides "how small can this thing get" lives here
/// so adjusting one number doesn't require chasing duplicates spread
/// across `ContentView`, `TerminalFileManagerView`,
/// `TerminalFileManagerFileArea`, and the rest.
///
/// The window minimum is intentionally derived from the per-pane
/// minimums via `minimumWindowWidth(isSplitViewVisible:isPreviewVisible:)`
/// — split and preview each contribute their own pane + divider. The
/// SwiftUI root frame uses `absoluteMinimumWindowWidth` (the smallest
/// of every combination) so the window can shrink down to single-pane
/// layouts; AppKit's `NSWindow.contentMinSize` is updated on the fly
/// when the pane visibility flags change, so the user can never drag
/// past the minimum that the current configuration needs.
enum TerminalFileManagerLayout {
    // MARK: - Window

    /// SwiftUI-level floor on the window content width. Corresponds to
    /// the narrowest valid configuration (single pane, no preview);
    /// wider configurations enforce a larger floor through
    /// `NSWindow.contentMinSize`.
    static var absoluteMinimumWindowWidth: CGFloat {
        minimumWindowWidth(isSplitViewVisible: false, isPreviewVisible: false)
    }
    /// Smallest window content height that still leaves room for the
    /// header, the file list, and the status line. Set to 300 so the
    /// user can park a narrow short window in a corner of the screen
    /// for quick browsing.
    static let minimumWindowHeight: CGFloat = 300

    // MARK: - Folder tree

    static let defaultFolderTreeWidth: Double = 250
    /// Hard floor on folder-tree width when resized or restored.
    static let minimumFolderTreeWidth: CGFloat = 180

    // MARK: - Preview pane

    static let defaultPreviewPaneWidth: Double = 320
    /// Hard floor on preview pane width.
    static let minimumPreviewPaneWidth: CGFloat = 240

    // MARK: - Built-in terminal pane

    static let defaultTerminalPaneHeight: Double = 220
    static let minimumTerminalPaneHeight: CGFloat = 120
    /// Smallest height the main file area is allowed to collapse to
    /// when the built-in terminal pane is expanded. Reduced from 260
    /// so a 300pt-tall window can still display the file list above
    /// the header + status bar (when the terminal pane is hidden).
    static let minimumMainAreaHeight: CGFloat = 200

    // MARK: - File pane (single + split)

    static let defaultFileNameColumnWidth: Double = 320
    /// Minimum width of one file pane. Applies both to the single-pane
    /// view and to each side of a split.
    static let minimumFilePaneWidth: CGFloat = 200
    static let defaultFileSplitRatio: Double = 0.5

    // MARK: - Dividers

    /// Width of every drag handle between top-level panes
    /// (folder/file, file/preview, and the split-internal handle).
    static let dividerWidth: CGFloat = 1

    // MARK: - Derived helpers

    /// Smallest file-area width that fits the current split state.
    /// In single mode = one file pane. In split mode = two file panes
    /// plus the divider between them.
    static func minimumFileAreaWidth(isSplitViewVisible: Bool) -> CGFloat {
        if isSplitViewVisible {
            return minimumFilePaneWidth * 2 + dividerWidth
        }
        return minimumFilePaneWidth
    }

    /// Width that must remain to the right of the folder tree when
    /// resizing or clamping the folder width. Equals file area plus
    /// the preview pane and its divider when the preview is visible.
    static func minimumWidthReservedAfterFolderTree(
        isSplitViewVisible: Bool,
        isPreviewVisible: Bool
    ) -> CGFloat {
        var reserved = minimumFileAreaWidth(isSplitViewVisible: isSplitViewVisible)
        if isPreviewVisible {
            reserved += dividerWidth + minimumPreviewPaneWidth
        }
        return reserved
    }

    /// Width that must remain to the left of the preview pane when
    /// resizing the preview. Equals folder min + divider + file area.
    static func minimumWidthReservedAfterPreview(isSplitViewVisible: Bool) -> CGFloat {
        minimumFolderTreeWidth + dividerWidth + minimumFileAreaWidth(isSplitViewVisible: isSplitViewVisible)
    }

    /// Total window content width required for the given pane
    /// configuration. The window may not shrink below this value.
    static func minimumWindowWidth(
        isSplitViewVisible: Bool,
        isPreviewVisible: Bool
    ) -> CGFloat {
        var width = minimumFolderTreeWidth + dividerWidth
        width += minimumFileAreaWidth(isSplitViewVisible: isSplitViewVisible)
        if isPreviewVisible {
            width += dividerWidth + minimumPreviewPaneWidth
        }
        return width
    }
}
#endif
