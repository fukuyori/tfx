#if os(macOS)
import AppKit
import SwiftUI

/// Diagnostic log for `MainPaneSplitView` only. Enabled by
/// `TFX_PANE_LAYOUT_LOGS=1` in the environment OR by toggling
/// `Developer.showsPaneLayoutLogs` in `UserDefaults`. Off by default
/// so production logs aren't noisy; turn on while debugging
/// pane / window-size behavior.
func paneLog(_ message: String) {
    if ProcessInfo.processInfo.environment["TFX_PANE_LAYOUT_LOGS"] == "1"
        || UserDefaults.standard.bool(forKey: "Developer.showsPaneLayoutLogs") {
        print("[tfx pane] \(message)")
    }
}

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

    /// Whether the file area's own internal split is active. Drives
    /// the file-area minimum width that this wrapper enforces (and
    /// passes through to the window's `contentMinSize`).
    let isSplitViewVisible: Bool

    /// Minimum width the file area must keep, used by the split
    /// view's coordinate-constraint delegate methods. Depends on
    /// whether the file area's own internal split is active.
    let fileAreaMinimumWidth: CGFloat

    /// Smallest window content height — propagated to the window's
    /// `contentMinSize` alongside the computed minimum width.
    let minimumWindowHeight: CGFloat

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
        paneLog("updateNSView: folder=\(isFolderVisible)/\(folderWidth) preview=\(isPreviewVisible)/\(previewWidth) split=\(isSplitViewVisible) fileAreaMin=\(fileAreaMinimumWidth)")
        context.coordinator.parent = self
        // Refresh SwiftUI content inside each hosted subview so that
        // upstream state changes (active pane highlight, file list
        // updates, etc.) propagate through.
        context.coordinator.updateHost(context.coordinator.folderHost, with: folderContent)
        context.coordinator.updateHost(context.coordinator.fileAreaHost, with: fileAreaContent)
        context.coordinator.updateHost(context.coordinator.previewHost, with: previewContent)

        DispatchQueue.main.async {
            // Order matters: contentMinSize must be the new floor
            // BEFORE setFrame in `resizeWindowForToggleIfNeeded` —
            // otherwise NSWindow may refuse to shrink past the old
            // (larger) min on a toggle OFF. `applyVisibility` and
            // `applyStoredWidths` need the window already at the
            // right size before they push subview positions.
            context.coordinator.applyContentMinSize()
            context.coordinator.resizeWindowForToggleIfNeeded()
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

        /// Last-seen visibility state, used by
        /// `resizeWindowForToggleIfNeeded` to detect a pane being
        /// toggled on or off across `updateNSView` calls. `nil`
        /// during the very first update so the initial pass doesn't
        /// look like a toggle.
        private var lastFolderVisible: Bool?
        private var lastPreviewVisible: Bool?

        init(parent: MainPaneSplitView) {
            self.parent = parent
        }

        // MARK: View hosting

        func makeHost(for content: AnyView) -> NSHostingView<AnyView> {
            let host = NSHostingView(rootView: content)
            host.translatesAutoresizingMaskIntoConstraints = false
            // CRUCIAL: NSHostingView does NOT clip its content to the
            // host's frame by default. When SwiftUI lays out content
            // with an intrinsic width wider than the frame
            // NSSplitView gave us (e.g. folder tree natural width
            // > stored 250pt forced into a 181pt frame during a
            // narrow-window live resize), the SwiftUI content
            // overflows and visually draws on top of the neighbor
            // pane. Enable layer-backed clipping so the host
            // physically cannot paint outside its frame.
            host.wantsLayer = true
            host.layer?.masksToBounds = true
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

        // MARK: Window-level state (single owner of contentMinSize)

        /// Write the window's `contentMinSize` from the current pane
        /// state — visible panes contribute `max(min, stored) +
        /// divider`, plus the file area's own minimum. This is the
        /// **only** place in the app that mutates `contentMinSize`,
        /// keeping the value coherent regardless of which user action
        /// (toggle, drag, split) triggered the update.
        func applyContentMinSize() {
            guard let window = splitView?.window else {
                paneLog("applyContentMinSize: no window yet, skipping")
                return
            }
            let divider = splitView?.dividerThickness ?? 1
            var width = parent.fileAreaMinimumWidth
            var components = "fileArea=\(parent.fileAreaMinimumWidth)"
            if parent.isFolderVisible {
                let folderWidth = max(LayoutPane.folderTree.minimumWidth, CGFloat(parent.folderWidth))
                width += folderWidth + divider
                components += " folder=\(folderWidth)+\(divider)"
            }
            if parent.isPreviewVisible {
                let previewWidth = max(LayoutPane.preview.minimumWidth, CGFloat(parent.previewWidth))
                width += previewWidth + divider
                components += " preview=\(previewWidth)+\(divider)"
            }
            let newMinSize = NSSize(width: width, height: parent.minimumWindowHeight)
            let oldMinSize = window.contentMinSize
            paneLog("applyContentMinSize: \(components) → newMin=\(width)x\(parent.minimumWindowHeight); old=\(oldMinSize.width)x\(oldMinSize.height); windowFrame=\(window.frame.width)")
            if window.contentMinSize != newMinSize {
                window.contentMinSize = newMinSize
                paneLog("  wrote contentMinSize")
            }
        }

        /// On the first `updateNSView` after a side pane toggled,
        /// resize the window symmetrically: grow by the pane's stored
        /// width on ON (so the file area is preserved), shrink by
        /// the same on OFF (so the file area returns to its prior
        /// width). Capped to the screen edge on grow and to the
        /// current `contentMinSize` on shrink (which `applyContentMinSize`
        /// just made authoritative).
        func resizeWindowForToggleIfNeeded() {
            guard let window = splitView?.window else { return }
            defer {
                lastFolderVisible = parent.isFolderVisible
                lastPreviewVisible = parent.isPreviewVisible
            }
            let folderChanged = lastFolderVisible != nil && lastFolderVisible != parent.isFolderVisible
            let previewChanged = lastPreviewVisible != nil && lastPreviewVisible != parent.isPreviewVisible
            paneLog("resizeForToggle: lastFolder=\(String(describing: lastFolderVisible)) curFolder=\(parent.isFolderVisible) folderChanged=\(folderChanged); lastPreview=\(String(describing: lastPreviewVisible)) curPreview=\(parent.isPreviewVisible) previewChanged=\(previewChanged)")
            guard folderChanged || previewChanged else { return }

            let currentFrame = window.frame
            let chromeWidth = currentFrame.width - window.contentLayoutRect.width
            let minFrameWidth = window.contentMinSize.width + chromeWidth
            var paneDelta: CGFloat = 0

            if folderChanged {
                let folderStored = max(LayoutPane.folderTree.minimumWidth, CGFloat(parent.folderWidth))
                let signed = parent.isFolderVisible ? folderStored : -folderStored
                paneDelta += signed + (splitView?.dividerThickness ?? 1) * (parent.isFolderVisible ? 1 : -1)
            }
            if previewChanged {
                let previewStored = max(LayoutPane.preview.minimumWidth, CGFloat(parent.previewWidth))
                let signed = parent.isPreviewVisible ? previewStored : -previewStored
                paneDelta += signed + (splitView?.dividerThickness ?? 1) * (parent.isPreviewVisible ? 1 : -1)
            }

            let maxFrameWidth = window.screen.map { screen in
                max(currentFrame.width, screen.visibleFrame.maxX - currentFrame.minX)
            } ?? .infinity
            let proposedWidth = currentFrame.width + paneDelta
            let cappedHigh = min(proposedWidth, maxFrameWidth)
            let targetFrameWidth = max(cappedHigh, minFrameWidth)
            paneLog("  paneDelta=\(paneDelta) currentFrame=\(currentFrame.width) minFrame=\(minFrameWidth) proposed=\(proposedWidth) target=\(targetFrameWidth)")
            guard targetFrameWidth != currentFrame.width else {
                paneLog("  no resize (target == current)")
                return
            }

            var frame = currentFrame
            frame.size.width = targetFrameWidth
            frame.origin = currentFrame.origin
            window.setFrame(frame, display: true, animate: false)
            paneLog("  setFrame to \(targetFrameWidth)")
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

        /// Hide the divider next to a collapsed pane. Without this,
        /// the would-be divider remains hit-testable and the user
        /// can drag it to re-expand a pane they explicitly hid —
        /// e.g. drag the file area's right edge to make the
        /// hidden preview reappear.
        func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {
            switch dividerIndex {
            case 0: return folderHost?.isHidden ?? false
            case 1: return previewHost?.isHidden ?? false
            default: return false
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
                paneLog("splitViewDidResizeSubviews: skip (live=\(split.inLiveResize) programmatic=\(isApplyingProgrammaticLayout)) | folder=\(folder.frame.width) preview=\(preview.frame.width)")
                return
            }

            // `NSSplitView` also fires this delegate method during
            // its own automatic layout — initial layout, window
            // resize that pushed past contentMinSize, etc. In those
            // cases the frame width we see is what NSSplitView
            // *clamped to*, not what the user dragged to. Writing
            // it back to AppStorage would corrupt the user's
            // stored preference (e.g. shrink stored 250 to whatever
            // fit in a too-narrow window).
            //
            // Distinguish user-drag from forced-clamp: a user drag
            // happens when the window CAN accommodate the stored
            // width — i.e. there is enough room left over after
            // every other visible pane (and the file area's min)
            // for the stored width. If the window is too narrow to
            // fit stored, any smaller frame width is NSSplitView's
            // forced layout decision, not the user's choice.
            let divider = split.dividerThickness
            let contentWidth = split.bounds.width
            paneLog("splitViewDidResizeSubviews: evaluating | content=\(contentWidth) folder=\(folder.frame.width) preview=\(preview.frame.width) stored folder=\(parent.folderWidth) preview=\(parent.previewWidth)")

            var didChangeWidth = false
            if parent.isFolderVisible, !folder.isHidden {
                let newFolderWidth = Double(folder.frame.width)
                // A frame width below the pane's own hard minimum
                // can ONLY be NSSplitView mid-layout (subview not
                // yet sized, or container just installed). The
                // `constrainMinCoordinate` delegate prevents any
                // user drag from violating the min, so anything
                // smaller is a layout intermediate state, never a
                // user choice.
                let isPreLayout = newFolderWidth < Double(LayoutPane.folderTree.minimumWidth)
                var folderRoom = contentWidth - parent.fileAreaMinimumWidth - divider
                if parent.isPreviewVisible, !preview.isHidden {
                    folderRoom -= max(LayoutPane.preview.minimumWidth, CGFloat(parent.previewWidth)) + divider
                }
                let windowAllowsStored = folderRoom >= CGFloat(parent.folderWidth)
                let isForcedShrink = !windowAllowsStored && newFolderWidth < parent.folderWidth
                let diff = abs(newFolderWidth - parent.folderWidth)
                if diff > 0.5 && !isPreLayout && !isForcedShrink {
                    paneLog("  persist folder=\(newFolderWidth) (was \(parent.folderWidth), folderRoom=\(folderRoom))")
                    parent.folderWidth = newFolderWidth
                    didChangeWidth = true
                } else if isPreLayout {
                    paneLog("  skip folder (pre-layout: width=\(newFolderWidth) < min=\(LayoutPane.folderTree.minimumWidth))")
                } else if isForcedShrink {
                    paneLog("  skip folder (forced clamp; folderRoom=\(folderRoom) < stored=\(parent.folderWidth))")
                }
            }
            if parent.isPreviewVisible, !preview.isHidden {
                let newPreviewWidth = Double(preview.frame.width)
                let isPreLayout = newPreviewWidth < Double(LayoutPane.preview.minimumWidth)
                var previewRoom = contentWidth - parent.fileAreaMinimumWidth - divider
                if parent.isFolderVisible, !folder.isHidden {
                    previewRoom -= max(LayoutPane.folderTree.minimumWidth, CGFloat(parent.folderWidth)) + divider
                }
                let windowAllowsStored = previewRoom >= CGFloat(parent.previewWidth)
                let isForcedShrink = !windowAllowsStored && newPreviewWidth < parent.previewWidth
                let diff = abs(newPreviewWidth - parent.previewWidth)
                if diff > 0.5 && !isPreLayout && !isForcedShrink {
                    paneLog("  persist preview=\(newPreviewWidth) (was \(parent.previewWidth), previewRoom=\(previewRoom))")
                    parent.previewWidth = newPreviewWidth
                    didChangeWidth = true
                } else if isPreLayout {
                    paneLog("  skip preview (pre-layout: width=\(newPreviewWidth) < min=\(LayoutPane.preview.minimumWidth))")
                } else if isForcedShrink {
                    paneLog("  skip preview (forced clamp; previewRoom=\(previewRoom) < stored=\(parent.previewWidth))")
                }
            }

            // Drag changed a stored width: refresh contentMinSize so
            // dragging a pane wider raises the window's floor.
            if didChangeWidth {
                applyContentMinSize()
            }
        }
    }
}
#endif
