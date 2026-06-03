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

    // MARK: - Unified write API

    /// Set the pane's visibility. Routes through the `@AppStorage`
    /// flag so `.onChange` handlers (window content-min refresh,
    /// auto-resize, focus fallback) fire exactly as if the user had
    /// flipped the toggle directly.
    func setVisible(_ pane: LayoutPane, _ visible: Bool) {
        switch pane {
        case .folderTree: isFolderTreeVisible = visible
        case .preview: isPreviewVisible = visible
        }
    }

    /// Toggle the pane's visibility — a thin wrapper so callers
    /// don't have to write `setVisible(p, !isVisible(p))`.
    func toggleVisibility(_ pane: LayoutPane) {
        setVisible(pane, !isVisible(pane))
    }

    /// Record a new stored width for the pane (from drag).
    /// Clamps to the pane's hard minimum so a runaway gesture
    /// can't write a useless value back to `UserDefaults`.
    func setStoredWidth(_ pane: LayoutPane, _ width: Double) {
        let clamped = max(Double(pane.minimumWidth), width)
        switch pane {
        case .folderTree: folderTreeWidth = clamped
        case .preview: previewWidth = clamped
        }
    }

    /// A SwiftUI `Binding<Bool>` for the pane's visibility, suitable
    /// for `Toggle(isOn:)`. Setting the binding routes through
    /// `setVisible` so the same `.onChange` side effects fire from
    /// toolbar, menu, and shortcut paths.
    func visibilityBinding(_ pane: LayoutPane) -> Binding<Bool> {
        Binding(
            get: { isVisible(pane) },
            set: { newValue in setVisible(pane, newValue) }
        )
    }
}
#endif
