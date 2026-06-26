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
    /// the narrowest valid configuration (single file pane, no folder
    /// tree, no preview); wider configurations enforce a larger floor
    /// through `NSWindow.contentMinSize`.
    static var absoluteMinimumWindowWidth: CGFloat {
        minimumWindowWidth(visiblePanes: [] as [PaneSnapshot], isSplitViewVisible: false)
    }
    /// Smallest window content height that still leaves room for the
    /// header, the file list, and the status line. Set to 300 so the
    /// user can park a narrow short window in a corner of the screen
    /// for quick browsing.
    static let minimumWindowHeight: CGFloat = 300

    static func minimumWindowHeight(isTerminalPaneVisible: Bool) -> CGFloat {
        if isTerminalPaneVisible {
            return minimumWindowHeight + minimumTerminalPaneHeight + dividerWidth
        }
        return minimumWindowHeight
    }

    // MARK: - Folder tree

    static let defaultFolderTreeWidth: Double = 200
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

    /// Width consumed by everything to the right of the folder pane
    /// itself — i.e. the folder/file divider, the file area at its
    /// minimum, and (when shown) the file/preview divider plus the
    /// preview pane at its minimum. Subtract this from the total
    /// content width to get the folder pane's maximum allowed width.
    /// IMPORTANT: counts the folder/file divider too — leaving it
    /// out leaks 1pt of slack into the folder pane and squeezes the
    /// file area below its declared minimum at the window-min
    /// configuration.
    static func widthReservedRightOfFolderTree(
        isSplitViewVisible: Bool,
        isPreviewVisible: Bool
    ) -> CGFloat {
        var reserved = dividerWidth + minimumFileAreaWidth(isSplitViewVisible: isSplitViewVisible)
        if isPreviewVisible {
            reserved += dividerWidth + minimumPreviewPaneWidth
        }
        return reserved
    }

    /// Width consumed by everything to the left of the preview pane
    /// itself, given the *current* folder width. Includes the
    /// file/preview divider (always present when this is called —
    /// preview is visible) and, when the folder tree is shown, the
    /// folder pane and its trailing divider.
    static func widthReservedLeftOfPreview(
        currentFolderWidth: CGFloat,
        isFolderTreeVisible: Bool,
        isSplitViewVisible: Bool
    ) -> CGFloat {
        var reserved = minimumFileAreaWidth(isSplitViewVisible: isSplitViewVisible) + dividerWidth
        if isFolderTreeVisible {
            reserved += currentFolderWidth + dividerWidth
        }
        return reserved
    }

    /// Total window content width required for the given pane
    /// configuration. The window may not shrink below this value.
    ///
    /// Each visible side pane contributes its hard minimum plus one
    /// divider. User-stored widths are preferences for normal
    /// allocation, not part of the window floor.
    static func minimumWindowWidth(
        visiblePanes: [PaneSnapshot],
        isSplitViewVisible: Bool
    ) -> CGFloat {
        var width = minimumFileAreaWidth(isSplitViewVisible: isSplitViewVisible)
        for snapshot in visiblePanes {
            width += snapshot.pane.minimumWidth + dividerWidth
        }
        return width
    }
}
#endif
