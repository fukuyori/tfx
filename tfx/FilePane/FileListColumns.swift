#if os(macOS)
import SwiftUI

enum FileListColumn: String, CaseIterable, Identifiable {
    case icon
    case mode
    case name
    case size
    case kind
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
            return "ICO"
        case .mode:
            return "MODE"
        case .name:
            return "NAME"
        case .size:
            return "SIZE"
        case .kind:
            return "KIND"
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
