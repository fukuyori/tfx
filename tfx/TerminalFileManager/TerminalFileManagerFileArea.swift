#if os(macOS)
import SwiftUI

extension TerminalFileManagerView {
    @ViewBuilder
    var fileArea: some View {
        if isSplitViewVisible {
            GeometryReader { geometry in
                let totalWidth = max(geometry.size.width, 0)
                let dividerWidth: CGFloat = 1
                let availableWidth = max(0, totalWidth - dividerWidth)
                let leftWidth = clampedLeftFileWidth(availableWidth: availableWidth)
                let rightWidth = max(0, availableWidth - leftWidth)

                HStack(spacing: 0) {
                    filePane(.left)
                        .frame(width: leftWidth, height: geometry.size.height)

                    SplitDragHandle {
                        fileSplitDragStartRatio = fileSplitRatio
                    } onChanged: { translation in
                        let baseRatio = fileSplitDragStartRatio ?? fileSplitRatio
                        let availableWidthValue = Double(availableWidth)
                        let baseWidth = availableWidthValue * baseRatio
                        fileSplitRatio = clamp((baseWidth + translation) / availableWidthValue, min: 0.2, max: 0.8)
                    } onEnded: {
                        fileSplitDragStartRatio = nil
                    }

                    filePane(.right)
                        .frame(width: rightWidth, height: geometry.size.height)
                }
                .frame(width: totalWidth, height: geometry.size.height)
                .clipped()
            }
        } else {
            filePane(activePane)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func clampedLeftFileWidth(availableWidth: CGFloat) -> CGFloat {
        Self.clampedLeftFileWidth(
            availableWidth: availableWidth,
            fileSplitRatio: fileSplitRatio
        )
    }

    func filePane(_ paneID: BrowserPaneID) -> some View {
        let paneModel = paneID == .left ? leftModel : rightModel

        return VStack(spacing: 0) {
            filePaneTabStrip(paneID)

            FilePane(
                model: paneModel,
                paneID: paneID,
                isActivePane: activePane == paneID,
                isKeyboardTarget: activePane == paneID && activeArea == .files,
                fileNameColumnWidth: $fileNameColumnWidth,
                columnConfiguration: FileListColumnConfiguration(rawValue: fileColumnConfigurationRaw),
                activate: {
                    activePane = paneID
                    activeArea = .files
                },
                reloadRelatedPanes: reloadAllPanes
            )
        }
    }

    func filePaneTabStrip(_ paneID: BrowserPaneID) -> some View {
        let paneTabs = tabs(for: paneID)
        let activeID = activeTabID(for: paneID)
        let isPaneActive = activePane == paneID

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(paneTabs) { tab in
                    HStack(spacing: 4) {
                        Button {
                            switchToTab(tab, in: paneID)
                        } label: {
                            Text(tabTitle(for: tab.directory))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(minWidth: 72, maxWidth: 144, minHeight: 24, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .help(tab.directory.path)

                        if shouldShowCloseButton(forTabID: tab.id, activeID: activeID, tabCount: paneTabs.count) {
                            Button {
                                closeActiveTab(in: paneID)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .frame(width: 14, height: 24)
                            }
                            .buttonStyle(.plain)
                            .help("Close Tab")
                        }
                    }
                    .font(design.fonts.swiftUIFont(for: .caption))
                    .foregroundStyle(tab.id == activeID ? theme.folderTreeSelectedForeground : theme.secondaryForeground)
                    .padding(.horizontal, 8)
                    .background(tab.id == activeID ? theme.titleBarBackgroundActive : theme.headerBackground)
                }

                Button {
                    openNewTab(in: paneID)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 24)
                        .foregroundStyle(theme.headerForeground)
                }
                .buttonStyle(.plain)
                .help("New Tab")
            }
        }
        .frame(height: 25)
        .background(theme.headerBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isPaneActive ? theme.paneBorderActive : theme.paneBorderInactive)
                .frame(height: 1)
        }
    }

    func shouldShowCloseButton(forTabID tabID: FilePaneTab.ID, activeID: FilePaneTab.ID, tabCount: Int) -> Bool {
        tabID == activeID && (tabCount > 1 || isSplitViewVisible)
    }

    func tabTitle(for directory: URL) -> String {
        let name = directory.lastPathComponent
        return name.isEmpty ? "/" : name
    }
}

#endif
