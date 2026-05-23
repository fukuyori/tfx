#if os(macOS)
import SwiftUI

/// One file's Git status as surfaced in the file list. Values mirror the
/// XY codes returned by `git status --porcelain=v2`, collapsed into the
/// distinctions tfx actually renders.
///
/// Ordering of the cases is intentional: when a file has differing
/// staged and worktree states (e.g. modified-then-staged-then-modified
/// again), `GitFileStatus.combine` picks the more "noteworthy" status to
/// show in the single-character badge so the user notices unresolved
/// work first.
enum GitFileStatus: Int, Comparable {
    /// Tracked file with unstaged worktree modifications.
    case modified = 50
    /// Tracked file with unstaged worktree deletion.
    case deleted = 60
    /// File renamed or copied between index and HEAD.
    case renamed = 40
    /// File is staged for addition but unmodified in worktree.
    case added = 30
    /// File is untracked (not in `.gitignore`, not in index).
    case untracked = 20
    /// File is excluded by `.gitignore`. Only surfaced when the user
    /// opts into showing ignored badges.
    case ignored = 10
    /// File has a merge conflict.
    case conflicted = 70

    static func < (lhs: GitFileStatus, rhs: GitFileStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Single-character badge displayed in the Git column.
    var badge: String {
        switch self {
        case .modified:   return "M"
        case .added:      return "A"
        case .deleted:    return "D"
        case .renamed:    return "R"
        case .untracked:  return "?"
        case .ignored:    return "!"
        case .conflicted: return "U"
        }
    }

    /// Color hint for the badge. Picked to read against the dark file
    /// pane background while matching Finder-adjacent conventions
    /// (modified = warm, added = green, deleted = red, untracked = dim).
    var color: Color {
        switch self {
        case .modified:   return .yellow
        case .added:      return .green
        case .deleted:    return .red
        case .renamed:    return .cyan
        case .untracked:  return .gray
        case .ignored:    return Color.gray.opacity(0.5)
        case .conflicted: return .red
        }
    }

    /// Pick the more noteworthy of two statuses. Conflicts win over
    /// everything; otherwise the higher raw value wins. Used to fold
    /// an XY pair (staged + worktree) into the single value the badge
    /// column can display.
    static func combine(_ a: GitFileStatus?, _ b: GitFileStatus?) -> GitFileStatus? {
        switch (a, b) {
        case let (a?, b?): return max(a, b)
        case let (a?, nil): return a
        case let (nil, b?): return b
        case (nil, nil): return nil
        }
    }
}

/// Aggregate Git status for one working copy. The status map is keyed by
/// the absolute POSIX path (no trailing slash) so directory entries and
/// file entries hash equivalently — file URLs from `FileManager` carry a
/// trailing slash for directories, which would otherwise miss a lookup.
struct GitRepositoryStatus {
    let workTreeRoot: URL
    /// Short branch name, or `nil` for detached HEAD. When detached,
    /// `detachedHeadShortSHA` carries a 7-char SHA for display.
    let branch: String?
    let detachedHeadShortSHA: String?
    let fileStatus: [String: GitFileStatus]

    /// Status to surface for one row in the file list. Returns nil for
    /// untouched / clean files so the badge column stays empty.
    func status(for url: URL) -> GitFileStatus? {
        // Strip a trailing slash so a directory `FileItem` whose URL
        // ends in `/` still matches the path Git printed (which never
        // carries the trailing slash for the file in `git status`,
        // though it does for untracked directories — see normalize).
        fileStatus[Self.normalize(url.path)]
    }

    static func normalize(_ path: String) -> String {
        var trimmed = path
        while trimmed.count > 1 && trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    /// Display text for the branch segment in the status line.
    /// Uses the Git "⎇ name" convention; falls back to a short SHA in
    /// detached-HEAD state.
    var branchDisplayText: String {
        if let branch {
            return "⎇ \(branch)"
        }
        if let detachedHeadShortSHA {
            return "⎇ (detached \(detachedHeadShortSHA))"
        }
        return "⎇ (detached)"
    }
}

#endif
