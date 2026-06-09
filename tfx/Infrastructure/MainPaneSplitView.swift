#if os(macOS)
import AppKit
import SwiftUI

/// Diagnostic log for `MainPaneSplitView` only. Enabled by
/// `TFX_PANE_LAYOUT_LOGS=1` in the environment OR by toggling
/// `Developer.showsPaneLayoutLogs` in `UserDefaults`. Off by default
/// so production logs aren't noisy; turn on while debugging
/// pane / window-size behavior.
///
/// The `@autoclosure` wrapper skips the message's string
/// interpolation entirely when the log is disabled — important
/// because this is called from layout / persist hot paths where
/// the interpolation cost (formatting frames, doubles, etc.) is
/// non-trivial even when nobody is watching.
@inlinable
func paneLog(_ message: @autoclosure () -> String) {
    guard isPaneLogEnabled else { return }
    print("[tfx pane] \(message())")
}

@usableFromInline
let isPaneLogEnabled: Bool = {
    ProcessInfo.processInfo.environment["TFX_PANE_LAYOUT_LOGS"] == "1"
        || UserDefaults.standard.bool(forKey: "Developer.showsPaneLayoutLogs")
}()

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

        // Holding priorities matter only when NSSplitView's own
        // layout algorithm runs — we override the whole layout
        // pass in `splitView(_:resizeSubviewsWithOldSize:)`, so
        // these are advisory at best. Set them for completeness
        // and so any layout path we didn't anticipate behaves
        // sensibly: folder and preview resist resizing, file area
        // absorbs the slack.
        split.setHoldingPriority(.required, forSubviewAt: 0)
        split.setHoldingPriority(.defaultLow, forSubviewAt: 1)
        split.setHoldingPriority(.defaultHigh, forSubviewAt: 2)

        DispatchQueue.main.async {
            context.coordinator.applyVisibility(animated: false)
        }

        return split
    }

    func updateNSView(_ nsView: NSSplitView, context: Context) {
        paneLog("updateNSView: folder=\(isFolderVisible) preview=\(isPreviewVisible)/\(previewWidth) split=\(isSplitViewVisible) fileAreaMin=\(fileAreaMinimumWidth)")
        context.coordinator.parent = self
        // Refresh SwiftUI content inside each hosted subview so
        // upstream state changes (active pane highlight, file
        // list updates, etc.) propagate through.
        context.coordinator.updateHost(context.coordinator.folderHost, with: folderContent)
        context.coordinator.updateHost(context.coordinator.fileAreaHost, with: fileAreaContent)
        context.coordinator.updateHost(context.coordinator.previewHost, with: previewContent)

        DispatchQueue.main.async {
            // Order:
            //   1. `applyContentMinSize` updates the window floor
            //      to match the new pane configuration so the
            //      following `setFrame` can shrink past the old
            //      minimum if needed.
            //   2. `applyVisibility` flips `isHidden` on the side
            //      hosts; our `resizeSubviewsWithOldSize` reads
            //      these flags to decide which panes get width.
            //   3. `resizeWindowForToggleIfNeeded` grows/shrinks
            //      the window so the file area keeps its width
            //      across pane toggles instead of shrinking.
            //
            // The `isApplyingProgrammaticLayout` flag is held only
            // for the duration of `setFrame` inside step 3, so the
            // delegate callback that `setFrame` fires synchronously
            // doesn't persist the mid-resize preview frame back to
            // AppStorage.
            context.coordinator.applyContentMinSize()
            context.coordinator.applyVisibility(animated: false)
            context.coordinator.runProgrammaticLayout {
                context.coordinator.resizeWindowForToggleIfNeeded()
            }
        }
    }

    // MARK: - Coordinator (NSSplitViewDelegate)

    final class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: MainPaneSplitView
        weak var splitView: NSSplitView?
        var folderHost: NSHostingView<AnyView>!
        var fileAreaHost: NSHostingView<AnyView>!
        var previewHost: NSHostingView<AnyView>!

        /// Set while we are calling `setFrame` on the window from
        /// `resizeWindowForToggleIfNeeded`. Filters the
        /// `splitViewDidResizeSubviews` callback that fires
        /// synchronously during the resize so we don't persist
        /// the mid-resize preview frame width over the user's
        /// stored preference.
        private var isApplyingProgrammaticLayout = false

        /// Wrap a block of layout calls that programmatically
        /// move pane widths (currently just the window
        /// `setFrame` inside `resizeWindowForToggleIfNeeded`)
        /// so synchronous `splitViewDidResizeSubviews` callbacks
        /// during the block are ignored for persistence.
        func runProgrammaticLayout(_ body: () -> Void) {
            isApplyingProgrammaticLayout = true
            defer { isApplyingProgrammaticLayout = false }
            body()
        }

        /// Last-seen visibility state. `resizeWindowForToggleIfNeeded`
        /// compares against this to detect a pane being toggled
        /// on or off across `updateNSView` calls. `nil` on the
        /// very first update so the initial pass isn't seen as
        /// a toggle.
        private var lastFolderVisible: Bool?
        private var lastPreviewVisible: Bool?

        /// The header-driven minimum content width that SwiftUI
        /// propagates into `NSWindow.contentMinSize` from the view
        /// tree (the search field + toolbar row can't render below a
        /// certain width). `applyContentMinSize` must never push the
        /// window floor below this — doing so lets the user drag the
        /// window narrower than the header needs, at which point the
        /// header (and the `NSSplitView` it shares the column with)
        /// overflows the window and gets centered + clipped, pushing
        /// the width-locked folder pane off the left edge. Captured
        /// from SwiftUI's own writes (see `applyContentMinSize`),
        /// never hard-coded, so it tracks localization / font changes.
        private var headerDrivenMinWidth: CGFloat = 0

        /// Last width we wrote to `contentMinSize` ourselves. Used to
        /// tell our own writes apart from SwiftUI's: when the live
        /// value differs from this, SwiftUI re-derived it from the
        /// view tree, so it is an authoritative header-driven floor.
        private var lastWrittenMinWidth: CGFloat = -1

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
        /// `isHidden`. The width assignment that follows happens
        /// in `splitView(_:resizeSubviewsWithOldSize:)`, which
        /// reads `parent.isFolderVisible` / `parent.isPreviewVisible`
        /// (and the resulting `isHidden` flags) directly.
        func applyVisibility(animated: Bool) {
            guard let folder = folderHost,
                  let preview = previewHost else { return }
            let folderShouldHide = !parent.isFolderVisible
            let previewShouldHide = !parent.isPreviewVisible
            if folder.isHidden != folderShouldHide {
                folder.isHidden = folderShouldHide
            }
            if preview.isHidden != previewShouldHide {
                preview.isHidden = previewShouldHide
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
            // `width` so far is the pane-driven floor (folder + file
            // area + preview + dividers). But the window also has to
            // fit the HEADER above the split, whose minimum width is
            // larger than a single narrow pane configuration. SwiftUI
            // derives that header minimum and writes it into
            // `contentMinSize`; if the live value differs from what we
            // last wrote, SwiftUI just re-derived it, so capture it as
            // the authoritative header-driven floor. Distinguishing
            // SwiftUI's writes from our own this way avoids mistaking a
            // stale *pane*-driven value (e.g. the wider preview-shown
            // floor, left behind after the preview was hidden) for the
            // header minimum.
            let liveMinWidth = window.contentMinSize.width
            if liveMinWidth != lastWrittenMinWidth {
                headerDrivenMinWidth = liveMinWidth
            }
            let finalWidth = max(width, headerDrivenMinWidth)
            let newMinSize = NSSize(width: finalWidth, height: parent.minimumWindowHeight)
            let oldMinSize = window.contentMinSize
            paneLog("applyContentMinSize: \(components) → paneMin=\(width) header=\(headerDrivenMinWidth) final=\(finalWidth)x\(parent.minimumWindowHeight); old=\(oldMinSize.width)x\(oldMinSize.height); windowFrame=\(window.frame.width)")
            if window.contentMinSize != newMinSize {
                window.contentMinSize = newMinSize
                paneLog("  wrote contentMinSize")
            }
            lastWrittenMinWidth = finalWidth
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

        /// Take over NSSplitView's layout pass entirely. This is
        /// the only mechanism that reliably pins the folder pane
        /// at `defaultFolderTreeWidth` (or 0 when hidden) under
        /// every kind of window-resize / split-toggle pressure;
        /// holding priority and Auto Layout constraints on
        /// arranged subviews are both silently violated by
        /// NSSplitView when the container would otherwise have to
        /// give the file area negative width.
        ///
        /// Preview drag still works because NSSplitView updates
        /// `previewHost.frame.width` directly during the tracking
        /// loop (before calling this method), and we read that
        /// value back as the source of truth — we only enforce
        /// `previewHost`'s minimum width and recompute the file
        /// area as the remainder.
        func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
            guard let folder = folderHost,
                  let fileArea = fileAreaHost,
                  let preview = previewHost else { return }
            paneLog("resizeSubviewsWithOldSize: total=\(splitView.bounds.width) folderVisible=\(parent.isFolderVisible) previewVisible=\(parent.isPreviewVisible)")
            let totalWidth = splitView.bounds.width
            let totalHeight = splitView.bounds.height
            let divider = splitView.dividerThickness

            let folderVisible = parent.isFolderVisible && !folder.isHidden
            let previewVisible = parent.isPreviewVisible && !preview.isHidden

            let folderWidth: CGFloat = folderVisible
                ? CGFloat(TerminalFileManagerLayout.defaultFolderTreeWidth)
                : 0

            // Preview width is whatever NSSplitView's current
            // tracking state (drag) or post-toggle restore
            // (setPosition) made it, clamped to its own minimum
            // and to whatever space is left after folder + file
            // area minimum.
            var previewWidth: CGFloat = 0
            if previewVisible {
                let currentPreviewWidth = preview.frame.width
                let proposed = currentPreviewWidth > 0
                    ? currentPreviewWidth
                    : CGFloat(parent.previewWidth)
                let foldersDividers = (folderVisible ? folderWidth + divider : 0) + divider
                let maxPreview = max(0, totalWidth - foldersDividers - parent.fileAreaMinimumWidth)
                previewWidth = min(max(LayoutPane.preview.minimumWidth, proposed), maxPreview)
            }

            var dividersShown: CGFloat = 0
            if folderVisible { dividersShown += divider }
            if previewVisible { dividersShown += divider }

            let fileAreaWidth = max(0, totalWidth - folderWidth - previewWidth - dividersShown)

            var x: CGFloat = 0
            folder.frame = NSRect(x: x, y: 0, width: folderWidth, height: totalHeight)
            if folderVisible { x += folderWidth + divider }
            fileArea.frame = NSRect(x: x, y: 0, width: fileAreaWidth, height: totalHeight)
            x += fileAreaWidth
            if previewVisible { x += divider }
            preview.frame = NSRect(x: x, y: 0, width: previewWidth, height: totalHeight)
        }

        /// Lower bound for each divider's position. NSSplitView calls
        /// this during user drag to enforce per-pane minimums.
        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            switch dividerIndex {
            case 0:
                // Folder is width-locked at defaultFolderTreeWidth
                // (or 0 when hidden) — min == max so the divider
                // cannot be dragged.
                return parent.isFolderVisible
                    ? CGFloat(TerminalFileManagerLayout.defaultFolderTreeWidth)
                    : 0
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
                // Folder is width-locked — pin the divider to the
                // default folder width (or 0 when hidden).
                _ = totalWidth
                return parent.isFolderVisible
                    ? CGFloat(TerminalFileManagerLayout.defaultFolderTreeWidth)
                    : 0
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

        /// Disable divider 0 (folder/file boundary) drag entirely:
        /// folder is width-locked, so any drag would just snap back
        /// to 200pt via `resizeSubviewsWithOldSize`. Returning an
        /// empty hit rect means NSSplitView never starts a tracking
        /// loop for it. Divider 1 (file/preview) keeps its full
        /// drawn rect so preview drag still works.
        func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
            dividerIndex == 0 ? .zero : proposedEffectiveRect
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
            // Window live-resize is the only "external" event we
            // want to ignore here — its delegate firings reflect
            // NSSplitView's clamping decisions, not user intent.
            // `split.inLiveResize` is too broad: it is ALSO true
            // during a divider drag (NSSplitView puts itself into
            // live-resize mode while tracking the mouse), and
            // skipping those firings means the user's divider drag
            // never persists. Filter on the window instead.
            let windowLive = split.window?.inLiveResize ?? false
            guard !windowLive, !isApplyingProgrammaticLayout else {
                paneLog("splitViewDidResizeSubviews: skip (live=\(windowLive) programmatic=\(isApplyingProgrammaticLayout)) | folder=\(folder.frame.width) preview=\(preview.frame.width)")
                return
            }

            // Only preview is user-resizable in this split view —
            // folder is width-locked in
            // `splitView(_:resizeSubviewsWithOldSize:)`. Read the
            // post-drag preview frame and persist it if it differs
            // from the stored value.
            let contentWidth = split.bounds.width
            paneLog("splitViewDidResizeSubviews: evaluating | content=\(contentWidth) preview=\(preview.frame.width) stored preview=\(parent.previewWidth)")

            guard parent.isPreviewVisible, !preview.isHidden else { return }

            let newPreviewWidth = Double(preview.frame.width)
            // Pre-layout transient: the frame can momentarily be 0
            // (subview not yet sized) — never a user choice.
            let isPreLayout = newPreviewWidth < Double(LayoutPane.preview.minimumWidth)
            // The window may force preview narrower than stored if
            // there isn't room. Don't persist those forced clamps.
            let divider = split.dividerThickness
            var previewRoom = contentWidth - parent.fileAreaMinimumWidth - divider
            if parent.isFolderVisible, !folder.isHidden {
                previewRoom -= folder.frame.width + divider
            }
            let windowAllowsStored = previewRoom >= CGFloat(parent.previewWidth)
            let isForcedShrink = !windowAllowsStored && newPreviewWidth < parent.previewWidth
            let diff = abs(newPreviewWidth - parent.previewWidth)
            guard diff > 0.5, !isPreLayout, !isForcedShrink else {
                if isPreLayout {
                    paneLog("  skip preview (pre-layout: width=\(newPreviewWidth) < min=\(LayoutPane.preview.minimumWidth))")
                } else if isForcedShrink {
                    paneLog("  skip preview (forced clamp; previewRoom=\(previewRoom) < stored=\(parent.previewWidth))")
                }
                return
            }
            paneLog("  persist preview=\(newPreviewWidth) (was \(parent.previewWidth), previewRoom=\(previewRoom))")
            parent.previewWidth = newPreviewWidth
            // Stored width changed: refresh contentMinSize so a
            // wider preview raises the window floor.
            applyContentMinSize()
        }
    }
}
#endif
