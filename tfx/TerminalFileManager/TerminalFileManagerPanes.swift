#if os(macOS)
import CoreGraphics
import SwiftUI

/// Unified read API for layout-pane state.
///
/// Each side pane (folder tree, preview) keeps its own `@AppStorage`
/// flag and width on `TerminalFileManagerView`. Code that needs to
/// reason about panes — the layout, the window-minimum calculation,
/// the toolbar / menu / drag handlers — should go through this enum-
/// keyed surface rather than reaching for `isFolderTreeVisible` /
/// `previewWidth` directly. That keeps cross-pane behavior uniform
/// and makes adding a third pane a matter of extending `LayoutPane`,
/// not chasing edits across every consumer.
///
/// Writes (toggling a pane, recording a drag) are added in Phase B —
/// this file is the read-side foundation.
extension TerminalFileManagerView {
    /// Is the pane currently shown? Reads the same `@AppStorage`
    /// the property accessors do.
    func isVisible(_ pane: LayoutPane) -> Bool {
        switch pane {
        case .folderTree: return isFolderTreeVisible
        case .preview: return isPreviewVisible
        }
    }

    /// The pane's stored width preference — what the user dragged
    /// it to, or the default if they never touched it. Never
    /// auto-narrowed by window resizes.
    func storedWidth(_ pane: LayoutPane) -> Double {
        switch pane {
        case .folderTree: return folderTreeWidth
        case .preview: return previewWidth
        }
    }

    /// The width the pane should actually render at. Stored width
    /// clamped to its hard minimum (so a corrupted defaults entry
    /// can't make the pane disappear) and to zero when the pane is
    /// not visible.
    func displayedWidth(_ pane: LayoutPane) -> CGFloat {
        guard isVisible(pane) else { return 0 }
        return max(pane.minimumWidth, CGFloat(storedWidth(pane)))
    }
}
#endif
