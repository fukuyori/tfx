#if os(macOS)
import Foundation

/// Cancellation handle for an in-flight Git status read. Mirrors the
/// pattern used by `DirectoryLoadCancellation`: callers flip
/// `isCancelled` to signal that the in-flight result should be
/// discarded; the worker checks it before publishing.
final class GitStatusCancellation: @unchecked Sendable {
    private let _cancelled = NSLock()
    nonisolated(unsafe) private var _isCancelled = false

    var isCancelled: Bool {
        _cancelled.lock()
        defer { _cancelled.unlock() }
        return _isCancelled
    }

    func cancel() {
        _cancelled.lock()
        _isCancelled = true
        _cancelled.unlock()
    }
}

/// Background-friendly wrapper around `git rev-parse` + `git status` for
/// surfacing per-row decorations.
///
/// All entry points are `nonisolated` and safe to call off the main
/// thread. None of them throw — failures collapse to nil so callers can
/// silently skip Git decoration for non-repository directories without
/// branching on error types. Real errors are written to `stderr` of the
/// underlying `git` invocation, which we deliberately discard.
enum GitStatusReader {
    /// Resolve the work-tree root containing `directory`. Returns nil for
    /// non-Git directories or when `git` is not installed. Cheap enough
    /// to call on every directory entry — `rev-parse` is one syscall +
    /// one stat per parent component.
    nonisolated static func workTreeRoot(near directory: URL) -> URL? {
        guard let output = runGit(arguments: ["rev-parse", "--show-toplevel"], in: directory) else {
            return nil
        }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed).standardizedFileURL
    }

    /// Read repository status for the work tree rooted at `root`.
    /// Returns nil if `git` is not installed, the directory is no longer
    /// a Git working copy, or the read was cancelled.
    ///
    /// `scope` limits the status walk to one subtree via a pathspec.
    /// Row badges only ever need entries under the pane's current
    /// directory, and scoping lets git skip scanning the rest of the
    /// work tree — the difference between milliseconds and seconds on
    /// large monorepos. The `# branch.*` headers are emitted regardless
    /// of pathspec, so the branch indicator is unaffected. Pass nil for
    /// a full-tree status.
    ///
    /// Note: ignored entries are *not* requested (`--ignored=no`) to
    /// keep the call cheap on large repos. The current product decision
    /// is to not surface ignored badges; revisit this when adding that.
    nonisolated static func readStatus(
        root: URL,
        scope: URL? = nil,
        cancellation: GitStatusCancellation? = nil
    ) -> GitRepositoryStatus? {
        if cancellation?.isCancelled == true { return nil }
        var arguments = ["status", "--porcelain=v2", "-b", "-z", "--untracked-files=normal", "--ignored=no"]
        if let scope, scope.standardizedFileURL.path != root.standardizedFileURL.path {
            arguments += ["--", scope.standardizedFileURL.path]
        }
        guard let data = runGitData(arguments: arguments, in: root) else {
            return nil
        }
        if cancellation?.isCancelled == true { return nil }
        return parsePorcelainV2(data: data, root: root)
    }

    // MARK: - Parsing

    /// Split a NUL-terminated entry stream into its individual records.
    ///
    /// `git status --porcelain=v2 -z` terminates every record with NUL,
    /// including the four `# branch.*` header lines. Renamed/copied
    /// entries (prefix `2`) carry an extra NUL-terminated original path
    /// immediately after the main record; the parser reattaches it
    /// while walking the token stream.
    private static func parsePorcelainV2(data: Data, root: URL) -> GitRepositoryStatus {
        // Split on NUL. `Data.split(separator:)` keeps empty trailing
        // chunks; that's fine — we'll skip them during iteration.
        var tokens: [Substring] = []
        if let text = String(data: data, encoding: .utf8) {
            tokens = text.split(separator: "\0", omittingEmptySubsequences: false).map { $0 }
        }

        var branch: String?
        var detachedSHA: String?
        var fileStatus: [String: GitFileStatus] = [:]

        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            defer { index += 1 }
            if token.isEmpty { continue }

            if token.hasPrefix("# branch.head ") {
                let value = String(token.dropFirst("# branch.head ".count))
                if value != "(detached)" {
                    branch = value
                }
            } else if token.hasPrefix("# branch.oid ") {
                let value = String(token.dropFirst("# branch.oid ".count))
                detachedSHA = String(value.prefix(7))
            } else if token.hasPrefix("# ") {
                // Other header lines we don't currently surface.
                continue
            } else if token.hasPrefix("1 ") {
                // 1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>
                if let entry = parseOrdinaryChange(token, root: root) {
                    fileStatus[entry.key] = entry.status
                }
            } else if token.hasPrefix("2 ") {
                // 2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X<score>> <path>
                // followed by an extra NUL-terminated <origPath> token.
                let entry = parseRenameChange(token, root: root)
                index += 1  // consume the orig-path token regardless
                if let entry {
                    fileStatus[entry.key] = entry.status
                }
            } else if token.hasPrefix("u ") {
                if let entry = parseUnmerged(token, root: root) {
                    fileStatus[entry.key] = entry.status
                }
            } else if token.hasPrefix("? ") {
                let path = String(token.dropFirst(2))
                fileStatus[pathKey(root: root, relative: path)] = .untracked
            } else if token.hasPrefix("! ") {
                let path = String(token.dropFirst(2))
                fileStatus[pathKey(root: root, relative: path)] = .ignored
            }
        }

        // If branch.head was "(detached)", `branch` stays nil and the
        // detached-HEAD short SHA carries the display label.
        return GitRepositoryStatus(
            workTreeRoot: root,
            branch: branch,
            detachedHeadShortSHA: branch == nil ? detachedSHA : nil,
            fileStatus: fileStatus
        )
    }

    private struct ParsedEntry {
        let key: String
        let status: GitFileStatus
    }

    /// Parse `1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>`.
    /// `XY` is two chars: index status + worktree status. We collapse
    /// them into the single status displayed in the badge column.
    private static func parseOrdinaryChange(_ token: Substring, root: URL) -> ParsedEntry? {
        // Drop the leading "1 " then split off the 7 fixed fields. The
        // path is the remainder and may contain spaces, so we cannot
        // use a plain whitespace split for the whole token.
        let body = token.dropFirst(2)
        // Find the 8th space — fields are: XY sub mH mI mW hH hI path
        var spacesSeen = 0
        var pathStart: Substring.Index?
        for index in body.indices {
            if body[index] == " " {
                spacesSeen += 1
                if spacesSeen == 7 {
                    pathStart = body.index(after: index)
                    break
                }
            }
        }
        guard let pathStart else { return nil }

        let xy = body.prefix(2)
        let path = body[pathStart...]
        guard let status = statusFromXY(String(xy)) else { return nil }
        return ParsedEntry(key: pathKey(root: root, relative: String(path)), status: status)
    }

    /// Parse `2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X<score>> <path>`.
    /// One extra field (the rename score, e.g. `R100`) before the path.
    private static func parseRenameChange(_ token: Substring, root: URL) -> ParsedEntry? {
        let body = token.dropFirst(2)
        var spacesSeen = 0
        var pathStart: Substring.Index?
        for index in body.indices {
            if body[index] == " " {
                spacesSeen += 1
                if spacesSeen == 8 {
                    pathStart = body.index(after: index)
                    break
                }
            }
        }
        guard let pathStart else { return nil }

        let xy = body.prefix(2)
        let path = body[pathStart...]
        let status = statusFromXY(String(xy)) ?? .renamed
        return ParsedEntry(key: pathKey(root: root, relative: String(path)), status: status)
    }

    /// Parse `u <XY> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>`.
    /// All unmerged entries collapse to `.conflicted` regardless of XY.
    private static func parseUnmerged(_ token: Substring, root: URL) -> ParsedEntry? {
        let body = token.dropFirst(2)
        var spacesSeen = 0
        var pathStart: Substring.Index?
        for index in body.indices {
            if body[index] == " " {
                spacesSeen += 1
                if spacesSeen == 9 {
                    pathStart = body.index(after: index)
                    break
                }
            }
        }
        guard let pathStart else { return nil }
        let path = body[pathStart...]
        return ParsedEntry(key: pathKey(root: root, relative: String(path)), status: .conflicted)
    }

    /// Reduce the two-character XY code from porcelain=v2 into the
    /// single status we display. `.` means "no change for this side".
    /// Index changes (X) and worktree changes (Y) both surface; if
    /// both are set we keep the more noteworthy one.
    private static func statusFromXY(_ xy: String) -> GitFileStatus? {
        guard xy.count == 2 else { return nil }
        let chars = Array(xy)
        let staged = statusFromCode(chars[0])
        let worktree = statusFromCode(chars[1])
        return GitFileStatus.combine(staged, worktree)
    }

    private static func statusFromCode(_ char: Character) -> GitFileStatus? {
        switch char {
        case ".":      return nil
        case "M", "T": return .modified  // T = type change, still "modified" to the user
        case "A":      return .added
        case "D":      return .deleted
        case "R", "C": return .renamed
        case "U":      return .conflicted
        case "?":      return .untracked
        case "!":      return .ignored
        default:       return nil
        }
    }

    /// Compose the lookup key (absolute POSIX path with no trailing
    /// slash) for a path that `git status` printed relative to `root`.
    /// `GitRepositoryStatus.normalize` strips any trailing slash that
    /// Git emits for untracked directories so the same key matches
    /// regardless of whether `FileItem.url` carries a trailing slash.
    private static func pathKey(root: URL, relative: String) -> String {
        let absolute = root.appendingPathComponent(relative).standardizedFileURL.path
        return GitRepositoryStatus.normalize(absolute)
    }

    // MARK: - Process invocation

    /// Run `git <arguments>` from `directory` and return stdout as a
    /// string, or nil if the process failed. Stderr is silently
    /// dropped — most expected failures (non-repo, missing git) are
    /// already represented by a non-zero exit, and surfacing the
    /// underlying error text would just clutter the UI.
    nonisolated private static func runGit(arguments: [String], in directory: URL) -> String? {
        guard let data = runGitData(arguments: arguments, in: directory) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    nonisolated private static func runGitData(arguments: [String], in directory: URL) -> Data? {
        // We use the `xcrun --find git` toolchain location implicitly
        // by hard-coding `/usr/bin/git`. Xcode's command-line tools
        // ship a git binary; if it's missing on the user's machine,
        // Git decoration silently degrades to "no badges".
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory

        // Inherit a minimal, deterministic environment. Avoid pulling
        // in the user's full env (locale, GIT_*, etc.) so output stays
        // parseable. PATH is still useful for `git`'s own helper
        // binaries.
        var env = ProcessInfo.processInfo.environment.filter { key, _ in
            key == "PATH" || key == "HOME" || key.hasPrefix("XPC_")
        }
        env["LC_ALL"] = "C"
        env["GIT_OPTIONAL_LOCKS"] = "0"  // avoid touching .git/index.lock
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        // Drain stderr CONCURRENTLY with stdout, then discard
        // (surfacing git stderr would clutter the UI). Reading it
        // only after stdout hit EOF could deadlock: git blocking
        // on a full 64 KB stderr pipe never closes stdout.
        let stderrHandle = stderrPipe.fileHandleForReading
        DispatchQueue.global(qos: .utility).async {
            _ = stderrHandle.readDataToEndOfFile()
        }

        // Watchdog: a git that never returns (repository on a dead
        // NFS/SMB mount, broken fsmonitor hook) would otherwise
        // pin this worker thread forever — and each navigation
        // spawns a fresh worker, so hung mounts leak threads until
        // the GCD pool (~64) is exhausted and every background
        // task in the app stalls. SIGTERM first, SIGKILL if git
        // ignores it.
        let timeout: TimeInterval = 30
        let watchdog = DispatchWorkItem {
            guard process.isRunning else { return }
            process.terminate()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: watchdog)

        // Drain stdout while the process runs to avoid deadlocking
        // on the pipe buffer for large status output.
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()

        guard process.terminationStatus == 0 else { return nil }
        return data
    }
}

#endif
