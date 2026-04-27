#if os(macOS)
import Foundation

enum MarkdownHTMLRenderer {
    static func htmlDocument(for markdown: String, cancellation: PreviewLoadCancellation) -> String? {
        guard !cancellation.isCancelled else { return nil }
        guard let body = markdownToHTML(markdown, cancellation: cancellation) else { return nil }
        guard !cancellation.isCancelled else { return nil }

        return MarkdownHTMLDocument.document(body: body)
    }

    private static func markdownToHTML(_ markdown: String, cancellation: PreviewLoadCancellation) -> String? {
        var html: [String] = []
        var paragraph: [String] = []
        var listItems: [String] = []
        var codeBlock: [String] = []
        var isInCodeBlock = false

        func flushParagraph() {
            guard !cancellation.isCancelled else { return }
            guard !paragraph.isEmpty else { return }
            html.append("<p>\(MarkdownInlineHTML.inlineHTML(paragraph.joined(separator: " ")))</p>")
            paragraph.removeAll()
        }

        func flushList() {
            guard !cancellation.isCancelled else { return }
            guard !listItems.isEmpty else { return }
            html.append("<ul>\(listItems.joined())</ul>")
            listItems.removeAll()
        }

        func flushCodeBlock() {
            guard !cancellation.isCancelled else { return }
            guard !codeBlock.isEmpty else { return }
            html.append("<pre><code>\(MarkdownInlineHTML.escapeHTML(codeBlock.joined(separator: "\n")))</code></pre>")
            codeBlock.removeAll()
        }

        for (index, rawLine) in markdown.components(separatedBy: .newlines).enumerated() {
            if index.isMultiple(of: 50), cancellation.isCancelled {
                return nil
            }

            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if isInCodeBlock {
                    flushCodeBlock()
                    isInCodeBlock = false
                } else {
                    flushParagraph()
                    flushList()
                    isInCodeBlock = true
                }
                continue
            }

            if isInCodeBlock {
                codeBlock.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushParagraph()
                flushList()
            } else if let heading = headingHTML(for: line) {
                flushParagraph()
                flushList()
                html.append(heading)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                listItems.append("<li>\(MarkdownInlineHTML.inlineHTML(String(line.dropFirst(2))))</li>")
            } else if line.hasPrefix("> ") {
                flushParagraph()
                flushList()
                html.append("<blockquote>\(MarkdownInlineHTML.inlineHTML(String(line.dropFirst(2))))</blockquote>")
            } else {
                flushList()
                paragraph.append(line)
            }
        }

        if isInCodeBlock {
            flushCodeBlock()
        }
        flushParagraph()
        flushList()

        guard !cancellation.isCancelled else { return nil }
        return html.joined(separator: "\n")
    }

    private static func headingHTML(for line: String) -> String? {
        let markerCount = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(markerCount), line.dropFirst(markerCount).hasPrefix(" ") else {
            return nil
        }

        let level = markerCount
        let text = line.dropFirst(markerCount + 1)
        return "<h\(level)>\(MarkdownInlineHTML.inlineHTML(String(text)))</h\(level)>"
    }
}
#endif
