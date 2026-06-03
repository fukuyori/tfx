#if os(macOS)
import AppKit
import SwiftUI

/// Three-pane horizontal layout (folder tree | file area | preview)
/// backed by `NSSplitView`.
///
/// Why AppKit and not a SwiftUI `HStack`?  SwiftUI `.frame(width:)`
/// is a *proposal* — when the HStack is constrained narrower than
/// the sum of its children, SwiftUI silently shrinks the
/// children. Combined with SwiftUI's automatic propagation of view-
/// tree intrinsic minimums into `NSWindow.contentMinSize`, the
/// resulting layout could not reliably keep a side pane at its
/// stored width across window resizes and toggles of unrelated
/// panes. `NSSplitView` is the native macOS construct designed for
/// this exact problem: each pane has its own minimum thickness, its
/// own holding priority (which decides who absorbs window-resize
/// slack), and an independent collapsed state. The view widths are
/// fully decoupled from each other and from the window — the goal
/// of this whole layout refactor.
///
/// The split view contains exactly three arranged subviews in this
/// order: `LayoutPane.folderTree`, the file area, `LayoutPane.preview`.
/// Each side pane's `LayoutPane` metadata drives its minimum
/// thickness; the file area has no per-pane minimum but contributes
/// `TerminalFileManagerLayout.minimumFilePaneWidth` via the
/// delegate's coordinate constraints. The file area's own internal
/// left/right split stays in SwiftUI inside the file-area subview.
///
/// State plumbing happens in Phase G-3; this file is the structural
/// shell so Phase G-2 can wire content into it.
struct MainPaneSplitView: NSViewRepresentable {
    /// SwiftUI content for the folder tree pane.
    let folderContent: AnyView
    /// SwiftUI content for the central file area (always present).
    let fileAreaContent: AnyView
    /// SwiftUI content for the preview pane.
    let previewContent: AnyView

    /// Which side panes should currently be shown. Hidden panes are
    /// collapsed; the split view automatically suppresses the
    /// corresponding divider.
    let isFolderVisible: Bool
    let isPreviewVisible: Bool

    /// Stored widths the side panes should restore to when visible.
    /// Two-way binding so user-drag results can be persisted back.
    @Binding var folderWidth: Double
    @Binding var previewWidth: Double

    /// Minimum width the file area must keep, used by the split
    /// view's coordinate-constraint delegate methods. Depends on
    /// whether the file area's own internal split is active.
    let fileAreaMinimumWidth: CGFloat

    // MARK: - NSViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSplitView {
        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false
        split.delegate = context.coordinator

        let folderHost = context.coordinator.makeHost(for: folderContent)
        let fileAreaHost = context.coordinator.makeHost(for: fileAreaContent)
        let previewHost = context.coordinator.makeHost(for: previewContent)

        split.addArrangedSubview(folderHost)
        split.addArrangedSubview(fileAreaHost)
        split.addArrangedSubview(previewHost)

        context.coordinator.folderHost = folderHost
        context.coordinator.fileAreaHost = fileAreaHost
        context.coordinator.previewHost = previewHost
        context.coordinator.splitView = split

        // Holding priorities: side panes resist window-resize
        // changes, file area absorbs them. Higher priority means
        // less likely to be resized.
        split.setHoldingPriority(.defaultHigh, forSubviewAt: 0)
        split.setHoldingPriority(.defaultLow, forSubviewAt: 1)
        split.setHoldingPriority(.defaultHigh, forSubviewAt: 2)

        DispatchQueue.main.async {
            context.coordinator.applyVisibility(animated: false)
            context.coordinator.applyStoredWidths()
        }

        return split
    }

    func updateNSView(_ nsView: NSSplitView, context: Context) {
        context.coordinator.parent = self
        // Refresh SwiftUI content inside each hosted subview so that
        // upstream state changes (active pane highlight, file list
        // updates, etc.) propagate through.
        context.coordinator.updateHost(context.coordinator.folderHost, with: folderContent)
        context.coordinator.updateHost(context.coordinator.fileAreaHost, with: fileAreaContent)
        context.coordinator.updateHost(context.coordinator.previewHost, with: previewContent)

        DispatchQueue.main.async {
            context.coordinator.applyVisibility(animated: false)
            context.coordinator.applyStoredWidths()
        }
    }

    // MARK: - Coordinator (NSSplitViewDelegate)

    final class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: MainPaneSplitView
        weak var splitView: NSSplitView?
        var folderHost: NSHostingView<AnyView>!
        var fileAreaHost: NSHostingView<AnyView>!
        var previewHost: NSHostingView<AnyView>!
        /// True while we're calling `adjustSubviews()` /
        /// `setPosition(_:ofDividerAt:)` ourselves, so the
        /// `splitViewDidResizeSubviews` callback that fires
        /// synchronously during those calls doesn't write our own
        /// programmatic positions back to `AppStorage` and clobber
        /// the user's stored preference.
        private var isApplyingProgrammaticLayout = false

        init(parent: MainPaneSplitView) {
            self.parent = parent
        }

        // MARK: View hosting

        func makeHost(for content: AnyView) -> NSHostingView<AnyView> {
            let host = NSHostingView(rootView: content)
            host.translatesAutoresizingMaskIntoConstraints = false
            return host
        }

        func updateHost(_ host: NSHostingView<AnyView>?, with content: AnyView) {
            host?.rootView = content
        }

        // MARK: Visibility / widths

        /// Hide/show side panes by toggling the hosting view's
        /// `isHidden`. `NSSplitView` treats a hidden subview as
        /// collapsed and automatically suppresses its divider.
        func applyVisibility(animated: Bool) {
            guard let split = splitView,
                  let folder = folderHost,
                  let preview = previewHost else { return }
            let folderShouldHide = !parent.isFolderVisible
            let previewShouldHide = !parent.isPreviewVisible
            let needsChange = folder.isHidden != folderShouldHide
                || preview.isHidden != previewShouldHide
            guard needsChange else { return }
            isApplyingProgrammaticLayout = true
            defer { isApplyingProgrammaticLayout = false }
            if folder.isHidden != folderShouldHide {
                folder.isHidden = folderShouldHide
            }
            if preview.isHidden != previewShouldHide {
                preview.isHidden = previewShouldHide
            }
            split.adjustSubviews()
        }

        /// Restore the side panes to their stored widths after a
        /// layout pass. Uses `setPosition(_:ofDividerAt:)` because
        /// the higher-level `preferredThicknessFraction` API is
        /// fraction-based and doesn't survive resize cleanly.
        func applyStoredWidths() {
            guard let split = splitView,
                  let folder = folderHost,
                  let preview = previewHost else { return }
            let totalWidth = split.bounds.width
            guard totalWidth > 0 else { return }

            isApplyingProgrammaticLayout = true
            defer { isApplyingProgrammaticLayout = false }

            // Divider 0 sits between subview 0 (folder) and subview
            // 1 (file area). Its position is measured from the
            // split's leading edge, so it equals folder width.
            if parent.isFolderVisible {
                let folderTarget = CGFloat(parent.folderWidth)
                if abs(folder.frame.width - folderTarget) > 0.5 {
                    split.setPosition(folderTarget, ofDividerAt: 0)
                }
            }

            // Divider 1 sits between subview 1 (file area) and
            // subview 2 (preview). Its position equals folder
            // width + file area width.
            if parent.isPreviewVisible {
                let previewTarget = CGFloat(parent.previewWidth)
                let dividerPosition = totalWidth - previewTarget
                if abs(preview.frame.width - previewTarget) > 0.5 {
                    split.setPosition(dividerPosition, ofDividerAt: 1)
                }
            }
        }

        // MARK: NSSplitViewDelegate — constraints & persistence

        /// Lower bound for each divider's position. NSSplitView calls
        /// this during user drag to enforce per-pane minimums.
        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            switch dividerIndex {
            case 0:
                // Folder can't be narrower than its own minimum.
                return parent.isFolderVisible ? LayoutPane.folderTree.minimumWidth : 0
            case 1:
                // File area can't be narrower than its own minimum,
                // measured from the leading edge of the file area.
                let folderWidth = parent.isFolderVisible ? (folderHost?.frame.width ?? 0) : 0
                return folderWidth + parent.fileAreaMinimumWidth
            default:
                return proposedMinimumPosition
            }
        }

        /// Upper bound for each divider's position.
        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            let totalWidth = splitView.bounds.width
            switch dividerIndex {
            case 0:
                // Folder can't push the file area below its min, and
                // (when preview is visible) below preview-min as well.
                var reserved = parent.fileAreaMinimumWidth
                if parent.isPreviewVisible {
                    reserved += splitView.dividerThickness + LayoutPane.preview.minimumWidth
                }
                return max(0, totalWidth - reserved)
            case 1:
                // Preview can't be narrower than its own minimum.
                return parent.isPreviewVisible
                    ? totalWidth - LayoutPane.preview.minimumWidth
                    : totalWidth
            default:
                return proposedMaximumPosition
            }
        }

        /// Persist user-drag results back to AppStorage. Skipped:
        /// - during `inLiveResize` (window itself being resized),
        ///   because window resize legitimately changes file area
        ///   width but pane widths shouldn't be touched (and we
        ///   don't write them back regardless);
        /// - during `isApplyingProgrammaticLayout`, because the
        ///   `setPosition` / `adjustSubviews` we just called
        ///   synchronously fires this delegate method — writing
        ///   those programmatic positions back to AppStorage would
        ///   defeat the whole point of having a stored preference.
        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let split = splitView,
                  let folder = folderHost,
                  let preview = previewHost else { return }
            guard !split.inLiveResize, !isApplyingProgrammaticLayout else {
                return
            }

            if parent.isFolderVisible, !folder.isHidden {
                let newFolderWidth = Double(folder.frame.width)
                if abs(newFolderWidth - parent.folderWidth) > 0.5 {
                    parent.folderWidth = newFolderWidth
                }
            }
            if parent.isPreviewVisible, !preview.isHidden {
                let newPreviewWidth = Double(preview.frame.width)
                if abs(newPreviewWidth - parent.previewWidth) > 0.5 {
                    parent.previewWidth = newPreviewWidth
                }
            }
        }
    }
}
#endif
