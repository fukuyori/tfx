#if os(macOS)
import SwiftUI

enum FileListColumn: String, CaseIterable, Identifiable {
    case icon
    case mode
    case name
    case size
    case kind
    case tags
    case gitStatus
    case modified
    case created
    case permissions

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .icon:
            return "Icon"
        case .mode:
            return "Mode"
        case .name:
            return "Name"
        case .size:
            return "Size"
        case .kind:
            return "Kind"
        case .tags:
            return "Tags"
        case .gitStatus:
            return "Git"
        case .modified:
            return "Modified"
        case .created:
            return "Created"
        case .permissions:
            return "Permissions"
        }
    }

    var headerTitle: LocalizedStringResource {
        switch self {
        case .icon:
            return ""
        case .mode:
            return "MODE"
        case .name:
            return "NAME"
        case .size:
            return "SIZE"
        case .kind:
            return "KIND"
        case .tags:
            // The tag column shows colored dots, not text — keep the
            // header empty so the cell does not need to be wide enough
            // to accommodate a label.
            return ""
        case .gitStatus:
            // Single-character badge column; the header is empty so the
            // column width can stay tight against the badge itself.
            return ""
        case .modified:
            return "MODIFIED"
        case .created:
            return "CREATED"
        case .permissions:
            return "PERM"
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .icon:
            return 28
        case .mode:
            return 54
        case .name:
            return 320
        case .size:
            return 96
        case .kind:
            return 120
        case .tags:
            // 9pt dot + ~3pt breathing room on each side. Tagged files
            // with multiple tags truncate after the first — most files
            // carry zero or one tag so this keeps the file row dense.
            return 16
        case .gitStatus:
            // One-character badge ("M", "A", "?", …). 13pt monospaced
            // glyphs are ~8pt wide; 10pt is the tightest width that
            // still renders the full character without clipping.
            return 10
        case .modified, .created:
            return 160
        case .permissions:
            return 64
        }
    }

    var minimumWidth: CGFloat {
        switch self {
        case .icon:
            return 24
        case .mode:
            return 44
        case .name:
            return 160
        case .size:
            return 64
        case .kind:
            return 64
        case .tags:
            return 16
        case .gitStatus:
            return 10
        case .modified, .created:
            return 120
        case .permissions:
            return 48
        }
    }

    var maximumWidth: CGFloat {
        switch self {
        case .icon:
            return 48
        case .mode:
            return 100
        case .name:
            return 720
        case .size:
            return 180
        case .kind:
            return 280
        case .tags:
            return 96
        case .gitStatus:
            return 64
        case .modified, .created:
            return 280
        case .permissions:
            return 140
        }
    }

    var alignment: Alignment {
        switch self {
        case .size:
            return .trailing
        default:
            return .leading
        }
    }

    var canHide: Bool {
        self != .name
    }

    /// Which `FileSortKey` this column drives when its header is
    /// clicked. Returns `nil` for columns that don't map to a
    /// sortable file attribute (icon, tags, git status, mode,
    /// permissions) — their headers stay non-interactive.
    var sortKey: FileSortKey? {
        switch self {
        case .name: return .fastName
        case .size: return .size
        case .kind: return .kind
        case .modified: return .modified
        case .created: return .created
        case .icon, .mode, .tags, .gitStatus, .permissions:
            return nil
        }
    }
}

struct FileListColumnWidths: Equatable {
    private var widths: [FileListColumn: Double]

    init(rawValue: String = "", fallbackNameWidth: Double = TerminalFileManagerLayout.defaultFileNameColumnWidth) {
        var parsed: [FileListColumn: Double] = [.name: fallbackNameWidth]

        for component in rawValue.split(separator: ",") {
            let parts = component.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let column = FileListColumn(rawValue: parts[0]),
                  let width = Double(parts[1]) else {
                continue
            }
            parsed[column] = width
        }

        widths = parsed
        for column in FileListColumn.allCases {
            widths[column] = Self.clamped(widths[column] ?? Double(column.defaultWidth), for: column)
        }
    }

    var rawValue: String {
        FileListColumn.allCases
            .map { column in
                "\(column.rawValue):\(Int(width(for: column).rounded()))"
            }
            .joined(separator: ",")
    }

    func width(for column: FileListColumn) -> Double {
        widths[column] ?? Double(column.defaultWidth)
    }

    mutating func setWidth(_ width: Double, for column: FileListColumn) {
        widths[column] = Self.clamped(width, for: column)
    }

    static func clamped(_ width: Double, for column: FileListColumn) -> Double {
        min(max(width, Double(column.minimumWidth)), Double(column.maximumWidth))
    }
}

#endif
