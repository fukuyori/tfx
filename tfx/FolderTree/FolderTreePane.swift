#if os(macOS)
import SwiftUI

struct FolderTreePane: View {
    @ObservedObject var model: FileBrowserModel
    let isActive: Bool
    let activate: () -> Void

    @State private var pinnedContentHeight: CGFloat = 0
    private let pinnedSectionMaxHeight: CGFloat = 240
    /// Bumped when the user taps the "collapse all folders"
    /// button. `folderTreeSection`'s `.onChange` listens and
    /// scrolls the tree back to the root row — without this the
    /// root row can end up off-screen above the viewport if the
    /// user was scrolled down inside a deep subtree.
    @State private var collapseAllRequestID = 0
    @StateObject private var volumeStore = VolumeListStore()
    // Per-section collapse state, persisted like the other layout
    // toggles. Defaults keep every section open.
    @AppStorage("TerminalFileManager.sidebarPinnedCollapsed") private var isPinnedSectionCollapsed = false
    @AppStorage("TerminalFileManager.sidebarDisksCollapsed") private var isDisksSectionCollapsed = false
    @AppStorage("TerminalFileManager.sidebarFoldersCollapsed") private var isFoldersSectionCollapsed = false
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    private var roots: [URL] {
        [URL(fileURLWithPath: "/").standardizedFileURL]
    }

    var body: some View {
        VStack(spacing: 0) {
            outerHeader

            if !model.pinnedFolders.isEmpty {
                FolderTreeSectionHeader(title: "PINNED", isCollapsed: $isPinnedSectionCollapsed)
                if !isPinnedSectionCollapsed {
                    pinnedSection
                }
                Divider()
            }

            FolderTreeSectionHeader(title: "DISKS", isCollapsed: $isDisksSectionCollapsed)
            if !isDisksSectionCollapsed {
                DiskListSection(
                    model: model,
                    volumeStore: volumeStore,
                    isTreeActive: isActive,
                    activateTree: activate
                )
            }
            Divider()

            foldersSectionHeader

            if !isFoldersSectionCollapsed {
                folderTreeSection
            } else {
                Spacer(minLength: 0)
            }
        }
        .background(theme.folderTreeBackground.opacity(design.opacity.background))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isActive ? theme.paneBorderKeyboardTarget : theme.paneBorderInactive, lineWidth: isActive ? 2 : 1)
        )
    }

    private var outerHeader: some View {
        HStack {
            Text("FOLDERS")
            Spacer()
            Button {
                volumeStore.refresh()
                model.reload()
                model.rebuildFolderTree()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Reload")
        }
        .font(design.fonts.swiftUIFont(for: .header, weight: .semibold))
        .foregroundStyle(theme.headerForeground)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background((isActive ? theme.titleBarBackgroundActive : theme.folderTreeBackground).opacity(design.opacity.background))
    }

    /// Folders section header with a trailing "collapse all" button.
    private var foldersSectionHeader: some View {
        FolderTreeSectionHeader(title: "FOLDERS", isCollapsed: $isFoldersSectionCollapsed) {
            Button {
                model.collapseAllFolders()
                collapseAllRequestID &+= 1
            } label: {
                Image(systemName: "rectangle.compress.vertical")
            }
            .buttonStyle(.borderless)
            .help("Collapse all folders")
        }
    }

    private var pinnedSection: some View {
        ScrollViewReader { pinnedProxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(model.pinnedFolders.enumerated()), id: \.element) { index, pinnedFolder in
                        PinnedFolderInsertionSlot(
                            isVisible: model.isPinnedFolderInsertionSlotVisible(at: index),
                            reservesRowSpace: !model.isDraggingPinnedFolder
                        )

                        PinnedFolderTreeRow(
                            model: model,
                            url: pinnedFolder,
                            isTreeActive: isActive,
                            activateTree: activate
                        )
                    }

                    PinnedFolderInsertionSlot(
                        isVisible: model.isPinnedFolderInsertionSlotVisible(at: model.pinnedFolders.count),
                        reservesRowSpace: !model.isDraggingPinnedFolder
                    )
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                updatePinnedContentHeight(geo.size.height)
                            }
                            .onChange(of: geo.size.height) { _, newHeight in
                                updatePinnedContentHeight(newHeight)
                            }
                    }
                )
                // Make the whole rows-VStack hit-testable so the
                // drop delegate receives location updates anywhere
                // inside the section, not only directly over a row
                // (which would miss the inter-row gaps the insertion
                // slots open into).
                .contentShape(Rectangle())
            }
            .frame(height: min(max(pinnedContentHeight, 1), pinnedSectionMaxHeight))
            .overlay {
                PinnedFolderExternalDropOverlay(model: model, rowHeight: 26)
            }
            .onChange(of: model.folderTreeSelection) {
                if model.folderTreeSelectionSection == .pinned {
                    scrollToSelection(with: pinnedProxy)
                }
            }
            .onChange(of: model.folderTreeSelectionSection) {
                if model.folderTreeSelectionSection == .pinned {
                    scrollToSelection(with: pinnedProxy)
                }
            }
        }
    }

    private var folderTreeSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // `LazyVStack` so deeply-expanded folder trees
                // (hundreds of rows) don't materialize every
                // `FolderTreeRow` up front. Rows are built only
                // as they scroll into view, cutting initial-paint
                // cost and memory pressure on big trees like / .
                LazyVStack(spacing: 0) {
                    ForEach(roots, id: \.self) { root in
                        FolderTreeRow(
                            model: model,
                            url: root,
                            depth: 0,
                            isTreeActive: isActive,
                            selectionSection: .tree,
                            activateTree: activate
                        )
                    }
                }
            }
            // Force SwiftUI to remount the ScrollView when the
            // user taps "collapse all". Bumping the `.id()` is
            // the only reliable way to reset the ScrollView's
            // scroll offset back to the top: `proxy.scrollTo`
            // can't find the root row in a `LazyVStack` when the
            // root has been lazy-evicted (off-screen), and even
            // when it can, the ScrollView often keeps the old
            // out-of-bounds offset after content shrinks from
            // hundreds of rows to one.
            .id(collapseAllRequestID)
            // Anchor mode comes from the model: navigation arriving
            // from outside the tree (file pane, pinned folders, DISKS)
            // pins the current folder's row to the top of the FOLDERS
            // viewport; selections made inside the tree itself only
            // scroll the minimum needed to stay visible, so the row
            // the user clicked doesn't jump away from under the
            // cursor.
            .onChange(of: model.folderTreeSelection) {
                if model.folderTreeSelectionSection == .tree {
                    scrollToSelection(with: proxy, anchor: autoScrollAnchor)
                }
            }
            .onChange(of: model.folderTreeSelectionSection) {
                if model.folderTreeSelectionSection == .tree {
                    scrollToSelection(with: proxy, anchor: autoScrollAnchor)
                }
            }
            .onChange(of: isActive) {
                if isActive && model.folderTreeSelectionSection == .tree {
                    scrollToSelection(with: proxy, anchor: autoScrollAnchor)
                }
            }
            // Navigation that doesn't move the tree selection — a
            // pinned-folder click keeps the selection in the PINNED
            // section — must still bring the file listing's folder to
            // the top of the FOLDERS viewport, so track the current
            // directory itself as well.
            .onChange(of: model.currentDirectory) {
                scrollToRow(
                    FolderTreeRowID(
                        url: model.currentDirectory.standardizedFileURL,
                        section: .tree
                    ),
                    with: proxy,
                    anchor: autoScrollAnchor
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            activate()
            model.ensureFolderTreeSelection()
        }
    }

    /// `.top` when the last navigation came from outside the tree,
    /// nil (scroll the minimum to stay visible) for in-tree selection.
    private var autoScrollAnchor: UnitPoint? {
        model.folderTreeScrollsToTopOnChange ? .top : nil
    }

    private func scrollToSelection(with proxy: ScrollViewProxy, anchor: UnitPoint? = nil) {
        scrollToRow(model.selectedFolderTreeRowID, with: proxy, anchor: anchor)
    }

    private func scrollToRow(_ rowID: FolderTreeRowID, with proxy: ScrollViewProxy, anchor: UnitPoint?) {
        // See `FilePaneFileList.scrollToSelection` — `ScrollViewProxy`
        // rejects access during view updates, and `Task.yield()`
        // can still resume inside the same update transaction.
        // `DispatchQueue.main.async` always lands on the next
        // runloop tick, safely after the current update completes.
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.08)) {
                proxy.scrollTo(rowID, anchor: anchor)
            }
        }
    }

    private func updatePinnedContentHeight(_ height: CGFloat) {
        Task { @MainActor in
            await Task.yield()
            guard abs(pinnedContentHeight - height) > 0.5 else { return }
            pinnedContentHeight = height
        }
    }
}

#endif
