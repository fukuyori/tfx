#if os(macOS)
import CoreGraphics
import Testing
@testable import tfx

@Suite("TerminalFileManagerLayout")
struct TerminalFileManagerLayoutTests {
    @Test
    func previewWidthUsesCurrentWindowConstraints() {
        let totalWidth: CGFloat = 980.0
        let folderWidth = TerminalFileManagerView.clampedFolderWidth(
            totalWidth: totalWidth,
            storedFolderWidth: 486,
            isSplitViewVisible: true,
            isPreviewVisible: true
        )

        let previewWidth = TerminalFileManagerView.clampedPreviewWidth(
            totalWidth: totalWidth,
            folderWidth: folderWidth,
            storedPreviewWidth: 320,
            isFolderTreeVisible: true,
            isSplitViewVisible: true
        )

        #expect(previewWidth >= TerminalFileManagerLayout.minimumPreviewPaneWidth)
        #expect(folderWidth + previewWidth <= totalWidth)
    }

    @Test
    func mainPaneLayoutDoesNotGrowFolderBeyondStoredWidth() {
        let layout = PaneLayoutResolver.mainPanes(
            totalWidth: 1_400,
            dividerWidth: 1,
            isFolderVisible: true,
            isPreviewVisible: true,
            isSplitViewVisible: true,
            storedFolderWidth: 220,
            storedPreviewWidth: 320
        )

        #expect(layout.folderWidth == 220)
        #expect(layout.previewWidth == 320)
        #expect(layout.fileAreaWidth == 858)
        #expect(layout.folderWidth + layout.fileAreaWidth + layout.previewWidth + 2 == 1_400)
    }

    @Test
    func mainPaneLayoutUsesTransientPreviewWidthDuringWindowResize() {
        let layout = PaneLayoutResolver.mainPanes(
            totalWidth: 1_400,
            dividerWidth: 1,
            isFolderVisible: true,
            isPreviewVisible: true,
            isSplitViewVisible: true,
            storedFolderWidth: 220,
            storedPreviewWidth: 320,
            displayedPreviewWidth: 520
        )

        #expect(layout.folderWidth == 220)
        #expect(layout.previewWidth == 520)
        #expect(layout.fileAreaWidth == 658)
        #expect(layout.folderWidth + layout.fileAreaWidth + layout.previewWidth + 2 == 1_400)
    }

    @Test
    func mainPaneLayoutShrinksPreviewBeforeFolderTree() {
        let layout = PaneLayoutResolver.mainPanes(
            totalWidth: 930,
            dividerWidth: 1,
            isFolderVisible: true,
            isPreviewVisible: true,
            isSplitViewVisible: true,
            storedFolderWidth: 260,
            storedPreviewWidth: 360
        )

        #expect(layout.folderWidth == 260)
        #expect(layout.previewWidth == 267)
        #expect(layout.fileAreaWidth == TerminalFileManagerLayout.minimumFilePaneWidth * 2 + 1)
        #expect(layout.folderWidth + layout.fileAreaWidth + layout.previewWidth + 2 == 930)
    }

    @Test
    func mainPaneLayoutShrinksFolderTreeLast() {
        let layout = PaneLayoutResolver.mainPanes(
            totalWidth: 823,
            dividerWidth: 1,
            isFolderVisible: true,
            isPreviewVisible: true,
            isSplitViewVisible: true,
            storedFolderWidth: 260,
            storedPreviewWidth: 360
        )

        #expect(layout.previewWidth == TerminalFileManagerLayout.minimumPreviewPaneWidth)
        #expect(layout.folderWidth == 180)
        #expect(layout.fileAreaWidth == TerminalFileManagerLayout.minimumFilePaneWidth * 2 + 1)
        #expect(layout.folderWidth + layout.fileAreaWidth + layout.previewWidth + 2 == 823)
    }

    @Test
    func mainPaneLayoutClampsTransientPreviewBeforeShrinkingFolderTree() {
        let layout = PaneLayoutResolver.mainPanes(
            totalWidth: 823,
            dividerWidth: 1,
            isFolderVisible: true,
            isPreviewVisible: true,
            isSplitViewVisible: true,
            storedFolderWidth: 260,
            storedPreviewWidth: 360,
            displayedPreviewWidth: 100
        )

        #expect(layout.previewWidth == TerminalFileManagerLayout.minimumPreviewPaneWidth)
        #expect(layout.folderWidth == TerminalFileManagerLayout.minimumFolderTreeWidth)
        #expect(layout.fileAreaWidth == TerminalFileManagerLayout.minimumFilePaneWidth * 2 + 1)
        #expect(layout.folderWidth + layout.fileAreaWidth + layout.previewWidth + 2 == 823)
    }

    @Test
    func fileSplitStartsAtEqualWidths() {
        let split = PaneLayoutResolver.fileSplit(
            totalWidth: 801,
            dividerWidth: 1,
            ratio: 0.5
        )

        #expect(split.leftWidth == 400)
        #expect(split.rightWidth == 400)
        #expect(split.effectiveRatio == 0.5)
        #expect(split.canResize)
    }

    @Test
    func columnWidthsUseLegacyNameWidthFallback() {
        let widths = FileListColumnWidths(rawValue: "", fallbackNameWidth: 480)

        #expect(widths.width(for: .name) == 480)
        #expect(widths.width(for: .size) == Double(FileListColumn.size.defaultWidth))
    }

    @Test
    func columnWidthsClampAndSerializeAllColumns() {
        var widths = FileListColumnWidths(rawValue: "name:40,size:999", fallbackNameWidth: 320)

        #expect(widths.width(for: .name) == Double(FileListColumn.name.minimumWidth))
        #expect(widths.width(for: .size) == Double(FileListColumn.size.maximumWidth))

        widths.setWidth(72, for: .kind)
        let restored = FileListColumnWidths(rawValue: widths.rawValue, fallbackNameWidth: 320)

        #expect(restored.width(for: .kind) == 72)
        #expect(restored.width(for: .name) == Double(FileListColumn.name.minimumWidth))
        #expect(restored.width(for: .size) == Double(FileListColumn.size.maximumWidth))
    }

    @Test
    func fileSplitAppliesCustomRatio() {
        let split = PaneLayoutResolver.fileSplit(
            totalWidth: 1_001,
            dividerWidth: 1,
            ratio: 2.0 / 3.0
        )

        #expect(split.leftWidth == 667)
        #expect(split.rightWidth == 333)
        #expect(abs(split.effectiveRatio - 0.667) < 0.001)
    }

    @Test
    func fileSplitClampsAtRightMinimum() {
        let split = PaneLayoutResolver.fileSplit(
            totalWidth: 601,
            dividerWidth: 1,
            ratio: 0.8
        )

        #expect(split.leftWidth == 400)
        #expect(split.rightWidth == 200)
        #expect(abs(split.effectiveRatio - (2.0 / 3.0)) < 0.001)
    }

    @Test
    func fileSplitClampsAtLeftMinimum() {
        let split = PaneLayoutResolver.fileSplit(
            totalWidth: 601,
            dividerWidth: 1,
            ratio: 0.2
        )

        #expect(split.leftWidth == 200)
        #expect(split.rightWidth == 400)
        #expect(abs(split.effectiveRatio - (1.0 / 3.0)) < 0.001)
    }

    @Test
    func fileSplitUsesClampedVisibleRatioForNextWidthChange() {
        let wide = PaneLayoutResolver.fileSplit(
            totalWidth: 1_001,
            dividerWidth: 1,
            ratio: 0.8
        )
        let narrow = PaneLayoutResolver.fileSplit(
            totalWidth: 601,
            dividerWidth: 1,
            ratio: wide.effectiveRatio
        )
        let widenedAgain = PaneLayoutResolver.fileSplit(
            totalWidth: 1_001,
            dividerWidth: 1,
            ratio: narrow.effectiveRatio
        )

        #expect(wide.leftWidth == 800)
        #expect(wide.rightWidth == 200)
        #expect(narrow.leftWidth == 400)
        #expect(narrow.rightWidth == 200)
        #expect(widenedAgain.leftWidth == 667)
        #expect(widenedAgain.rightWidth == 333)
    }

    @Test
    func windowMinimumHeightIncludesTerminalWhenVisible() {
        #expect(
            TerminalFileManagerLayout.minimumWindowHeight(isTerminalPaneVisible: false)
                == TerminalFileManagerLayout.minimumWindowHeight
        )
        #expect(
            TerminalFileManagerLayout.minimumWindowHeight(isTerminalPaneVisible: true)
                == TerminalFileManagerLayout.minimumWindowHeight
                    + TerminalFileManagerLayout.minimumTerminalPaneHeight
                    + TerminalFileManagerLayout.dividerWidth
        )
    }

    @Test
    func verticalPaneLayoutUsesDisplayedTerminalHeight() {
        let layout = PaneLayoutResolver.verticalPanes(
            totalHeight: 700,
            dividerHeight: 1,
            isTerminalVisible: true,
            displayedTerminalHeight: 320
        )

        #expect(layout.terminalHeight == 320)
        #expect(layout.mainHeight == 379)
        #expect(layout.mainHeight + layout.terminalHeight + 1 == 700)
    }

    @Test
    func verticalPaneLayoutClampsTerminalAtMinimumBeforeMainShrinks() {
        let layout = PaneLayoutResolver.verticalPanes(
            totalHeight: 321,
            dividerHeight: 1,
            isTerminalVisible: true,
            displayedTerminalHeight: 20
        )

        #expect(layout.terminalHeight == TerminalFileManagerLayout.minimumTerminalPaneHeight)
        #expect(layout.mainHeight == TerminalFileManagerLayout.minimumMainAreaHeight)
        #expect(layout.mainHeight + layout.terminalHeight + 1 == 321)
    }

    @Test
    func verticalPaneLayoutGivesAllHeightToMainWhenTerminalHidden() {
        let layout = PaneLayoutResolver.verticalPanes(
            totalHeight: 700,
            dividerHeight: 0,
            isTerminalVisible: false,
            displayedTerminalHeight: 320
        )

        #expect(layout.terminalHeight == 0)
        #expect(layout.mainHeight == 700)
    }
}
#endif
