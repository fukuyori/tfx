#if os(macOS)
import SwiftUI

/// Base color tokens for tfx.
///
/// tfx now ships one canonical visual design: a black terminal surface with
/// green phosphor-style accents. User configuration will customize these
/// tokens directly instead of switching among multiple bundled themes.
struct Theme: Equatable {
    // MARK: - File pane / list rows

    let fileListBackground: Color
    let fileListRowSelected: Color
    let fileListRowDropTarget: Color
    let directoryForeground: Color
    let fileForeground: Color
    let secondaryForeground: Color

    // MARK: - File pane chrome

    let headerForeground: Color
    let headerBackground: Color
    let titleBarBackgroundActive: Color
    let titleBarBackgroundInactive: Color
    let statusLineForegroundActive: Color
    let statusLineForegroundInactive: Color
    let statusLineBackground: Color

    // MARK: - Pane borders

    let paneBorderKeyboardTarget: Color
    let paneBorderActive: Color
    let paneBorderInactive: Color

    // MARK: - Folder tree

    let folderTreeBackground: Color
    let folderTreeForeground: Color
    let folderTreeSelectedForeground: Color
    let folderTreeFolderIcon: Color
    let folderTreeSelectedActive: Color
    let folderTreeSelectedInactive: Color
    let folderTreeSectionHeader: Color

    // MARK: - Misc surfaces

    let splitHandleIdle: Color
    let splitHandleActive: Color

    // MARK: - Git status badge colors

    let gitModified: Color
    let gitAdded: Color
    let gitDeleted: Color
    let gitRenamed: Color
    let gitUntracked: Color
    let gitIgnored: Color
    let gitConflicted: Color

    static let `default`: Theme = .tfxGreen
}

extension Theme {
    /// Map a Git status to the active design's color for that status.
    func color(for status: GitFileStatus) -> Color {
        switch status {
        case .modified:   return gitModified
        case .added:      return gitAdded
        case .deleted:    return gitDeleted
        case .renamed:    return gitRenamed
        case .untracked:  return gitUntracked
        case .ignored:    return gitIgnored
        case .conflicted: return gitConflicted
        }
    }

    func applying(_ overrides: ThemeColorOverrides) -> Theme {
        Theme(
            fileListBackground: overrides.fileListBackground ?? fileListBackground,
            fileListRowSelected: overrides.fileListRowSelected ?? fileListRowSelected,
            fileListRowDropTarget: overrides.fileListRowDropTarget ?? fileListRowDropTarget,
            directoryForeground: overrides.directoryForeground ?? directoryForeground,
            fileForeground: overrides.fileForeground ?? fileForeground,
            secondaryForeground: overrides.secondaryForeground ?? secondaryForeground,
            headerForeground: overrides.headerForeground ?? headerForeground,
            headerBackground: overrides.headerBackground ?? headerBackground,
            titleBarBackgroundActive: overrides.titleBarBackgroundActive ?? titleBarBackgroundActive,
            titleBarBackgroundInactive: overrides.titleBarBackgroundInactive ?? titleBarBackgroundInactive,
            statusLineForegroundActive: overrides.statusLineForegroundActive ?? statusLineForegroundActive,
            statusLineForegroundInactive: overrides.statusLineForegroundInactive ?? statusLineForegroundInactive,
            statusLineBackground: overrides.statusLineBackground ?? statusLineBackground,
            paneBorderKeyboardTarget: overrides.paneBorderKeyboardTarget ?? paneBorderKeyboardTarget,
            paneBorderActive: overrides.paneBorderActive ?? paneBorderActive,
            paneBorderInactive: overrides.paneBorderInactive ?? paneBorderInactive,
            folderTreeBackground: overrides.folderTreeBackground ?? folderTreeBackground,
            folderTreeForeground: overrides.folderTreeForeground ?? folderTreeForeground,
            folderTreeSelectedForeground: overrides.folderTreeSelectedForeground ?? folderTreeSelectedForeground,
            folderTreeFolderIcon: overrides.folderTreeFolderIcon ?? folderTreeFolderIcon,
            folderTreeSelectedActive: overrides.folderTreeSelectedActive ?? folderTreeSelectedActive,
            folderTreeSelectedInactive: overrides.folderTreeSelectedInactive ?? folderTreeSelectedInactive,
            folderTreeSectionHeader: overrides.folderTreeSectionHeader ?? folderTreeSectionHeader,
            splitHandleIdle: overrides.splitHandleIdle ?? splitHandleIdle,
            splitHandleActive: overrides.splitHandleActive ?? splitHandleActive,
            gitModified: overrides.gitModified ?? gitModified,
            gitAdded: overrides.gitAdded ?? gitAdded,
            gitDeleted: overrides.gitDeleted ?? gitDeleted,
            gitRenamed: overrides.gitRenamed ?? gitRenamed,
            gitUntracked: overrides.gitUntracked ?? gitUntracked,
            gitIgnored: overrides.gitIgnored ?? gitIgnored,
            gitConflicted: overrides.gitConflicted ?? gitConflicted
        )
    }
}

struct ThemeColorOverrides: Equatable {
    var fileListBackground: Color?
    var fileListRowSelected: Color?
    var fileListRowDropTarget: Color?
    var directoryForeground: Color?
    var fileForeground: Color?
    var secondaryForeground: Color?
    var headerForeground: Color?
    var headerBackground: Color?
    var titleBarBackgroundActive: Color?
    var titleBarBackgroundInactive: Color?
    var statusLineForegroundActive: Color?
    var statusLineForegroundInactive: Color?
    var statusLineBackground: Color?
    var paneBorderKeyboardTarget: Color?
    var paneBorderActive: Color?
    var paneBorderInactive: Color?
    var folderTreeBackground: Color?
    var folderTreeForeground: Color?
    var folderTreeSelectedForeground: Color?
    var folderTreeFolderIcon: Color?
    var folderTreeSelectedActive: Color?
    var folderTreeSelectedInactive: Color?
    var folderTreeSectionHeader: Color?
    var splitHandleIdle: Color?
    var splitHandleActive: Color?
    var gitModified: Color?
    var gitAdded: Color?
    var gitDeleted: Color?
    var gitRenamed: Color?
    var gitUntracked: Color?
    var gitIgnored: Color?
    var gitConflicted: Color?
}

private enum TFXGreenPalette {
    static let black0 = Color(red: 0.000, green: 0.012, blue: 0.004) // #000301
    static let black1 = Color(red: 0.012, green: 0.035, blue: 0.018) // #030905
    static let black2 = Color(red: 0.024, green: 0.067, blue: 0.035) // #061109
    static let black3 = Color(red: 0.043, green: 0.125, blue: 0.071) // #0B2012
    static let black4 = Color(red: 0.063, green: 0.180, blue: 0.102) // #102E1A

    static let green0 = Color(red: 0.812, green: 1.000, blue: 0.812) // #CFFFCF
    static let green1 = Color(red: 0.435, green: 1.000, blue: 0.502) // #6FFF80
    static let green2 = Color(red: 0.176, green: 0.851, blue: 0.337) // #2DD956
    static let green3 = Color(red: 0.102, green: 0.561, blue: 0.224) // #1A8F39
    static let green4 = Color(red: 0.071, green: 0.337, blue: 0.145) // #125625

    static let amber = Color(red: 0.965, green: 0.780, blue: 0.314) // #F6C750
    static let red = Color(red: 1.000, green: 0.286, blue: 0.286) // #FF4949
    static let cyan = Color(red: 0.369, green: 0.941, blue: 0.918) // #5EF0EA
    static let violet = Color(red: 0.710, green: 0.565, blue: 1.000) // #B590FF
}

extension Theme {
    static let tfxGreen = Theme(
        fileListBackground: TFXGreenPalette.black0,
        fileListRowSelected: TFXGreenPalette.black4,
        fileListRowDropTarget: TFXGreenPalette.green4,
        directoryForeground: TFXGreenPalette.green1,
        fileForeground: TFXGreenPalette.green0,
        secondaryForeground: TFXGreenPalette.green3,

        headerForeground: TFXGreenPalette.green1,
        headerBackground: TFXGreenPalette.black1,
        titleBarBackgroundActive: TFXGreenPalette.black4,
        titleBarBackgroundInactive: TFXGreenPalette.black1,
        statusLineForegroundActive: TFXGreenPalette.green1,
        statusLineForegroundInactive: TFXGreenPalette.green3,
        statusLineBackground: TFXGreenPalette.black1,

        paneBorderKeyboardTarget: TFXGreenPalette.green1,
        paneBorderActive: TFXGreenPalette.green3,
        paneBorderInactive: TFXGreenPalette.green4,

        folderTreeBackground: TFXGreenPalette.black0,
        folderTreeForeground: TFXGreenPalette.green0,
        folderTreeSelectedForeground: TFXGreenPalette.green1,
        folderTreeFolderIcon: TFXGreenPalette.green2,
        folderTreeSelectedActive: TFXGreenPalette.black4,
        folderTreeSelectedInactive: TFXGreenPalette.black3,
        folderTreeSectionHeader: TFXGreenPalette.green1,

        splitHandleIdle: TFXGreenPalette.green4,
        splitHandleActive: TFXGreenPalette.green1,

        gitModified: TFXGreenPalette.amber,
        gitAdded: TFXGreenPalette.green1,
        gitDeleted: TFXGreenPalette.red,
        gitRenamed: TFXGreenPalette.violet,
        gitUntracked: TFXGreenPalette.green3,
        gitIgnored: TFXGreenPalette.green4,
        gitConflicted: TFXGreenPalette.cyan
    )
}
#endif
