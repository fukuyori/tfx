#if os(macOS)
import SwiftUI

struct PinnedFolderTreeRow: View {
    @ObservedObject var model: FileBrowserModel
    let url: URL
    let isTreeActive: Bool
    let activateTree: () -> Void
    @State private var rowHeight: CGFloat = 26
    @State private var dragTranslationY: CGFloat = 0

    var body: some View {
        FolderTreeRow(
            model: model,
            url: url,
            depth: 0,
            isTreeActive: isTreeActive,
            selectionSection: .pinned,
            allowsExpansion: false,
            activateTree: activateTree
        )
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            rowHeight = proxy.size.height
                        }
                        .onChange(of: proxy.size.height) {
                            rowHeight = proxy.size.height
                        }
                }
            )
            .offset(y: dragTranslationY)
            .opacity(model.isDraggingPinnedFolder(url) ? 0.82 : 1)
            .zIndex(model.isDraggingPinnedFolder(url) ? 1 : 0)
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
}

struct PinnedFolderInsertionSlot: View {
    let isVisible: Bool

    var body: some View {
        Rectangle()
            .fill(Color.green.opacity(isVisible ? 0.75 : 0))
            .frame(height: isVisible ? 10 : 0)
            .padding(.horizontal, isVisible ? 10 : 0)
            .animation(.easeOut(duration: 0.08), value: isVisible)
    }
}
#endif
