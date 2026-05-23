#if os(macOS)
import SwiftUI

/// One named color theme. Tokens are semantic ("file list selected row")
/// rather than positional ("color of the highlighted background of the
/// third row of …"), so themes can be swapped without each view knowing
/// which theme is active.
///
/// Every built-in theme is designed around a small canonical palette
/// (typically 5–8 hand-picked colors). Token assignments layer that
/// palette intentionally:
///   - `*Background` tokens use the darkest 1–2 shades, so the file
///     pane reads as a flat-but-layered surface rather than pure black.
///   - Selection / drop-target tokens lift one shade above the
///     background using a desaturated palette accent, so highlights
///     feel native to the theme instead of borrowing the system
///     accent color.
///   - Headers, status line, and the active pane border share a single
///     "alert accent" color so the eye learns to recognize one theme
///     identity throughout the UI.
struct Theme: Identifiable, Equatable {
    let id: String
    let displayName: LocalizedStringResource

    // MARK: - File pane / list rows

    /// Solid background for file rows in the default (unselected, no
    /// drop target) state. Also used as the file pane's base background.
    let fileListBackground: Color
    /// Background applied when a row is part of the active multi-selection.
    let fileListRowSelected: Color
    /// Background applied when a row is the in-progress drop target.
    let fileListRowDropTarget: Color
    /// Foreground for directory names and the directory mode glyph.
    let directoryForeground: Color
    /// Foreground for regular file names.
    let fileForeground: Color
    /// Foreground for size / kind / date / permission columns.
    let secondaryForeground: Color

    // MARK: - File pane chrome

    /// File-pane column header text.
    let headerForeground: Color
    /// File-pane column header background — usually matches the list
    /// background so the header reads as part of the list.
    let headerBackground: Color
    /// Title bar background when the pane is the keyboard target.
    let titleBarBackgroundActive: Color
    /// Title bar background otherwise.
    let titleBarBackgroundInactive: Color
    /// Status line text when the pane is the keyboard target.
    let statusLineForegroundActive: Color
    /// Status line text otherwise.
    let statusLineForegroundInactive: Color
    /// Status line background.
    let statusLineBackground: Color

    // MARK: - Pane borders

    /// Border around the file pane / folder tree pane when it is the
    /// keyboard target (thick, vivid).
    let paneBorderKeyboardTarget: Color
    /// Border around an active pane that is not the current keyboard target.
    let paneBorderActive: Color
    /// Border around an inactive pane.
    let paneBorderInactive: Color

    // MARK: - Folder tree

    /// Folder-tree row background.
    let folderTreeBackground: Color
    /// Folder-tree row foreground for non-selected rows.
    let folderTreeForeground: Color
    /// Folder-tree row foreground for the active selection row.
    let folderTreeSelectedForeground: Color
    /// Folder icon tint.
    let folderTreeFolderIcon: Color
    /// Background for the selected folder-tree row when the tree is the
    /// keyboard target.
    let folderTreeSelectedActive: Color
    /// Background for the selected folder-tree row when the tree is not
    /// the keyboard target.
    let folderTreeSelectedInactive: Color
    /// Section header foreground (e.g. "TREE", "PINNED").
    let folderTreeSectionHeader: Color

    // MARK: - Misc surfaces

    /// Drag handle between split panes when idle.
    let splitHandleIdle: Color
    /// Drag handle between split panes during an active drag.
    let splitHandleActive: Color

    // MARK: - Git status badge colors

    let gitModified: Color
    let gitAdded: Color
    let gitDeleted: Color
    let gitRenamed: Color
    let gitUntracked: Color
    let gitIgnored: Color
    let gitConflicted: Color

    static func == (lhs: Theme, rhs: Theme) -> Bool {
        lhs.id == rhs.id
    }
}

extension Theme {
    /// Map a Git status to the active theme's color for that status.
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

    /// All built-in themes, in the order they appear in the View menu.
    static let allThemes: [Theme] = [
        .terminalClassic,
        .solarizedDark,
        .monokai,
        .dracula,
    ]

    static let `default`: Theme = .terminalClassic

    static func theme(forID id: String) -> Theme {
        allThemes.first(where: { $0.id == id }) ?? .default
    }
}

// MARK: - Terminal Classic (phosphor green CRT)
//
// Palette inspired by amber/green CRT terminals: a near-black ground
// with a faint green undertone, a layered mid-shade for chrome, and a
// single vivid phosphor green that runs through every active state
// (keyboard target, header, status line). Directories use a cooler
// green-cyan so they read as "interactive" against the warmer foreground.

extension Theme {
    private enum ClassicPalette {
        // Base (background) ladder — three close-together near-blacks
        // with a green tint so layered surfaces still feel related.
        static let base0   = Color(red: 0.027, green: 0.039, blue: 0.027) // #070A07 — darkest
        static let base1   = Color(red: 0.043, green: 0.063, blue: 0.043) // #0B100B — chrome
        static let base2   = Color(red: 0.067, green: 0.094, blue: 0.067) // #111811 — selection lift
        static let base3   = Color(red: 0.110, green: 0.149, blue: 0.110) // #1C261C — strong lift

        // Foreground ladder — desaturated phosphor greens.
        static let text    = Color(red: 0.776, green: 0.910, blue: 0.776) // #C6E8C6
        static let muted   = Color(red: 0.420, green: 0.533, blue: 0.439) // #6B8870
        static let dim     = Color(red: 0.243, green: 0.318, blue: 0.255) // #3E5141

        // Accents
        static let phosphor   = Color(red: 0.290, green: 0.867, blue: 0.486) // #4ADD7C — keyboard / headers
        static let phosphorDim = Color(red: 0.165, green: 0.502, blue: 0.282) // #2A8048 — active (non-KB)
        static let directory  = Color(red: 0.373, green: 0.702, blue: 0.478) // #5FB37A — folders
        static let amber      = Color(red: 0.847, green: 0.722, blue: 0.361) // #D8B85C — git modified
        static let signalRed  = Color(red: 0.910, green: 0.361, blue: 0.361) // #E85C5C — git deleted
        static let signalCyan = Color(red: 0.361, green: 0.784, blue: 0.847) // #5CC8D8 — git renamed
        static let signalOrange = Color(red: 1.0, green: 0.478, blue: 0.361) // #FF7A5C — conflict
    }

    static let terminalClassic = Theme(
        id: "terminal-classic",
        displayName: "Terminal Classic",
        // File pane
        fileListBackground: ClassicPalette.base0,
        fileListRowSelected: ClassicPalette.base3,
        fileListRowDropTarget: ClassicPalette.phosphorDim,
        directoryForeground: ClassicPalette.directory,
        fileForeground: ClassicPalette.text,
        secondaryForeground: ClassicPalette.muted,
        // Chrome
        headerForeground: ClassicPalette.phosphor,
        headerBackground: ClassicPalette.base1,
        titleBarBackgroundActive: ClassicPalette.base3,
        titleBarBackgroundInactive: ClassicPalette.base1,
        statusLineForegroundActive: ClassicPalette.phosphor,
        statusLineForegroundInactive: ClassicPalette.muted,
        statusLineBackground: ClassicPalette.base1,
        // Borders
        paneBorderKeyboardTarget: ClassicPalette.phosphor,
        paneBorderActive: ClassicPalette.phosphorDim,
        paneBorderInactive: ClassicPalette.dim,
        // Folder tree
        folderTreeBackground: ClassicPalette.base0,
        folderTreeForeground: ClassicPalette.text,
        folderTreeSelectedForeground: ClassicPalette.phosphor,
        folderTreeFolderIcon: ClassicPalette.directory,
        folderTreeSelectedActive: ClassicPalette.base3,
        folderTreeSelectedInactive: ClassicPalette.base2,
        folderTreeSectionHeader: ClassicPalette.phosphorDim,
        // Misc
        splitHandleIdle: ClassicPalette.dim,
        splitHandleActive: ClassicPalette.phosphor,
        // Git — palette accents only, all sit on the dark base
        gitModified: ClassicPalette.amber,
        gitAdded: ClassicPalette.phosphor,
        gitDeleted: ClassicPalette.signalRed,
        gitRenamed: ClassicPalette.signalCyan,
        gitUntracked: ClassicPalette.muted,
        gitIgnored: ClassicPalette.dim,
        gitConflicted: ClassicPalette.signalOrange
    )
}

// MARK: - Solarized Dark (Ethan Schoonover)
//
// Strict canonical palette from solarized.com. Backgrounds layer
// base03 → base02; foregrounds layer base01 → base0 → base1. Yellow
// is the single hue used for "alert" state (header, status line,
// keyboard target border, active selection). Blue is used for
// "navigational" elements (directories, folder icons). No off-palette
// colors anywhere.

extension Theme {
    private enum SolarizedPalette {
        static let base03  = Color(red: 0.0,   green: 0.169, blue: 0.212) // #002B36 — bg
        static let base02  = Color(red: 0.027, green: 0.212, blue: 0.259) // #073642 — lift
        static let base01  = Color(red: 0.345, green: 0.431, blue: 0.459) // #586E75 — muted fg
        static let base00  = Color(red: 0.396, green: 0.482, blue: 0.514) // #657B83 — secondary
        static let base0   = Color(red: 0.514, green: 0.580, blue: 0.588) // #839496 — fg
        static let base1   = Color(red: 0.576, green: 0.631, blue: 0.631) // #93A1A1 — emphasized fg
        static let yellow  = Color(red: 0.710, green: 0.537, blue: 0.0)   // #B58900
        static let orange  = Color(red: 0.796, green: 0.294, blue: 0.086) // #CB4B16
        static let red     = Color(red: 0.863, green: 0.196, blue: 0.184) // #DC322F
        static let magenta = Color(red: 0.827, green: 0.212, blue: 0.510) // #D33682
        static let blue    = Color(red: 0.149, green: 0.545, blue: 0.824) // #268BD2
        static let cyan    = Color(red: 0.165, green: 0.631, blue: 0.596) // #2AA198
        static let green   = Color(red: 0.522, green: 0.600, blue: 0.0)   // #859900
    }

    private enum SolarizedExtras {
        // True-Solarized only ships base03 / base02 for the dark side.
        // We add one deeper shade so the file list reads as the lowest
        // layer and chrome (header / status line / selection) lifts to
        // base03/base02 above it. The hue stays on the canonical
        // teal-leaning axis — this is "Solarized base03 with the lights
        // turned further down" rather than a black background.
        static let baseAbyss = Color(red: 0.0,   green: 0.094, blue: 0.122) // #001820
        // base2 / base3 belong to the light palette but are canonical
        // Solarized colors. We use them as the "near-white" foreground
        // for the dark theme so monospaced text on the deep background
        // gets full readability without leaving the palette.
        static let base2 = Color(red: 0.933, green: 0.910, blue: 0.835) // #EEE8D5
        static let base3 = Color(red: 0.992, green: 0.965, blue: 0.890) // #FDF6E3
        // A slightly brighter blue keeps directory rows distinct against
        // the deeper background without resorting to off-palette hues.
        static let blueBright = Color(red: 0.290, green: 0.671, blue: 0.953) // #4AABF3
    }

    static let solarizedDark = Theme(
        id: "solarized-dark",
        displayName: "Solarized Dark",
        // File pane — base ladder is abyss → base03 → base02
        fileListBackground: SolarizedExtras.baseAbyss,
        fileListRowSelected: SolarizedPalette.base02,
        fileListRowDropTarget: SolarizedPalette.yellow.opacity(0.45),
        directoryForeground: SolarizedExtras.blueBright,
        fileForeground: SolarizedExtras.base3,
        secondaryForeground: SolarizedPalette.base1,
        // Chrome — lifted one step above the file list
        headerForeground: SolarizedPalette.yellow,
        headerBackground: SolarizedPalette.base03,
        titleBarBackgroundActive: SolarizedPalette.base02,
        titleBarBackgroundInactive: SolarizedPalette.base03,
        statusLineForegroundActive: SolarizedPalette.yellow,
        statusLineForegroundInactive: SolarizedPalette.base1,
        statusLineBackground: SolarizedPalette.base03,
        // Borders
        paneBorderKeyboardTarget: SolarizedPalette.yellow,
        paneBorderActive: SolarizedPalette.base01,
        paneBorderInactive: SolarizedPalette.base02,
        // Folder tree — same abyss base as the file list
        folderTreeBackground: SolarizedExtras.baseAbyss,
        folderTreeForeground: SolarizedExtras.base3,
        folderTreeSelectedForeground: SolarizedPalette.yellow,
        folderTreeFolderIcon: SolarizedExtras.blueBright,
        folderTreeSelectedActive: SolarizedPalette.base02,
        folderTreeSelectedInactive: SolarizedPalette.base02.opacity(0.6),
        folderTreeSectionHeader: SolarizedPalette.yellow.opacity(0.85),
        // Misc
        splitHandleIdle: SolarizedPalette.base02,
        splitHandleActive: SolarizedPalette.yellow,
        // Git — palette accents only
        gitModified: SolarizedPalette.yellow,
        gitAdded: SolarizedPalette.green,
        gitDeleted: SolarizedPalette.red,
        gitRenamed: SolarizedPalette.cyan,
        gitUntracked: SolarizedPalette.base1,
        gitIgnored: SolarizedPalette.base01,
        gitConflicted: SolarizedPalette.magenta
    )
}

// MARK: - Monokai Pro (Filter Octagon)
//
// Canonical Monokai Pro palette — the modern, paid-edition refresh of
// classic Monokai with desaturated, more readable accents. We use the
// "Octagon" filter (default) backgrounds. Red is the soft coral
// `#FF6188` rather than the eye-watering `#F92672` of original Monokai.
//
// Palette reference: https://monokai.pro/
// - bg0 #19181A  deepest
// - bg1 #221F22  chrome
// - bg2 #2D2A2E  main background
// - bg3 #403E41  selection / lift
// - bg4 #5B595C  strong lift
// - text #FCFCFA / comment #727072 / muted #939293
// Accents (Octagon):
//   red    #FF6188  yellow #FFD866  green  #A9DC76
//   blue   #78DCE8  purple #AB9DF2  orange #FC9867

extension Theme {
    private enum MonokaiProPalette {
        static let bg0      = Color(red: 0.098, green: 0.094, blue: 0.102) // #19181A
        static let bg1      = Color(red: 0.133, green: 0.122, blue: 0.133) // #221F22
        static let bg2      = Color(red: 0.176, green: 0.165, blue: 0.180) // #2D2A2E
        static let bg3      = Color(red: 0.251, green: 0.243, blue: 0.255) // #403E41
        static let bg4      = Color(red: 0.357, green: 0.349, blue: 0.361) // #5B595C
        static let text     = Color(red: 0.988, green: 0.988, blue: 0.980) // #FCFCFA
        static let muted    = Color(red: 0.576, green: 0.573, blue: 0.576) // #939293
        static let comment  = Color(red: 0.447, green: 0.439, blue: 0.447) // #727072

        // Accents (Filter Octagon)
        static let red      = Color(red: 1.0,   green: 0.380, blue: 0.533) // #FF6188 — soft coral
        static let orange   = Color(red: 0.988, green: 0.596, blue: 0.404) // #FC9867
        static let yellow   = Color(red: 1.0,   green: 0.847, blue: 0.400) // #FFD866
        static let green    = Color(red: 0.663, green: 0.863, blue: 0.463) // #A9DC76
        static let blue     = Color(red: 0.471, green: 0.863, blue: 0.910) // #78DCE8 — cool cyan-blue
        static let purple   = Color(red: 0.671, green: 0.616, blue: 0.949) // #AB9DF2
    }

    static let monokai = Theme(
        id: "monokai-pro",
        displayName: "Monokai Pro",
        // File pane
        fileListBackground: MonokaiProPalette.bg2,
        fileListRowSelected: MonokaiProPalette.bg3,
        fileListRowDropTarget: MonokaiProPalette.green.opacity(0.35),
        directoryForeground: MonokaiProPalette.blue,
        fileForeground: MonokaiProPalette.text,
        secondaryForeground: MonokaiProPalette.muted,
        // Chrome — yellow runs as the "alert" hue in Monokai Pro Octagon
        // (more readable than red against the warm bg).
        headerForeground: MonokaiProPalette.yellow,
        headerBackground: MonokaiProPalette.bg1,
        titleBarBackgroundActive: MonokaiProPalette.bg3,
        titleBarBackgroundInactive: MonokaiProPalette.bg1,
        statusLineForegroundActive: MonokaiProPalette.yellow,
        statusLineForegroundInactive: MonokaiProPalette.muted,
        statusLineBackground: MonokaiProPalette.bg1,
        // Borders
        paneBorderKeyboardTarget: MonokaiProPalette.yellow,
        paneBorderActive: MonokaiProPalette.purple,
        paneBorderInactive: MonokaiProPalette.bg3,
        // Folder tree
        folderTreeBackground: MonokaiProPalette.bg2,
        folderTreeForeground: MonokaiProPalette.text,
        folderTreeSelectedForeground: MonokaiProPalette.yellow,
        folderTreeFolderIcon: MonokaiProPalette.blue,
        folderTreeSelectedActive: MonokaiProPalette.bg3,
        folderTreeSelectedInactive: MonokaiProPalette.bg3.opacity(0.6),
        folderTreeSectionHeader: MonokaiProPalette.purple.opacity(0.85),
        // Misc
        splitHandleIdle: MonokaiProPalette.bg3,
        splitHandleActive: MonokaiProPalette.yellow,
        // Git — palette accents only; red reserved for delete/conflict
        gitModified: MonokaiProPalette.yellow,
        gitAdded: MonokaiProPalette.green,
        gitDeleted: MonokaiProPalette.red,
        gitRenamed: MonokaiProPalette.blue,
        gitUntracked: MonokaiProPalette.muted,
        gitIgnored: MonokaiProPalette.comment,
        gitConflicted: MonokaiProPalette.orange
    )
}

// MARK: - Dracula (draculatheme.com)
//
// Strict canonical palette. Background #282A36 with currentLine
// (#44475A) for selection. Pink (#FF79C6) is the alert hue. Purple
// (#BD93F9) is the navigational hue paired with cyan for folders.
// `comment` (#6272A4) is the canonical muted color and runs through
// every secondary surface — keeping the violet-leaning identity from
// background to status line.

extension Theme {
    private enum DraculaPalette {
        static let background  = Color(red: 0.157, green: 0.165, blue: 0.212) // #282A36
        static let currentLine = Color(red: 0.267, green: 0.278, blue: 0.353) // #44475A
        static let foreground  = Color(red: 0.973, green: 0.973, blue: 0.949) // #F8F8F2
        static let comment     = Color(red: 0.388, green: 0.408, blue: 0.541) // #6272A4
        static let cyan        = Color(red: 0.545, green: 0.914, blue: 0.992) // #8BE9FD
        static let green       = Color(red: 0.314, green: 0.980, blue: 0.482) // #50FA7B
        static let orange      = Color(red: 1.0,   green: 0.722, blue: 0.424) // #FFB86C
        static let pink        = Color(red: 1.0,   green: 0.475, blue: 0.776) // #FF79C6
        static let purple      = Color(red: 0.741, green: 0.576, blue: 0.976) // #BD93F9
        static let red         = Color(red: 1.0,   green: 0.333, blue: 0.333) // #FF5555
        static let yellow      = Color(red: 0.945, green: 0.980, blue: 0.549) // #F1FA8C
    }

    static let dracula = Theme(
        id: "dracula",
        displayName: "Dracula",
        // File pane
        fileListBackground: DraculaPalette.background,
        fileListRowSelected: DraculaPalette.currentLine,
        fileListRowDropTarget: DraculaPalette.green.opacity(0.40),
        directoryForeground: DraculaPalette.purple,
        fileForeground: DraculaPalette.foreground,
        secondaryForeground: DraculaPalette.comment,
        // Chrome
        headerForeground: DraculaPalette.pink,
        headerBackground: DraculaPalette.currentLine,
        titleBarBackgroundActive: DraculaPalette.currentLine,
        titleBarBackgroundInactive: DraculaPalette.background,
        statusLineForegroundActive: DraculaPalette.pink,
        statusLineForegroundInactive: DraculaPalette.comment,
        statusLineBackground: DraculaPalette.currentLine,
        // Borders
        paneBorderKeyboardTarget: DraculaPalette.pink,
        paneBorderActive: DraculaPalette.purple,
        paneBorderInactive: DraculaPalette.currentLine,
        // Folder tree
        folderTreeBackground: DraculaPalette.background,
        folderTreeForeground: DraculaPalette.foreground,
        folderTreeSelectedForeground: DraculaPalette.cyan,
        folderTreeFolderIcon: DraculaPalette.purple,
        folderTreeSelectedActive: DraculaPalette.currentLine,
        folderTreeSelectedInactive: DraculaPalette.currentLine.opacity(0.6),
        folderTreeSectionHeader: DraculaPalette.pink.opacity(0.85),
        // Misc
        splitHandleIdle: DraculaPalette.currentLine,
        splitHandleActive: DraculaPalette.pink,
        // Git — palette accents only
        gitModified: DraculaPalette.yellow,
        gitAdded: DraculaPalette.green,
        gitDeleted: DraculaPalette.red,
        gitRenamed: DraculaPalette.cyan,
        gitUntracked: DraculaPalette.comment,
        gitIgnored: DraculaPalette.comment.opacity(0.5),
        gitConflicted: DraculaPalette.orange
    )
}

#endif
