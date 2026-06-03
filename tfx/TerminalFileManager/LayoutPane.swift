#if os(macOS)
import CoreGraphics

/// One of the user-toggleable side panes that share the main file
/// area's row of horizontal space.
///
/// This enum is the **single source of truth** for everything that
/// distinguishes one side pane from another: which side it sits on,
/// what its `@AppStorage` keys are, what its minimum and default
/// widths are. The view layer, the window-minimum calculation, the
/// toolbar / menu / shortcut toggles, and the drag handler all read
/// pane metadata from here — so adding a new side pane is a matter
/// of extending the enum, not chasing edits across half a dozen
/// files.
///
/// The central file area is *not* a `LayoutPane` because it is
/// always present and takes the residue width. Split / single is a
/// property of the file area, not a separate pane.
enum LayoutPane: String, CaseIterable, Identifiable {
    case folderTree
    case preview

    var id: String { rawValue }

    /// Which side of the file area this pane sits on.
    var side: PaneSide {
        switch self {
        case .folderTree: return .leading
        case .preview: return .trailing
        }
    }

    /// Hard minimum width below which the pane is never rendered.
    var minimumWidth: CGFloat {
        switch self {
        case .folderTree: return TerminalFileManagerLayout.minimumFolderTreeWidth
        case .preview: return TerminalFileManagerLayout.minimumPreviewPaneWidth
        }
    }

    /// Default width used the first time the pane is shown (and the
    /// fallback when the stored value is missing).
    var defaultWidth: Double {
        switch self {
        case .folderTree: return TerminalFileManagerLayout.defaultFolderTreeWidth
        case .preview: return TerminalFileManagerLayout.defaultPreviewPaneWidth
        }
    }

    /// `UserDefaults` key for this pane's visibility flag. The
    /// `@AppStorage` properties on `TerminalFileManagerView` use the
    /// same string literal — kept here so non-view callers (e.g.
    /// `WindowFrameAutosaver.Coordinator.windowWillResize`) can read
    /// the live value without going through SwiftUI.
    var visibilityStorageKey: String {
        switch self {
        case .folderTree: return "TerminalFileManager.isFolderTreeVisible"
        case .preview: return "TerminalFileManager.isPreviewVisible"
        }
    }

    /// `UserDefaults` key for this pane's stored width.
    var widthStorageKey: String {
        switch self {
        case .folderTree: return "TerminalFileManager.folderTreeWidth"
        case .preview: return "TerminalFileManager.previewWidth"
        }
    }

    /// Default visibility used on first launch when the
    /// `UserDefaults` key is missing.
    var defaultVisibility: Bool {
        switch self {
        case .folderTree: return true
        case .preview: return true
        }
    }
}

enum PaneSide {
    case leading
    case trailing
}
#endif
