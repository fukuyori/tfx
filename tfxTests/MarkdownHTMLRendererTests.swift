#if os(macOS)
import Testing
@testable import tfx

@Suite("MarkdownHTMLRenderer")
struct MarkdownHTMLRendererTests {
    @Test
    func rendersPipeTable() {
        let markdown = """
        | Name | Value |
        | --- | --- |
        | Alpha | 1 |
        | Beta | 2 |
        """

        let html = MarkdownHTMLRenderer.htmlDocument(
            for: markdown,
            cancellation: PreviewLoadCancellation()
        )

        #expect(html?.contains("<table>") == true)
        #expect(html?.contains("<thead><tr><th>Name</th><th>Value</th></tr></thead>") == true)
        #expect(html?.contains("<tbody><tr><td>Alpha</td><td>1</td></tr><tr><td>Beta</td><td>2</td></tr></tbody>") == true)
    }

    @Test
    func rendersAlignedTableCells() {
        let markdown = """
        | Left | Center | Right |
        | :--- | :---: | ---: |
        | a | b | c |
        """

        let html = MarkdownHTMLRenderer.htmlDocument(
            for: markdown,
            cancellation: PreviewLoadCancellation()
        )

        #expect(html?.contains(#"<th style="text-align: left">Left</th>"#) == true)
        #expect(html?.contains(#"<th style="text-align: center">Center</th>"#) == true)
        #expect(html?.contains(#"<th style="text-align: right">Right</th>"#) == true)
        #expect(html?.contains(#"<td style="text-align: center">b</td>"#) == true)
    }

    @Test
    func keepsTablesInsideCodeBlocksAsCode() {
        let markdown = """
        ```
        | Name | Value |
        | --- | --- |
        ```
        """

        let html = MarkdownHTMLRenderer.htmlDocument(
            for: markdown,
            cancellation: PreviewLoadCancellation()
        )

        #expect(html?.contains("<table>") == false)
        #expect(html?.contains("| Name | Value |") == true)
    }
}
#endif
