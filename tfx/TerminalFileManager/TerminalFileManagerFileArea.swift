#if os(macOS)
import SwiftUI

struct FileSplitDragStart {
    let availableWidth: CGFloat
    let ratio: CGFloat
}

extension TerminalFileManagerView {
    @ViewBuilder
    var fileArea: some View {
        if isSplitViewVisible {
            GeometryReader { geometry in
                let totalWidth = max(geometry.size.width, 0)
                let dividerWidth = TerminalFileManagerLayout.dividerWidth
                let splitLayout = PaneLayoutResolver.fileSplit(
                    totalWidth: totalWidth,
                    dividerWidth: dividerWidth,
                    ratio: fileSplitRatio
                )

                HStack(spacing: 0) {
                    filePane(.left)
                        .frame(width: splitLayout.leftWidth, height: geometry.size.height)

                    FileSplitDragHandle(
                        canResize: splitLayout.canResize,
                        onStarted: {
                            fileSplitDragStart = FileSplitDragStart(
                                availableWidth: max(0, totalWidth - dividerWidth),
                                ratio: splitLayout.effectiveRatio
                            )
                        },
                        onChanged: { translation in
                            updateFileSplitRatio(
                                translation: translation,
                                totalWidth: totalWidth,
                                dividerWidth: dividerWidth
                            )
                        },
                        onEnded: {
                            fileSplitDragStart = nil
                        }
                    )
                        .frame(width: dividerWidth, height: geometry.size.height)

                    filePane(.right)
                        .frame(width: splitLayout.rightWidth, height: geometry.size.height)
                }
                .frame(width: totalWidth, height: geometry.size.height)
                .clipped()
                .onChange(of: geometry.size.width) { oldValue, newValue in
                    reconcileFileSplitRatioAfterWidthChange(
                        oldWidth: oldValue,
                        newWidth: newValue,
                        dividerWidth: dividerWidth
                    )
                }
            }
        } else {
            filePane(activePane)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func updateFileSplitRatio(
        translation: Double,
        totalWidth: CGFloat,
        dividerWidth: CGFloat
    ) {
        let availableWidth = max(0, totalWidth - dividerWidth)
        guard availableWidth > TerminalFileManagerLayout.minimumFilePaneWidth * 2 else { return }

        let start = fileSplitDragStart ?? FileSplitDragStart(
            availableWidth: availableWidth,
            ratio: PaneLayoutResolver.fileSplit(
                totalWidth: totalWidth,
                dividerWidth: dividerWidth,
                ratio: fileSplitRatio
            ).effectiveRatio
        )
        if fileSplitDragStart == nil {
            fileSplitDragStart = start
        }

        let minimum = TerminalFileManagerLayout.minimumFilePaneWidth
        let proposedLeftWidth = start.availableWidth * start.ratio + CGFloat(translation)
        let clampedLeftWidth = min(max(proposedLeftWidth, minimum), availableWidth - minimum)
        fileSplitRatio = clampedLeftWidth / availableWidth
    }

    func reconcileFileSplitRatioAfterWidthChange(
        oldWidth: CGFloat,
        newWidth: CGFloat,
        dividerWidth: CGFloat
    ) {
        let oldLayout = PaneLayoutResolver.fileSplit(
            totalWidth: max(0, oldWidth),
            dividerWidth: dividerWidth,
            ratio: fileSplitRatio
        )
        let newLayout = PaneLayoutResolver.fileSplit(
            totalWidth: max(0, newWidth),
            dividerWidth: dividerWidth,
            ratio: oldLayout.effectiveRatio
        )
        guard abs(newLayout.effectiveRatio - fileSplitRatio) > 0.0001 else { return }
        fileSplitRatio = newLayout.effectiveRatio
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
                executeUserCommand: { command, selection in
                    activePane = paneID
                    activeArea = .files
                    executeUserCommand(command, selection: selection, in: paneModel)
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
