#if os(macOS)
import SwiftUI

/// Rendered CSV / TSV preview.
///
/// Parses the file off the main thread with `CSVParser`, then renders the
/// rows as a horizontally and vertically scrollable monospaced table. The
/// first row is treated as a header and gets a contrasting background.
/// Falls back to a status message when the file cannot be read or has no
/// rows.
struct CSVPreview: View {
    let url: URL

    @State private var rows: [[String]] = []
    @State private var loadedURL: URL?
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var tooLargeMessage: String?
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if isLoading {
                statusView { ProgressView() }
            } else if let tooLargeMessage {
                statusView { Text(tooLargeMessage) }
            } else if loadFailed {
                statusView { Text("Unable to read file") }
            } else if rows.isEmpty {
                statusView { Text("Empty file") }
            } else {
                tableView
            }
        }
        .onAppear { loadIfNeeded(url) }
        .onChange(of: url) { _, newValue in loadIfNeeded(newValue) }
    }

    private func statusView<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(design.fonts.swiftUIFont(for: .previewCode))
            .foregroundStyle(theme.secondaryForeground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tableView: some View {
        let columnCount = rows.map(\.count).max() ?? 0
        return ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(0..<columnCount, id: \.self) { columnIndex in
                            let cell = columnIndex < row.count ? row[columnIndex] : ""
                            Text(cell)
                                .font(design.fonts.swiftUIFont(for: .previewCode))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(minWidth: 96, alignment: .leading)
                                .foregroundStyle(theme.fileForeground)
                                .background(rowIndex == 0
                                    ? theme.headerBackground.opacity(design.opacity.background)
                                    : Color.clear
                                )
                                .overlay(
                                    Rectangle()
                                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
        }
    }

    private func loadIfNeeded(_ newURL: URL) {
        guard loadedURL != newURL else { return }
        loadedURL = newURL
        isLoading = true
        loadFailed = false
        tooLargeMessage = nil
        rows = []

        let delimiter: Character = newURL.pathExtension.lowercased() == "tsv" ? "\t" : ","
        let target = newURL

        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = PreviewTextLoader.load(at: target)
            switch outcome {
            case let .tooLarge(actualBytes):
                let message = PreviewTextLoader.tooLargeMessage(actualBytes: actualBytes)
                DispatchQueue.main.async {
                    guard loadedURL == newURL else { return }
                    tooLargeMessage = message
                    isLoading = false
                }
                return
            case let .success(text):
                let parsed = CSVParser.parse(text, delimiter: delimiter)
                DispatchQueue.main.async {
                    guard loadedURL == newURL else { return }
                    rows = parsed
                    isLoading = false
                }
            }
        }
    }
}

/// Minimal CSV / TSV parser. Handles the RFC 4180 essentials:
/// - delimited fields
/// - quoted fields containing the delimiter, embedded newlines, or escaped
///   double quotes (`""`)
/// - both LF and CRLF row separators
///
/// Streaming and locale-specific delimiter detection are intentionally out of
/// scope for this preview. The whole file is loaded into memory first.
enum CSVParser {
    static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false

        let characters = Array(text)
        var i = 0
        while i < characters.count {
            let c = characters[i]

            if inQuotes {
                if c == "\"" {
                    if i + 1 < characters.count, characters[i + 1] == "\"" {
                        field.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                case delimiter:
                    current.append(field)
                    field = ""
                case "\n", "\r", "\r\n":
                    // Swift collapses `\r\n` into a single grapheme cluster
                    // when iterating Character-by-Character, so an explicit
                    // CRLF case is required in addition to the lone LF / CR
                    // cases above. No manual lookahead is needed.
                    current.append(field)
                    rows.append(current)
                    current = []
                    field = ""
                default:
                    field.append(c)
                }
            }
            i += 1
        }

        if !field.isEmpty || !current.isEmpty {
            current.append(field)
            rows.append(current)
        }
        return rows
    }
}

#endif
