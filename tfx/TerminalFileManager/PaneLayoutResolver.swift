#if os(macOS)
import CoreGraphics

struct MainPaneLayoutResult: Equatable {
    let folderWidth: CGFloat
    let fileAreaWidth: CGFloat
    let previewWidth: CGFloat
}

struct FileSplitLayoutResult: Equatable {
    let leftWidth: CGFloat
    let rightWidth: CGFloat
    let effectiveRatio: CGFloat
    let canResize: Bool
}

enum PaneLayoutResolver {
    static func mainPanes(
        totalWidth: CGFloat,
        dividerWidth: CGFloat,
        isFolderVisible: Bool,
        isPreviewVisible: Bool,
        isSplitViewVisible: Bool,
        storedFolderWidth: Double,
        storedPreviewWidth: Double,
        minimumFolderWidth: CGFloat = TerminalFileManagerLayout.minimumFolderTreeWidth,
        minimumPreviewWidth: CGFloat = TerminalFileManagerLayout.minimumPreviewPaneWidth,
        minimumFilePaneWidth: CGFloat = TerminalFileManagerLayout.minimumFilePaneWidth
    ) -> MainPaneLayoutResult {
        let safeTotal = max(0, totalWidth)
        let visibleDividerWidth = dividerWidth
            * CGFloat((isFolderVisible ? 1 : 0) + (isPreviewVisible ? 1 : 0))
        let fileMinimum = fileAreaMinimumWidth(
            isSplitViewVisible: isSplitViewVisible,
            dividerWidth: dividerWidth,
            minimumFilePaneWidth: minimumFilePaneWidth
        )

        var folderWidth = isFolderVisible
            ? max(minimumFolderWidth, CGFloat(storedFolderWidth))
            : 0
        var previewWidth = isPreviewVisible
            ? max(minimumPreviewWidth, CGFloat(storedPreviewWidth))
            : 0

        var fileAreaWidth = safeTotal - visibleDividerWidth - folderWidth - previewWidth
        if fileAreaWidth < fileMinimum {
            var deficit = fileMinimum - fileAreaWidth

            if isPreviewVisible {
                let shrink = min(deficit, max(0, previewWidth - minimumPreviewWidth))
                previewWidth -= shrink
                deficit -= shrink
            }

            if deficit > 0, isFolderVisible {
                let shrink = min(deficit, max(0, folderWidth - minimumFolderWidth))
                folderWidth -= shrink
                deficit -= shrink
            }

            fileAreaWidth = safeTotal - visibleDividerWidth - folderWidth - previewWidth
        }

        if fileAreaWidth < 0 {
            fileAreaWidth = 0
        }

        return MainPaneLayoutResult(
            folderWidth: roundedPoint(folderWidth),
            fileAreaWidth: roundedPoint(fileAreaWidth),
            previewWidth: roundedPoint(max(0, previewWidth))
        )
    }

    static func fileSplit(
        totalWidth: CGFloat,
        dividerWidth: CGFloat,
        ratio: CGFloat,
        minimumPaneWidth: CGFloat = TerminalFileManagerLayout.minimumFilePaneWidth
    ) -> FileSplitLayoutResult {
        let availableWidth = max(0, totalWidth - dividerWidth)
        guard availableWidth > 0 else {
            return FileSplitLayoutResult(leftWidth: 0, rightWidth: 0, effectiveRatio: 0.5, canResize: false)
        }

        let minimumTotal = minimumPaneWidth * 2
        guard availableWidth > minimumTotal else {
            let leftWidth = min(minimumPaneWidth, availableWidth)
            let rightWidth = max(0, availableWidth - leftWidth)
            let effectiveRatio = availableWidth > 0 ? leftWidth / availableWidth : 0.5
            return FileSplitLayoutResult(
                leftWidth: roundedPoint(leftWidth),
                rightWidth: roundedPoint(rightWidth),
                effectiveRatio: effectiveRatio,
                canResize: false
            )
        }

        let minRatio = minimumPaneWidth / availableWidth
        let maxRatio = 1 - minRatio
        let clampedRatio = min(max(ratio, minRatio), maxRatio)
        let leftWidth = roundedPoint(availableWidth * clampedRatio)
        let rightWidth = max(0, availableWidth - leftWidth)
        let effectiveRatio = availableWidth > 0 ? leftWidth / availableWidth : clampedRatio

        return FileSplitLayoutResult(
            leftWidth: leftWidth,
            rightWidth: roundedPoint(rightWidth),
            effectiveRatio: effectiveRatio,
            canResize: true
        )
    }

    static func fileAreaMinimumWidth(
        isSplitViewVisible: Bool,
        dividerWidth: CGFloat = TerminalFileManagerLayout.dividerWidth,
        minimumFilePaneWidth: CGFloat = TerminalFileManagerLayout.minimumFilePaneWidth
    ) -> CGFloat {
        if isSplitViewVisible {
            return minimumFilePaneWidth * 2 + dividerWidth
        }
        return minimumFilePaneWidth
    }

    private static func roundedPoint(_ value: CGFloat) -> CGFloat {
        value.rounded()
    }
}
#endif
