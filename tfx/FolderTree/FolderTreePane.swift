#if os(macOS)
import SwiftUI

struct FolderTreePane: View {
    @ObservedObject var model: FileBrowserModel
    let isActive: Bool
    let activate: () -> Void

    @State private var pinnedContentHeight: CGFloat = 0
    private let pinnedSectionMaxHeight: CGFloat = 240

    private var roots: [URL] {
        [URL(fileURLWithPath: "/").standardizedFileURL]
    }

    var body: some View {
        VStack(spacing: 0) {
            outerHeader

            if !model.pinnedFolders.isEmpty {
                pinnedSection
                Divider()
                FolderTreeSectionHeader(title: "FOLDERS")
            }

            folderTreeSection
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isActive ? Color.green : Color.gray.opacity(0.35), lineWidth: isActive ? 2 : 1)
        )
    }

    private var outerHeader: some View {
        HStack {
            Text("FOLDERS")
            Spacer()
            Button {
                model.reload()
                model.rebuildFolderTree()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Reload")
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundStyle(.green)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isActive ? Color.green.opacity(0.16) : Color.black)
    }

    private var pinnedSection: some View {
        VStack(spacing: 0) {
            FolderTreeSectionHeader(title: "PINNED")

            ScrollViewReader { pinnedProxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(model.pinnedFolders.enumerated()), id: \.element) { index, pinnedFolder in
                            PinnedFolderInsertionSlot(isVisible: model.isPinnedFolderInsertionSlotVisible(at: index))

                            PinnedFolderTreeRow(
                                model: model,
                                url: pinnedFolder,
                                isTreeActive: isActive,
                                activateTree: activate
                            )
                        }

                        PinnedFolderInsertionSlot(isVisible: model.isPinnedFolderInsertionSlotVisible(at: model.pinnedFolders.count))
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { pinnedContentHeight = geo.size.height }
                                .onChange(of: geo.size.height) { pinnedContentHeight = geo.size.height }
                        }
                    )
                }
                .frame(height: min(max(pinnedContentHeight, 1), pinnedSectionMaxHeight))
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
        .background(Color.black)
    }

    private var folderTreeSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
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
            .onChange(of: model.folderTreeSelection) {
                if model.folderTreeSelectionSection == .tree {
                    scrollToSelection(with: proxy)
                }
            }
            .onChange(of: model.folderTreeSelectionSection) {
                if model.folderTreeSelectionSection == .tree {
                    scrollToSelection(with: proxy)
                }
            }
            .onChange(of: isActive) {
                if isActive && model.folderTreeSelectionSection == .tree {
                    scrollToSelection(with: proxy)
                }
            }
        }
        .background(Color.black)
        .contentShape(Rectangle())
        .onTapGesture {
            activate()
            model.ensureFolderTreeSelection()
        }
    }

    private func scrollToSelection(with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.08)) {
                proxy.scrollTo(model.selectedFolderTreeRowID)
            }
        }
    }
}

#endif
