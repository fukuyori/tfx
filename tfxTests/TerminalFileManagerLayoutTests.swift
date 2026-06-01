#if os(macOS)
import CoreGraphics
import Testing
@testable import tfx

@Suite("TerminalFileManagerLayout")
struct TerminalFileManagerLayoutTests {
    @Test
    func splitPaneWidthsStayInsideAvailableFileArea() {
        let availableWidth = 218.0

        let leftWidth = TerminalFileManagerView.clampedLeftFileWidth(
            availableWidth: availableWidth,
            fileSplitRatio: 0.5
        )
        let rightWidth = max(0, availableWidth - leftWidth)

        #expect(leftWidth + rightWidth <= availableWidth)
        #expect(rightWidth >= 0)
    }

    @Test
    func previewWidthUsesCurrentWindowConstraints() {
        let totalWidth = 980.0
        let folderWidth = TerminalFileManagerView.clampedFolderWidth(
            totalWidth: totalWidth,
            storedFolderWidth: 486
        )

        let previewWidth = TerminalFileManagerView.clampedPreviewWidth(
            totalWidth: totalWidth,
            folderWidth: folderWidth,
            storedPreviewWidth: 320
        )

        #expect(previewWidth == 240)
    }
}
#endif
