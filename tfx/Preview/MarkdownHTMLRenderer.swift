#if os(macOS)
import Foundation

enum MarkdownHTMLRenderer {
    private enum TableAlignment {
        case leading
        case center
        case trailing
    }

    static func htmlDocument(
        for markdown: String,
        allowsExternalImages: Bool = false,
        cancellation: PreviewLoadCancellation
    ) -> String? {
        guard !cancellation.isCancelled else { return nil }
        guard let body = markdownToHTML(markdown, cancellation: cancellation) else { return nil }
        guard !cancellation.isCancelled else { return nil }

        return MarkdownHTMLDocument.document(body: body, allowsExternalImages: allowsExternalImages)
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

        let lines = markdown.components(separatedBy: .newlines)
        var index = 0

        while index < lines.count {
            if index.isMultiple(of: 50), cancellation.isCancelled {
                return nil
            }

            let rawLine = lines[index]
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
                index += 1
                continue
            }

            if isInCodeBlock {
                codeBlock.append(rawLine)
                index += 1
                continue
            }

            if line.isEmpty {
                flushParagraph()
                flushList()
            } else if let table = tableHTML(startingAt: index, in: lines) {
                flushParagraph()
                flushList()
                html.append(table.html)
                index = table.nextIndex
                continue
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

            index += 1
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

    private static func tableHTML(startingAt index: Int, in lines: [String]) -> (html: String, nextIndex: Int)? {
        guard index + 1 < lines.count else { return nil }

        let headerLine = lines[index].trimmingCharacters(in: .whitespaces)
        let delimiterLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
        guard headerLine.contains("|"), delimiterLine.contains("|") else { return nil }

        let headers = tableCells(in: headerLine)
        guard !headers.isEmpty else { return nil }
        guard let alignments = tableDelimiterAlignments(for: tableCells(in: delimiterLine)),
              alignments.count == headers.count else {
            return nil
        }

        var rows: [[String]] = []
        var nextIndex = index + 2
        while nextIndex < lines.count {
            let line = lines[nextIndex].trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, line.contains("|") else { break }
            rows.append(normalizedTableCells(tableCells(in: line), count: headers.count))
            nextIndex += 1
        }

        let headerHTML = zip(headers, alignments)
            .map { header, alignment in
                "<th\(tableStyleAttribute(for: alignment))>\(MarkdownInlineHTML.inlineHTML(header))</th>"
            }
            .joined()
        let bodyHTML = rows
            .map { row in
                let cells = zip(row, alignments)
                    .map { cell, alignment in
                        "<td\(tableStyleAttribute(for: alignment))>\(MarkdownInlineHTML.inlineHTML(cell))</td>"
                    }
                    .joined()
                return "<tr>\(cells)</tr>"
            }
            .joined()

        return (
            """
            <table>
            <thead><tr>\(headerHTML)</tr></thead>
            <tbody>\(bodyHTML)</tbody>
            </table>
            """,
            nextIndex
        )
    }

    private static func tableCells(in line: String) -> [String] {
        var characters = Array(line.trimmingCharacters(in: .whitespaces))
        if characters.first == "|" {
            characters.removeFirst()
        }
        if characters.last == "|" {
            characters.removeLast()
        }

        var cells: [String] = []
        var current = ""
        var isEscaped = false

        for character in characters {
            if isEscaped {
                if character != "|" {
                    current.append("\\")
                }
                current.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }

        if isEscaped {
            current.append("\\")
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    private static func tableDelimiterAlignments(for cells: [String]) -> [TableAlignment?]? {
        guard !cells.isEmpty else { return nil }

        var alignments: [TableAlignment?] = []
        for cell in cells {
            var marker = cell.trimmingCharacters(in: .whitespaces)
            let alignsLeft = marker.hasPrefix(":")
            let alignsRight = marker.hasSuffix(":")

            if alignsLeft {
                marker.removeFirst()
            }
            if alignsRight {
                marker.removeLast()
            }

            guard marker.count >= 3, marker.allSatisfy({ $0 == "-" }) else {
                return nil
            }

            if alignsLeft && alignsRight {
                alignments.append(.center)
            } else if alignsLeft {
                alignments.append(.leading)
            } else if alignsRight {
                alignments.append(.trailing)
            } else {
                alignments.append(nil)
            }
        }

        return alignments
    }

    private static func normalizedTableCells(_ cells: [String], count: Int) -> [String] {
        if cells.count == count {
            return cells
        }
        if cells.count > count {
            return Array(cells.prefix(count))
        }
        return cells + Array(repeating: "", count: count - cells.count)
    }

    private static func tableStyleAttribute(for alignment: TableAlignment?) -> String {
        switch alignment {
        case .leading:
            return #" style="text-align: left""#
        case .center:
            return #" style="text-align: center""#
        case .trailing:
            return #" style="text-align: right""#
        case nil:
            return ""
        }
    }
}
#endif
