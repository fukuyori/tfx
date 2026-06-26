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
/// The split view contains exactly three subviews in this
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
    /// assigned zero width by the resolver; the split view delegate
    /// suppresses the corresponding divider.
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

        // Use plain subviews, not arranged subviews. NSSplitView's
        // arranged-subview/collapse machinery can retain automatic
        // sizing decisions that fight our resolver-driven frames
        // (most visibly: the file area can keep pushing the preview
        // down to zero width after restart). We still use NSSplitView
        // for native divider tracking and delegate hooks, but every
        // pane frame is assigned by `resizeSubviewsWithOldSize`.
        split.addSubview(folderHost)
        split.addSubview(fileAreaHost)
        split.addSubview(previewHost)

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
            context.coordinator.applyResolvedFrames(in: split)
            DispatchQueue.main.async {
                context.coordinator.applyResolvedFrames(in: split)
            }
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
            //      to the hard minimums for the current pane set.
            //   2. `applyVisibility` flips `isHidden` on the side
            //      hosts; our `resizeSubviewsWithOldSize` reads
            //      these flags to decide which panes get width.
            //
            // Pane visibility changes intentionally do not resize
            // the window. The current content width is reallocated
            // inside the split view instead.
            context.coordinator.applyContentMinSize()
            context.coordinator.applyVisibility(animated: false)
            context.coordinator.applyResolvedFrames(in: nsView)
            DispatchQueue.main.async {
                context.coordinator.applyResolvedFrames(in: nsView)
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

        /// The header-driven minimum content width that SwiftUI
        /// propagates into `NSWindow.contentMinSize` from the view
        /// tree (the search field + toolbar row can't render below a
        /// certain width). `applyContentMinSize` must never push the
        /// window floor below this — doing so lets the user drag the
        /// window narrower than the header needs, at which point the
        /// header (and the `NSSplitView` it shares the column with)
        /// overflows the window and gets centered + clipped, pushing
        /// the width-stable folder pane off the left edge. Captured
        /// from SwiftUI's own writes (see `applyContentMinSize`),
        /// never hard-coded, so it tracks localization / font changes.
        private var headerDrivenMinWidth: CGFloat = 0

        /// Last width we wrote to `contentMinSize` ourselves. Used to
        /// tell our own writes apart from SwiftUI's: when the live
        /// value differs from this, SwiftUI re-derived it from the
        /// view tree, so it is an authoritative header-driven floor.
        private var lastWrittenMinWidth: CGFloat = -1

        /// Preview width produced by window resizing. This is a
        /// continuity value for the current session layout, not a
        /// preference: direct preview-divider drags still write
        /// `parent.previewWidth`, while window resize only updates
        /// this transient display width.
        private var displayedPreviewWidth: Double?

        /// Last split-view width we laid out. Used to route window
        /// width deltas into the preview pane while it is visible.
        private var lastAppliedTotalWidth: CGFloat?

        init(parent: MainPaneSplitView) {
            self.parent = parent
        }

        // MARK: View hosting

        func makeHost(for content: AnyView) -> NSHostingView<AnyView> {
            let host = NSHostingView(rootView: content)
            host.translatesAutoresizingMaskIntoConstraints = true
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

        /// Keep hosted subviews alive and let the manual layout
        /// pass assign zero width for logically hidden panes.
        ///
        /// `NSSplitView` has its own collapsed-subview behavior when
        /// arranged subviews are hidden. That behavior fights the
        /// resolver-driven frame assignment and can leave a pane
        /// collapsed after its visibility flag flips back on. Keeping
        /// the hosts unhidden makes `parent.isFolderVisible` /
        /// `parent.isPreviewVisible` the only visibility source of
        /// truth.
        func applyVisibility(animated: Bool) {
            guard let folder = folderHost,
                  let preview = previewHost else { return }
            folder.isHidden = false
            preview.isHidden = false
        }

        // MARK: Window-level state (single owner of contentMinSize)

        /// Write the window's `contentMinSize` from hard minimums
        /// for the current pane state. Stored pane widths are user
        /// preferences for normal allocation; they do not raise the
        /// window floor.
        func applyContentMinSize() {
            guard let window = splitView?.window else {
                paneLog("applyContentMinSize: no window yet, skipping")
                return
            }
            let divider = splitView?.dividerThickness ?? 1
            var width = parent.fileAreaMinimumWidth
            var components = "fileArea=\(parent.fileAreaMinimumWidth)"
            if parent.isFolderVisible {
                let folderWidth = LayoutPane.folderTree.minimumWidth
                width += folderWidth + divider
                components += " folderMin=\(folderWidth)+\(divider)"
            }
            if parent.isPreviewVisible {
                let previewWidth = LayoutPane.preview.minimumWidth
                width += previewWidth + divider
                components += " previewMin=\(previewWidth)+\(divider)"
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

        // MARK: NSSplitViewDelegate — constraints & persistence

        /// Take over NSSplitView's layout pass entirely so pane
        /// visibility changes reallocate the current window width
        /// instead of resizing the window. Folder tree and preview
        /// use stored widths as preferences, but can temporarily
        /// shrink to their hard minimums. Folder tree never grows
        /// beyond its stored width and is the last shrink fallback.
        func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
            applyResolvedFrames(in: splitView)
        }

        func applyResolvedFrames(in splitView: NSSplitView) {
            guard let folder = folderHost,
                  let fileArea = fileAreaHost,
                  let preview = previewHost else { return }
            let totalWidth = splitView.bounds.width
            let totalHeight = splitView.bounds.height
            guard totalWidth > 0, totalHeight > 0 else {
                paneLog("applyResolvedFrames: skip zero bounds \(totalWidth)x\(totalHeight)")
                return
            }
            paneLog("applyResolvedFrames: total=\(totalWidth) folderVisible=\(parent.isFolderVisible) previewVisible=\(parent.isPreviewVisible)")
            let divider = splitView.dividerThickness

            let folderVisible = parent.isFolderVisible
            let previewVisible = parent.isPreviewVisible

            let windowLive = splitView.window?.inLiveResize ?? false
            let isDividerDrag = splitView.inLiveResize && !windowLive
            if !previewVisible {
                displayedPreviewWidth = nil
            }
            let preferredFolderWidth = isDividerDrag && folder.frame.width >= LayoutPane.folderTree.minimumWidth
                ? Double(folder.frame.width)
                : parent.folderWidth
            let preferredPreviewWidth: Double?
            if isDividerDrag && preview.frame.width >= LayoutPane.preview.minimumWidth {
                preferredPreviewWidth = Double(preview.frame.width)
                displayedPreviewWidth = nil
            } else if previewVisible,
                      windowLive,
                      let lastAppliedTotalWidth {
                let basePreviewWidth = displayedPreviewWidth
                    ?? (preview.frame.width >= LayoutPane.preview.minimumWidth
                        ? Double(preview.frame.width)
                        : parent.previewWidth)
                preferredPreviewWidth = basePreviewWidth + Double(totalWidth - lastAppliedTotalWidth)
            } else {
                preferredPreviewWidth = displayedPreviewWidth
            }

            let layout = PaneLayoutResolver.mainPanes(
                totalWidth: totalWidth,
                dividerWidth: divider,
                isFolderVisible: folderVisible,
                isPreviewVisible: previewVisible,
                isSplitViewVisible: parent.isSplitViewVisible,
                storedFolderWidth: preferredFolderWidth,
                storedPreviewWidth: parent.previewWidth,
                displayedPreviewWidth: preferredPreviewWidth
            )

            var dividersShown: CGFloat = 0
            if folderVisible { dividersShown += divider }
            if previewVisible { dividersShown += divider }

            let folderWidth = layout.folderWidth
            let previewWidth = layout.previewWidth
            let fileAreaWidth = max(0, totalWidth - folderWidth - previewWidth - dividersShown)

            var x: CGFloat = 0
            folder.frame = NSRect(x: x, y: 0, width: folderWidth, height: totalHeight)
            if folderVisible { x += folderWidth + divider }
            fileArea.frame = NSRect(x: x, y: 0, width: fileAreaWidth, height: totalHeight)
            x += fileAreaWidth
            if previewVisible { x += divider }
            preview.frame = NSRect(x: x, y: 0, width: previewWidth, height: totalHeight)
            if previewVisible, windowLive {
                displayedPreviewWidth = Double(previewWidth)
            }
            lastAppliedTotalWidth = totalWidth
            paneLog("  frames folder=\(folderWidth) file=\(fileAreaWidth) preview=\(previewWidth) dividers=\(dividersShown)")
        }

        /// Lower bound for each divider's position. NSSplitView calls
        /// this during user drag to enforce per-pane minimums.
        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            switch dividerIndex {
            case 0:
                // Folder may temporarily shrink below its stored
                // width when the window is narrow, but never below
                // its hard minimum.
                return parent.isFolderVisible
                    ? LayoutPane.folderTree.minimumWidth
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
                // Folder can be user-resized, but only within the
                // space that still leaves the file area and preview
                // at their hard minimums.
                guard parent.isFolderVisible else { return 0 }
                let reservedRight = TerminalFileManagerLayout.widthReservedRightOfFolderTree(
                    isSplitViewVisible: parent.isSplitViewVisible,
                    isPreviewVisible: parent.isPreviewVisible
                )
                return max(
                    LayoutPane.folderTree.minimumWidth,
                    totalWidth - reservedRight
                )
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
            case 0: return !parent.isFolderVisible
            case 1: return !parent.isPreviewVisible
            default: return false
            }
        }

        /// Keep both visible dividers draggable. Per-pane minimums are
        /// enforced by the coordinate-constraint delegate methods.
        func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
            proposedEffectiveRect
        }

        /// Persist user-drag results back to AppStorage. Skipped:
        /// - during `inLiveResize` (window itself being resized),
        ///   because window resize legitimately changes file area
        ///   width but pane widths shouldn't be touched (and we
        ///   don't write them back regardless);
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
            guard !windowLive else {
                paneLog("splitViewDidResizeSubviews: skip (window live resize) | folder=\(folder.frame.width) preview=\(preview.frame.width)")
                return
            }

            // Read post-drag side-pane frames and persist the values
            // if they differ from the stored preference. Forced
            // clamps from window size are skipped below.
            let contentWidth = split.bounds.width
            paneLog("splitViewDidResizeSubviews: evaluating | content=\(contentWidth) folder=\(folder.frame.width) stored folder=\(parent.folderWidth) preview=\(preview.frame.width) stored preview=\(parent.previewWidth)")

            if parent.isFolderVisible {
                let newFolderWidth = Double(folder.frame.width)
                let isPreLayout = newFolderWidth < Double(LayoutPane.folderTree.minimumWidth)
                let divider = split.dividerThickness
                var folderRoom = contentWidth - parent.fileAreaMinimumWidth - divider
                if parent.isPreviewVisible {
                    folderRoom -= LayoutPane.preview.minimumWidth + divider
                }
                let windowAllowsStored = folderRoom >= CGFloat(parent.folderWidth)
                let isForcedShrink = !windowAllowsStored && newFolderWidth < parent.folderWidth
                let diff = abs(newFolderWidth - parent.folderWidth)
                if diff > 0.5, !isPreLayout, !isForcedShrink {
                    paneLog("  persist folder=\(newFolderWidth) (was \(parent.folderWidth), folderRoom=\(folderRoom))")
                    parent.folderWidth = newFolderWidth
                } else if isPreLayout {
                    paneLog("  skip folder (pre-layout: width=\(newFolderWidth) < min=\(LayoutPane.folderTree.minimumWidth))")
                } else if isForcedShrink {
                    paneLog("  skip folder (forced clamp; folderRoom=\(folderRoom) < stored=\(parent.folderWidth))")
                }
            }

            guard parent.isPreviewVisible else {
                applyContentMinSize()
                return
            }

            let newPreviewWidth = Double(preview.frame.width)
            // Pre-layout transient: the frame can momentarily be 0
            // (subview not yet sized) — never a user choice.
            let isPreLayout = newPreviewWidth < Double(LayoutPane.preview.minimumWidth)
            // The window may force preview narrower than stored if
            // there isn't room. Don't persist those forced clamps.
            let divider = split.dividerThickness
            var previewRoom = contentWidth - parent.fileAreaMinimumWidth - divider
            if parent.isFolderVisible {
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
