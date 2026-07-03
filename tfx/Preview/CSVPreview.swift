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
    @State private var isTruncated = false
    @State private var loadedURL: URL?
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var tooLargeMessage: String?
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    /// Rendering bounds for the preview table. A preview doesn't
    /// need every row of a huge dump, and each rendered cell is a
    /// bordered `Text` — without a cap a million-row CSV builds
    /// an unscrollable wall of views. Rows beyond the cap are
    /// reported via a footer instead.
    private static let maxPreviewRows = 1_000
    private static let maxPreviewColumns = 100

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
        let columnCount = min(rows.map(\.count).max() ?? 0, Self.maxPreviewColumns)
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
                if isTruncated {
                    Text("Preview limited to the first \(Self.maxPreviewRows) rows.")
                        .font(design.fonts.swiftUIFont(for: .previewCode))
                        .foregroundStyle(theme.secondaryForeground)
                        .padding(8)
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
        isTruncated = false

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
                // Parse one row past the render cap so a footer
                // can say the preview is truncated.
                var parsed = CSVParser.parse(text, delimiter: delimiter, maxRows: Self.maxPreviewRows + 1)
                let truncated = parsed.count > Self.maxPreviewRows
                if truncated {
                    parsed.removeLast(parsed.count - Self.maxPreviewRows)
                }
                DispatchQueue.main.async {
                    guard loadedURL == newURL else { return }
                    rows = parsed
                    isTruncated = truncated
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
    /// `maxRows` stops the parse once that many rows are
    /// complete — the preview renders a bounded table, so
    /// parsing every row of a 50 MB dump is wasted work.
    /// Pass nil for a full parse.
    static func parse(_ text: String, delimiter: Character, maxRows: Int? = nil) -> [[String]] {
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false

        // Iterate the string directly instead of materializing
        // `Array(text)` first: one Character costs 16 bytes, so
        // the array peaked at ~16× the file size (≈800 MB for a
        // 50 MB CSV) before parsing even began. `pending` holds
        // the single character of lookahead the `""` escape
        // needs.
        var iterator = text.makeIterator()
        var pending: Character?
        func nextCharacter() -> Character? {
            if let held = pending {
                pending = nil
                return held
            }
            return iterator.next()
        }

        while let c = nextCharacter() {
            if inQuotes {
                if c == "\"" {
                    let lookahead = nextCharacter()
                    if lookahead == "\"" {
                        field.append("\"")
                        continue
                    }
                    inQuotes = false
                    pending = lookahead
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
                    if let maxRows, rows.count >= maxRows {
                        return rows
                    }
                default:
                    field.append(c)
                }
            }
        }

        if !field.isEmpty || !current.isEmpty {
            current.append(field)
            rows.append(current)
        }
        return rows
    }
}

#endif
