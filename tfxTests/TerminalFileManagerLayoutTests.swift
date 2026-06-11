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
}
#endif
