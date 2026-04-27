#if os(macOS)
import SwiftUI

extension TerminalFileManagerView {
    @ViewBuilder
    var fileArea: some View {
        if isSplitViewVisible {
            GeometryReader { geometry in
                let totalWidth = max(geometry.size.width, 760)
                let dividerWidth: CGFloat = 1
                let availableWidth = max(300, totalWidth - dividerWidth)
                let leftWidth = clampedLeftFileWidth(availableWidth: availableWidth)
                let rightWidth = max(260, availableWidth - leftWidth)

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
            }
        } else {
            filePane(activePane)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func clampedLeftFileWidth(availableWidth: CGFloat) -> CGFloat {
        let minPaneWidth = min(260.0, max(120.0, Double(availableWidth) / 2))
        let maxPaneWidth = max(minPaneWidth, Double(availableWidth) - minPaneWidth)
        return CGFloat(clamp(Double(availableWidth) * fileSplitRatio, min: minPaneWidth, max: maxPaneWidth))
    }

    func filePane(_ paneID: BrowserPaneID) -> some View {
        let paneModel = paneID == .left ? leftModel : rightModel

        return FilePane(
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

#endif
