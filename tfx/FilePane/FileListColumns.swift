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
}

#endif
