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
    func rendersCompactTableDelimiters() {
        let markdown = """
        Name | Value
        - | -
        Alpha | 1
        Beta | 2
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
    func rendersCompactRightAlignedDelimiter() {
        let markdown = """
        | 回 | 章タイトル | 主題 | 成果物 |
        |-:|------|------|------|
        | 1 | 導入 | 概要 | メモ |
        """

        let html = MarkdownHTMLRenderer.htmlDocument(
            for: markdown,
            cancellation: PreviewLoadCancellation()
        )

        #expect(html?.contains("<table>") == true)
        #expect(html?.contains(#"<th style="text-align: right">回</th>"#) == true)
        #expect(html?.contains("<th>章タイトル</th><th>主題</th><th>成果物</th>") == true)
        #expect(html?.contains(#"<td style="text-align: right">1</td>"#) == true)
    }

    @Test
    func rendersCompactLeftAndCenterAlignedDelimiters() {
        let markdown = """
        | Left | Center |
        | :- | :-: |
        | a | b |
        """

        let html = MarkdownHTMLRenderer.htmlDocument(
            for: markdown,
            cancellation: PreviewLoadCancellation()
        )

        #expect(html?.contains("<table>") == true)
        #expect(html?.contains(#"<th style="text-align: left">Left</th>"#) == true)
        #expect(html?.contains(#"<th style="text-align: center">Center</th>"#) == true)
        #expect(html?.contains(#"<td style="text-align: left">a</td>"#) == true)
        #expect(html?.contains(#"<td style="text-align: center">b</td>"#) == true)
    }

    @Test
    func rendersOrderedListsAndInlineFormatting() {
        let markdown = """
        9. 次章への準備

        **必ず手を動かしながら読んでください。**

        ## 表記のルール
        """

        let html = MarkdownHTMLRenderer.htmlDocument(
            for: markdown,
            cancellation: PreviewLoadCancellation()
        )

        #expect(html?.contains("<ol><li>次章への準備</li></ol>") == true)
        #expect(html?.contains("<p><strong>必ず手を動かしながら読んでください。</strong></p>") == true)
        #expect(html?.contains("<h2>表記のルール</h2>") == true)
    }

    @Test
    func rendersHorizontalRule() {
        let markdown = """
        Before

        ---

        After
        """

        let html = MarkdownHTMLRenderer.htmlDocument(
            for: markdown,
            cancellation: PreviewLoadCancellation()
        )

        #expect(html?.contains("<p>Before</p>\n<hr>\n<p>After</p>") == true)
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

    @Test
    func rendersLinkedExternalImageAsImage() {
        let markdown = """
        [![Rust](https://img.shields.io/badge/rust-1.70%2B-orange.svg)](https://www.rust-lang.org/)
        """

        let html = MarkdownHTMLRenderer.htmlDocument(
            for: markdown,
            cancellation: PreviewLoadCancellation()
        )

        #expect(html?.contains(#"<a href="https://www.rust-lang.org/"><img alt="Rust" src="https://img.shields.io/badge/rust-1.70%2B-orange.svg"></a>"#) == true)
        #expect(html?.contains("img-src data:;") == true)
    }

    @Test
    func allowsExternalImagesWhenRequested() {
        let markdown = """
        ![Version](https://img.shields.io/badge/version-0.4.2-green.svg)
        """

        let html = MarkdownHTMLRenderer.htmlDocument(
            for: markdown,
            allowsExternalImages: true,
            cancellation: PreviewLoadCancellation()
        )

        #expect(html?.contains(#"<img alt="Version" src="https://img.shields.io/badge/version-0.4.2-green.svg">"#) == true)
        #expect(html?.contains("img-src data: https:;") == true)
    }
}
#endif
