#if os(macOS)
import SwiftUI

struct FolderTreePane: View {
    @ObservedObject var model: FileBrowserModel
    let isActive: Bool
    let activate: () -> Void

    private var roots: [URL] {
        [URL(fileURLWithPath: "/").standardizedFileURL]
    }

    var body: some View {
        VStack(spacing: 0) {
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

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if !model.pinnedFolders.isEmpty {
                            FolderTreeSectionHeader(title: "PINNED")

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

                            FolderTreeSectionHeader(title: "FOLDERS")
                        }

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
                    scrollToSelection(with: proxy)
                }
                .onChange(of: model.folderTreeSelectionSection) {
                    scrollToSelection(with: proxy)
                }
                .onChange(of: isActive) {
                    if isActive {
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
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isActive ? Color.green : Color.gray.opacity(0.35), lineWidth: isActive ? 2 : 1)
        )
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
