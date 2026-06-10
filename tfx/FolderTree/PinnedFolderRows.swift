#if os(macOS)
import SwiftUI

struct PinnedFolderTreeRow: View {
    @ObservedObject var model: FileBrowserModel
    let url: URL
    let isTreeActive: Bool
    let activateTree: () -> Void
    @State private var rowHeight: CGFloat = 26
    @State private var dragTranslationY: CGFloat = 0
    @Environment(\.design) private var design

    var body: some View {
        rowContent
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updateRowHeight(proxy.size.height)
                        }
                        .onChange(of: proxy.size.height) { _, newHeight in
                            updateRowHeight(newHeight)
                        }
                }
            )
            .opacity(model.isDraggingPinnedFolder(url) ? 0 : 1)
            .overlay(alignment: .topLeading) {
                if showsFloatingDragRow {
                    rowContent
                        .offset(y: dragTranslationY)
                        .opacity(design.opacity.dragPreview)
                        .shadow(color: .black.opacity(design.opacity.dragPreviewShadow), radius: 6, x: 0, y: 3)
                        .allowsHitTesting(false)
                }
            }
            .zIndex(model.isDraggingPinnedFolder(url) ? 2 : 0)
            .highPriorityGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        model.beginPinnedFolderDrag(url)
                        dragTranslationY = value.translation.height
                        model.updateDraggedPinnedFolder(translationY: value.translation.height, rowHeight: rowHeight)
                    }
                    .onEnded { _ in
                        dragTranslationY = 0
                        model.finishPinnedFolderDrag(applyingMove: true)
                    }
            )
            .help("Drag to reorder pinned folders")
    }

    private var rowContent: some View {
        FolderTreeRow(
            model: model,
            url: url,
            depth: 0,
            isTreeActive: isTreeActive,
            selectionSection: .pinned,
            allowsExpansion: false,
            activateTree: activateTree
        )
    }

    private var showsFloatingDragRow: Bool {
        model.isDraggingPinnedFolder(url) && abs(dragTranslationY) > 0.5
    }

    private func updateRowHeight(_ height: CGFloat) {
        Task { @MainActor in
            await Task.yield()
            guard abs(rowHeight - height) > 0.5 else { return }
            rowHeight = height
        }
    }
}

struct PinnedFolderInsertionSlot: View {
    let isVisible: Bool
    var reservesRowSpace = true
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    /// Visible insertion slot opens by a full pinned-folder row height
    /// so the existing rows physically shift to make space for the
    /// dropped folder, matching the iOS / Finder-sidebar reorder gap.
    /// The visual indicator (a thin colored bar centered in the gap) is
    /// kept subtle so the lift reads as "space to drop here" rather than
    /// a UI element.
    private static let openHeight: CGFloat = 26
    private static let compactHeight: CGFloat = 2

    var body: some View {
        ZStack {
            // Outer rectangle owns the layout height. When `isVisible`
            // is true it claims a full row's worth of vertical space so
            // rows below physically shift down.
            Rectangle()
                .fill(Color.clear)
                .frame(height: isVisible ? slotHeight : 0)

            if isVisible {
                // Inner pill: ~2pt tall accent bar centered in the slot,
                // so the user sees a clear "insert here" mark without
                // the whole gap looking like a giant UI element.
                Capsule()
                    .fill(theme.paneBorderKeyboardTarget.opacity(design.opacity.dropIndicator))
                    .frame(height: 2)
                    .padding(.horizontal, 10)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isVisible)
    }

    private var slotHeight: CGFloat {
        reservesRowSpace ? Self.openHeight : Self.compactHeight
    }
}
#endif
