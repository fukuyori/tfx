#if os(macOS)
import Combine
import Darwin
import Foundation

@MainActor
final class BuiltInTerminalModel: ObservableObject {
    enum Tab {
        case shell
        case output
    }

    struct OutputEvent: Equatable {
        let id: UUID
        let text: String
    }

    @Published var currentDirectory: URL
    @Published private(set) var rawTerminalTranscript = ""

    /// Rendered plain-text views of the decoder state, computed
    /// on demand. These used to be `@Published` strings rebuilt
    /// (full `lines.joined()`, twice) on every 4 KB output chunk
    /// — O(n²) main-thread work that saturated the app during
    /// `find /`-style floods. Nothing subscribes to them as
    /// publishers: the pane renders through xterm.js fed by
    /// `outputEvent`, and tests read the property directly.
    var transcript: String { outputDecoder.renderedText() }
    var displayTranscript: String { outputDecoder.renderedTextWithCursor() }
    @Published var commandOutputTranscript = ""
    @Published var activeTab: Tab = .shell
    @Published var outputEvent: OutputEvent?
    @Published var commandText = ""
    @Published var isRunning = false
    @Published var terminalExitRequestID = UUID()

    private var shellPath: String
    private var session: PTYTerminalSession?
    private var outputDecoder = TerminalOutputDecoder()
    private var interactiveCommandBuffer = ""
    private var isIgnoringEscapeSequence = false
    private var isClosingSessionExplicitly = false

    init(
        currentDirectory: URL = URL(fileURLWithPath: NSHomeDirectory()),
        shellPath: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    ) {
        let initialDirectory = currentDirectory.standardizedFileURL
        self.currentDirectory = initialDirectory
        self.shellPath = shellPath.isEmpty ? "/bin/zsh" : shellPath
        outputDecoder.reset(with: Self.initialTranscript)
    }

    private static let initialTranscript = "tfx built-in terminal\n"

    deinit {
        session?.terminate()
    }

    func followDirectory(_ directory: URL) {
        let standardizedDirectory = directory.standardizedFileURL
        guard currentDirectory != standardizedDirectory else { return }
        guard session == nil else { return }
        currentDirectory = standardizedDirectory
    }

    func open() {
        activeTab = .shell
        startSessionIfNeeded()
    }

    func showOutput() {
        activeTab = .output
    }

    func close() {
        let activeSession = session
        if activeSession != nil {
            isClosingSessionExplicitly = true
        }
        session = nil
        isRunning = false
        interactiveCommandBuffer = ""
        isIgnoringEscapeSequence = false
        activeSession?.terminate()
    }

    func reportStartupError(_ message: String) {
        appendTerminalOutput("Terminal startup error: \(message)\n")
        isRunning = false
    }

    func appendUserCommandOutput(_ output: String) {
        commandOutputTranscript += output
        activeTab = .output
    }

    func submitCommand() {
        let command = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        commandText = ""
        guard !command.isEmpty else { return }

        if session == nil, Self.isExitCommand(command) {
            // `exit` typed at the input field when no shell is
            // running (e.g. a user idled at the prompt after a
            // previous shell exited). Treat this exactly like a
            // natural shell exit: wipe the transcript so the
            // next time the pane comes up it starts fresh.
            resetTranscript()
            terminalExitRequestID = UUID()
            return
        }

        startSessionIfNeeded()
        updateCurrentDirectoryIfSimpleCD(command)
        session?.write(command + "\n")
    }

    func sendInterrupt() {
        sendControlCharacter(0x03)
    }

    func sendQuit() {
        sendControlCharacter(0x1C)
    }

    func sendSuspend() {
        sendControlCharacter(0x1A)
    }

    func sendEndOfTransmission() {
        startSessionIfNeeded()
        session?.write(Data([4]))
    }

    func sendText(_ text: String) {
        guard !text.isEmpty else { return }
        startSessionIfNeeded()
        session?.write(text)
    }

    func sendTerminalInput(_ input: String) {
        guard !input.isEmpty else { return }
        startSessionIfNeeded()
        session?.write(input)
        recordTerminalInput(input)
    }

    func sendReturn() {
        startSessionIfNeeded()
        session?.write("\r")
    }

    func sendBackspace() {
        startSessionIfNeeded()
        session?.write(Data([0x7F]))
    }

    func sendEscape() {
        startSessionIfNeeded()
        session?.write(Data([0x1B]))
    }

    func sendTab() {
        startSessionIfNeeded()
        session?.write("\t")
    }

    func sendDelete() {
        startSessionIfNeeded()
        session?.write("\u{1B}[3~")
    }

    func sendArrowUp() {
        startSessionIfNeeded()
        session?.write("\u{1B}[A")
    }

    func sendArrowDown() {
        startSessionIfNeeded()
        session?.write("\u{1B}[B")
    }

    func sendArrowRight() {
        startSessionIfNeeded()
        session?.write("\u{1B}[C")
    }

    func sendArrowLeft() {
        startSessionIfNeeded()
        session?.write("\u{1B}[D")
    }

    private func sendControlCharacter(_ byte: UInt8) {
        startSessionIfNeeded()
        session?.write(Data([byte]))
        if let scalar = UnicodeScalar(UInt32(byte)) {
            recordTerminalInput(String(scalar))
        }
    }

    func insertPaths(_ urls: [URL]) {
        let arguments = urls
            .map { Self.shellQuotedPath($0.path) }
            .joined(separator: " ")
        guard !arguments.isEmpty else { return }

        if session != nil {
            sendTerminalInput(arguments + " ")
            return
        }

        if !commandText.isEmpty, commandText.last?.isWhitespace == false {
            commandText += " "
        }
        commandText += arguments
    }

    private func startSessionIfNeeded() {
        guard session == nil else { return }

        do {
            isRunning = true
            let terminalSession = try PTYTerminalSession(
                shellPath: shellPath,
                currentDirectory: currentDirectory,
                onOutput: { output in
                    Task { @MainActor [weak self] in
                        self?.appendTerminalOutput(output)
                    }
                },
                onExit: {
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.session = nil
                        self.isRunning = false
                        if self.isClosingSessionExplicitly {
                            self.isClosingSessionExplicitly = false
                        } else {
                            // Shell exited on its own (the user
                            // typed `exit`, hit Ctrl-D, etc.).
                            // Wipe the transcript here so that
                            // when the user re-opens the pane,
                            // `startSessionIfNeeded()` spawns a
                            // fresh shell against a fresh
                            // display — instead of looking like
                            // the previous session was restored
                            // (its bytes were still on screen
                            // even though the PTY was gone).
                            self.resetTranscript()
                            self.terminalExitRequestID = UUID()
                        }
                    }
                }
            )
            session = terminalSession
            terminalSession.start()
        } catch {
            appendTerminalOutput("Failed to start terminal: \(error.localizedDescription)\n")
            isRunning = false
        }
    }

    /// Drop everything the previous shell wrote (rendered
    /// transcript, raw bytes, captured user-command output, the
    /// half-typed escape-sequence state machine) and reset the
    /// shown tab to the live shell. Used whenever a session ends
    /// non-explicitly so the next `open()` paints a clean pane
    /// instead of resurrecting the dead shell's output.
    private func resetTranscript() {
        rawTerminalTranscript = ""
        commandOutputTranscript = ""
        interactiveCommandBuffer = ""
        isIgnoringEscapeSequence = false
        activeTab = .shell
        outputDecoder.reset(with: Self.initialTranscript)
    }

    private func appendTerminalOutput(_ output: String) {
        rawTerminalTranscript += output
        trimRawTranscriptIfNeeded()
        outputEvent = OutputEvent(id: UUID(), text: output)
        outputDecoder.consume(output)
    }

    /// Upper bound for the raw byte replay buffer (used to
    /// repaint xterm.js when the pane's web view is recreated).
    /// xterm keeps a 5 000-line scrollback anyway, so replaying
    /// more than this is wasted memory — and without a cap the
    /// buffer grows without limit for as long as the shell keeps
    /// producing output.
    private static let maxRawTranscriptUTF8Bytes = 512 * 1024

    private func trimRawTranscriptIfNeeded() {
        let utf8View = rawTerminalTranscript.utf8
        guard utf8View.count > Self.maxRawTranscriptUTF8Bytes else { return }
        // Cut down to ~3/4 of the cap (amortizes the trim) and
        // land on a line boundary so the replay doesn't start
        // mid-escape-sequence.
        let keepTarget = Self.maxRawTranscriptUTF8Bytes * 3 / 4
        var rawCut = utf8View.index(utf8View.startIndex, offsetBy: utf8View.count - keepTarget)
        // A byte offset can land mid-character; walk forward to
        // the next Character boundary.
        var characterCut = String.Index(rawCut, within: rawTerminalTranscript)
        while characterCut == nil, rawCut < utf8View.endIndex {
            rawCut = utf8View.index(after: rawCut)
            characterCut = String.Index(rawCut, within: rawTerminalTranscript)
        }
        var cutIndex = characterCut ?? rawTerminalTranscript.startIndex
        if let newline = rawTerminalTranscript[cutIndex...].firstIndex(of: "\n") {
            cutIndex = rawTerminalTranscript.index(after: newline)
        }
        rawTerminalTranscript = String(rawTerminalTranscript[cutIndex...])
    }

    func resize(columns: Int, rows: Int) {
        session?.resize(columns: columns, rows: rows)
    }

    /// Snapshot the actual working directory of the shell (or
    /// whatever foreground process is currently attached to the
    /// PTY). Read directly from the kernel via `tcgetpgrp` +
    /// `proc_pidinfo` — does not write anything to the shell, so
    /// the terminal output stays clean. Returns `nil` if there
    /// is no active session or the lookup fails (e.g. the
    /// foreground process exited between query and lookup).
    func foregroundWorkingDirectory() -> URL? {
        session?.foregroundWorkingDirectory()
    }

    private func updateCurrentDirectoryIfSimpleCD(_ command: String) {
        guard command == "cd" || command.hasPrefix("cd ") else { return }
        let rawPath = command == "cd" ? NSHomeDirectory() : Self.normalizedPathArgument(String(command.dropFirst(3)))
        let resolvedPath: String
        if rawPath.hasPrefix("~") {
            resolvedPath = (rawPath as NSString).expandingTildeInPath
        } else if rawPath.hasPrefix("/") {
            resolvedPath = rawPath
        } else {
            resolvedPath = currentDirectory.appendingPathComponent(rawPath).path
        }

        let url = URL(fileURLWithPath: resolvedPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            currentDirectory = url
        }
    }

    private func recordTerminalInput(_ input: String) {
        for scalar in input.unicodeScalars {
            if isIgnoringEscapeSequence {
                if scalar.value >= 0x40, scalar.value <= 0x7E {
                    isIgnoringEscapeSequence = false
                }
                continue
            }

            switch scalar.value {
            case 0x1B:
                isIgnoringEscapeSequence = true
            case 0x03, 0x15, 0x1A, 0x1C:
                interactiveCommandBuffer = ""
            case 0x08, 0x7F:
                if !interactiveCommandBuffer.isEmpty {
                    interactiveCommandBuffer.removeLast()
                }
            case 0x0A, 0x0D:
                let command = interactiveCommandBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                interactiveCommandBuffer = ""
                updateCurrentDirectoryIfSimpleCD(command)
            default:
                if scalar.value >= 0x20 {
                    interactiveCommandBuffer.append(Character(scalar))
                }
            }
        }
    }

    nonisolated static func isExitCommand(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "exit" || trimmed == "logout"
    }

    nonisolated private static func normalizedPathArgument(_ argument: String) -> String {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return trimmed }

        let first = trimmed.first
        let last = trimmed.last
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed.replacingOccurrences(of: "\\ ", with: " ")
    }

    nonisolated static func shellQuotedPath(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private struct TerminalOutputDecoder {
    private enum EscapeState {
        case normal
        case escape
        case csi
        case osc
        case oscEscape
    }

    private var state: EscapeState = .normal
    private var csiBuffer = ""
    private var lines: [String] = [""]
    private var cursorRow = 0
    private var cursorColumn = 0

    /// Matches xterm.js's `scrollback: 5000`. Without a cap the
    /// decoder's line buffer grows for as long as the shell
    /// produces output — `yes` or a long build log would push
    /// memory (and every subsequent render) without bound.
    private static let maxLines = 5_000

    mutating func reset(with text: String) {
        lines = text.components(separatedBy: "\n")
        if lines.isEmpty {
            lines = [""]
        }
        cursorRow = lines.count - 1
        cursorColumn = lines[cursorRow].unicodeScalars.count
        state = .normal
        csiBuffer = ""
    }

    mutating func consume(_ rawOutput: String) {
        for scalar in rawOutput.unicodeScalars {
            append(scalar)
        }
        trimExcessLines()
    }

    func renderedText() -> String {
        lines.joined(separator: "\n")
    }

    private mutating func trimExcessLines() {
        let excess = lines.count - Self.maxLines
        guard excess > 0 else { return }
        lines.removeFirst(excess)
        cursorRow = max(0, cursorRow - excess)
    }

    func renderedTextWithCursor() -> String {
        var displayLines = lines
        let row = max(0, min(cursorRow, displayLines.count - 1))
        var scalars = Array(displayLines[row].unicodeScalars)
        let column = max(0, min(cursorColumn, scalars.count))
        scalars.insert("▌", at: column)
        displayLines[row] = String(String.UnicodeScalarView(scalars))
        return displayLines.joined(separator: "\n")
    }

    private mutating func append(_ scalar: UnicodeScalar) {
        switch state {
        case .normal:
            appendPrintable(scalar)
        case .escape:
            handleEscapeFollower(scalar)
        case .csi:
            if isCSIFinalByte(scalar) {
                handleCSI(final: scalar)
                csiBuffer = ""
                state = .normal
            } else {
                csiBuffer.unicodeScalars.append(scalar)
            }
        case .osc:
            if scalar.value == 0x07 {
                state = .normal
            } else if scalar.value == 0x1B {
                state = .oscEscape
            }
        case .oscEscape:
            state = scalar == "\\" ? .normal : .osc
        }
    }

    private mutating func appendPrintable(_ scalar: UnicodeScalar) {
        switch scalar.value {
        case 0x08, 0x7F:
            cursorColumn = max(0, cursorColumn - 1)
        case 0x09:
            for _ in 0..<4 {
                writeVisibleScalar(" ")
            }
        case 0x0A:
            cursorRow += 1
            cursorColumn = 0
            ensureCursorPosition()
        case 0x0D:
            cursorColumn = 0
        case 0x1B:
            state = .escape
        case 0x00...0x1F:
            return
        default:
            writeVisibleScalar(scalar)
        }
    }

    private mutating func handleEscapeFollower(_ scalar: UnicodeScalar) {
        switch scalar {
        case "[":
            csiBuffer = ""
            state = .csi
        case "]":
            state = .osc
        default:
            state = .normal
        }
    }

    private func isCSIFinalByte(_ scalar: UnicodeScalar) -> Bool {
        (0x40...0x7E).contains(scalar.value)
    }

    private mutating func handleCSI(final: UnicodeScalar) {
        let parameters = csiParameters()
        switch final {
        case "A":
            cursorRow = max(0, cursorRow - parameter(at: 0, defaultValue: 1, parameters: parameters))
        case "B":
            cursorRow += parameter(at: 0, defaultValue: 1, parameters: parameters)
            ensureCursorPosition()
        case "C":
            cursorColumn += parameter(at: 0, defaultValue: 1, parameters: parameters)
            ensureCursorPosition()
        case "D":
            cursorColumn = max(0, cursorColumn - parameter(at: 0, defaultValue: 1, parameters: parameters))
        case "G":
            cursorColumn = max(0, parameter(at: 0, defaultValue: 1, parameters: parameters) - 1)
            ensureCursorPosition()
        case "H", "f":
            cursorRow = max(0, parameter(at: 0, defaultValue: 1, parameters: parameters) - 1)
            cursorColumn = max(0, parameter(at: 1, defaultValue: 1, parameters: parameters) - 1)
            ensureCursorPosition()
        case "J":
            clearScreen(mode: parameter(at: 0, defaultValue: 0, parameters: parameters))
        case "K":
            clearLine(mode: parameter(at: 0, defaultValue: 0, parameters: parameters))
        default:
            return
        }
    }

    private func csiParameters() -> [Int?] {
        let sanitized = csiBuffer.filter { character in
            character.isNumber || character == ";"
        }
        guard !sanitized.isEmpty else { return [] }
        return sanitized.split(separator: ";", omittingEmptySubsequences: false).map { token in
            token.isEmpty ? nil : Int(token)
        }
    }

    private func parameter(at index: Int, defaultValue: Int, parameters: [Int?]) -> Int {
        guard parameters.indices.contains(index), let value = parameters[index] else {
            return defaultValue
        }
        return value == 0 ? defaultValue : value
    }

    private mutating func clearScreen(mode: Int) {
        switch mode {
        case 2, 3:
            lines = [""]
            cursorRow = 0
            cursorColumn = 0
        default:
            clearLine(mode: 0)
            if cursorRow + 1 < lines.count {
                lines.removeSubrange((cursorRow + 1)..<lines.count)
            }
        }
    }

    private mutating func clearLine(mode: Int) {
        ensureCursorPosition()
        var scalars = Array(lines[cursorRow].unicodeScalars)
        switch mode {
        case 1:
            let end = min(cursorColumn, scalars.count)
            for index in 0..<end {
                scalars[index] = " "
            }
        case 2:
            scalars.removeAll()
            cursorColumn = 0
        default:
            if cursorColumn < scalars.count {
                scalars.removeSubrange(cursorColumn..<scalars.count)
            }
        }
        lines[cursorRow] = String(String.UnicodeScalarView(scalars))
    }

    private mutating func writeVisibleScalar(_ scalar: UnicodeScalar) {
        ensureCursorPosition()
        var scalars = Array(lines[cursorRow].unicodeScalars)
        if cursorColumn < scalars.count {
            scalars[cursorColumn] = scalar
        } else {
            while scalars.count < cursorColumn {
                scalars.append(" ")
            }
            scalars.append(scalar)
        }
        lines[cursorRow] = String(String.UnicodeScalarView(scalars))
        cursorColumn += 1
    }

    private mutating func ensureCursorPosition() {
        while cursorRow >= lines.count {
            lines.append("")
        }
        var scalars = Array(lines[cursorRow].unicodeScalars)
        while cursorColumn > scalars.count {
            scalars.append(" ")
        }
        lines[cursorRow] = String(String.UnicodeScalarView(scalars))
    }
}

nonisolated private final class PTYTerminalSession: @unchecked Sendable {
    private let shellPath: String
    private let currentDirectory: URL
    private let onOutput: @Sendable (String) -> Void
    private let onExit: @Sendable () -> Void
    private let lock = NSLock()

    private var masterFD: Int32 = -1
    private var childPID: pid_t = -1
    private var readSource: DispatchSourceRead?
    private var didExit = false

    init(
        shellPath: String,
        currentDirectory: URL,
        onOutput: @escaping @Sendable (String) -> Void,
        onExit: @escaping @Sendable () -> Void
    ) throws {
        self.shellPath = shellPath
        self.currentDirectory = currentDirectory
        self.onOutput = onOutput
        self.onExit = onExit
    }

    func start() {
        let directoryPath = currentDirectory.path
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent
        var master: Int32 = -1
        var size = winsize(ws_row: 24, ws_col: 100, ws_xpixel: 0, ws_ypixel: 0)
        let pid = forkpty(&master, nil, nil, &size)

        guard pid >= 0 else {
            onOutput("Failed to start shell: \(String(cString: strerror(errno)))\n")
            finish()
            return
        }

        if pid == 0 {
            childExecuteShell(shellPath: shellPath, shellName: shellName, directoryPath: directoryPath)
        }

        lock.lock()
        masterFD = master
        childPID = pid
        lock.unlock()

        _ = fcntl(masterFD, F_SETFL, fcntl(masterFD, F_GETFL) | O_NONBLOCK)
        startReading()
    }

    /// Walk the PTY's foreground process group (or fall back to
    /// the shell itself) and ask the kernel for its current
    /// working directory via `proc_pidinfo`. Returns `nil` if
    /// the FD is gone or the process exited.
    ///
    /// When the foreground process is a tmux client, the kernel
    /// only knows the client's own cwd — which is wherever the
    /// user ran `tmux` from, NOT the cwd of the pane the user is
    /// currently looking at (each pane's shell lives under the
    /// tmux *server* and has its own controlling tty that is
    /// unreachable from our master fd). Special-case that path
    /// by shelling out to tmux's own `display-message` query.
    /// Zellij and other multiplexers have no equivalently clean
    /// external CWD query, so they keep using the generic kernel
    /// lookup — which returns the multiplexer's own startup cwd,
    /// the best safe approximation without injecting commands
    /// into the running session.
    func foregroundWorkingDirectory() -> URL? {
        lock.lock()
        let fd = masterFD
        let shellPID = childPID
        lock.unlock()
        guard fd >= 0 else { return nil }

        // Prefer the foreground process group leader so commands
        // like `(cd /tmp && bash)` reflect the inner shell's cwd
        // rather than the outer login shell's.
        let pgid = tcgetpgrp(fd)
        let targetPID = pgid > 0 ? pid_t(pgid) : shellPID
        guard targetPID > 0 else { return nil }

        if let executablePath = Self.processExecutablePath(targetPID),
           (executablePath as NSString).lastPathComponent == "tmux",
           let url = Self.tmuxActivePaneCWD(clientPID: targetPID, tmuxBinaryPath: executablePath) {
            return url
        }

        return Self.kernelReportedCWD(of: targetPID)
    }

    /// `proc_pidinfo(PROC_PIDVNODEPATHINFO)` — works for any
    /// regular process attached to its own tty, including the
    /// non-multiplexer shell case.
    nonisolated private static func kernelReportedCWD(of pid: pid_t) -> URL? {
        var info = proc_vnodepathinfo()
        let infoSize = MemoryLayout<proc_vnodepathinfo>.size
        let result = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
            proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, ptr, Int32(infoSize))
        }
        guard result == Int32(infoSize) else { return nil }

        let path = withUnsafePointer(to: &info.pvi_cdir.vip_path) { tuplePtr -> String in
            tuplePtr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { cstr in
                String(cString: cstr)
            }
        }
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).standardizedFileURL
    }

    /// Absolute path to a process's executable image. We reuse
    /// this path as the tmux binary to invoke, so we always hit
    /// the SAME tmux build the user is running (no PATH search
    /// surprises across Homebrew / Apple Silicon / Intel).
    nonisolated private static func processExecutablePath(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let written = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard written > 0 else { return nil }
        return String(cString: buffer)
    }

    /// External query for the cwd of the tmux pane the user is
    /// currently focused on. Three attempts:
    ///
    /// 1. Bare `tmux display-message -p '#{pane_current_path}'`
    ///    — `tmux` picks the most-recently-active session
    ///    automatically, which matches the live client in
    ///    single-session setups (the overwhelmingly common case).
    /// 2. If that fails, query `list-clients` and match by
    ///    `#{client_pid}` so multi-session setups still resolve
    ///    correctly.
    /// 3. Anything still failing returns `nil` and the caller
    ///    falls back to the kernel-reported cwd of the tmux
    ///    client itself.
    ///
    /// All invocations use the user's own tmux binary (via
    /// `processExecutablePath`) so they share the server socket
    /// and version that the live session is running on.
    nonisolated private static func tmuxActivePaneCWD(clientPID: pid_t, tmuxBinaryPath: String) -> URL? {
        if let path = tmuxQueryPath(tmuxBinaryPath: tmuxBinaryPath, target: nil) {
            return path
        }

        guard let clientsOutput = runCapturingStdout(
            executable: tmuxBinaryPath,
            arguments: ["list-clients", "-F", "#{client_pid}\t#{session_id}"]
        ) else { return nil }

        var sessionID: String?
        for line in clientsOutput.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let pid = pid_t(parts[0]) else { continue }
            if pid == clientPID {
                sessionID = String(parts[1])
                break
            }
        }
        guard let sessionID else { return nil }

        return tmuxQueryPath(tmuxBinaryPath: tmuxBinaryPath, target: sessionID)
    }

    nonisolated private static func tmuxQueryPath(tmuxBinaryPath: String, target: String?) -> URL? {
        var args = ["display-message", "-p"]
        if let target {
            args.append(contentsOf: ["-t", target])
        }
        args.append("#{pane_current_path}")

        guard let output = runCapturingStdout(executable: tmuxBinaryPath, arguments: args) else { return nil }
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, path.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: path).standardizedFileURL
    }

    /// Run a short-lived helper, capture its stdout, and bail out
    /// with `nil` on launch failure, non-zero exit, or a 1.5-second
    /// timeout. Stderr is discarded so the integration is silent
    /// even if tmux complains. Synchronous on purpose — this is
    /// driven by a user button click and the timeout keeps the UI
    /// from stalling if the tmux socket has gone weird.
    nonisolated private static func runCapturingStdout(
        executable: String,
        arguments: [String],
        timeout: TimeInterval = 1.5
    ) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()

        // Set the handler BEFORE `run()` so a fast-exiting
        // subprocess (tmux returns in single-digit ms) cannot
        // terminate before we wire up the signal and leave us
        // waiting on a semaphore that will never fire.
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }

        do {
            try process.run()
        } catch {
            return nil
        }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func childExecuteShell(shellPath: String, shellName: String, directoryPath: String) -> Never {
        _ = chdir(directoryPath)
        setenv("TERM", "xterm-256color", 1)
        // Advertise truecolor support so CLI tools (delta, bat,
        // fzf, etc.) emit 24-bit RGB escapes instead of falling
        // back to the 256-color palette.
        setenv("COLORTERM", "truecolor", 1)
        setenv("PWD", directoryPath, 1)

        shellPath.withCString { shellCString in
            shellName.withCString { shellNameCString in
                let arg0 = strdup(shellNameCString)
                let arg1 = strdup("-l")
                var arguments: [UnsafeMutablePointer<CChar>?] = [arg0, arg1, nil]
                execv(shellCString, &arguments)
            }
        }
        _exit(127)
    }

    func write(_ string: String) {
        write(Data(string.utf8))
    }

    func write(_ data: Data) {
        lock.lock()
        let fd = masterFD
        lock.unlock()
        guard fd >= 0 else { return }

        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var written = 0
            while written < rawBuffer.count {
                let result = Darwin.write(fd, baseAddress.advanced(by: written), rawBuffer.count - written)
                if result > 0 {
                    written += result
                } else if errno == EINTR {
                    continue
                } else {
                    break
                }
            }
        }
    }

    func resize(columns: Int, rows: Int) {
        let safeColumns = UInt16(max(2, min(columns, Int(UInt16.max))))
        let safeRows = UInt16(max(1, min(rows, Int(UInt16.max))))

        lock.lock()
        let fd = masterFD
        let pid = childPID
        lock.unlock()
        guard fd >= 0 else { return }

        var size = winsize(ws_row: safeRows, ws_col: safeColumns, ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(fd, TIOCSWINSZ, &size)
        if pid > 0 {
            kill(pid, SIGWINCH)
        }
    }

    func terminate() {
        lock.lock()
        let pid = childPID
        lock.unlock()
        if pid > 0 {
            kill(pid, SIGHUP)
        }
        finish()
    }

    private func startReading() {
        let source = DispatchSource.makeReadSource(fileDescriptor: masterFD, queue: DispatchQueue.global(qos: .userInitiated))
        source.setEventHandler { [weak self] in
            self?.readAvailableBytes()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let fd = self.masterFD
            self.masterFD = -1
            self.lock.unlock()
            if fd >= 0 {
                close(fd)
            }
        }
        readSource = source
        source.resume()
    }

    private func readAvailableBytes() {
        lock.lock()
        let fd = masterFD
        lock.unlock()
        guard fd >= 0 else { return }

        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count > 0 {
                onOutput(String(decoding: buffer.prefix(count), as: UTF8.self))
            } else if count == 0 {
                finish()
                return
            } else if errno == EAGAIN || errno == EWOULDBLOCK {
                return
            } else if errno == EINTR {
                continue
            } else {
                finish()
                return
            }
        }
    }

    private func finish() {
        lock.lock()
        guard !didExit else {
            lock.unlock()
            return
        }
        didExit = true
        lock.unlock()

        readSource?.cancel()
        readSource = nil

        lock.lock()
        let pid = childPID
        childPID = -1
        lock.unlock()
        if pid > 0 {
            var status: Int32 = 0
            if waitpid(pid, &status, WNOHANG) == 0 {
                // The child hasn't exited yet — `terminate()`
                // calls us immediately after sending SIGHUP, so
                // this is the common path when closing the pane.
                // A one-shot WNOHANG here leaked the child as a
                // zombie for the rest of the app's lifetime
                // (`didExit` guarantees no second waitpid).
                // Reap on a background queue instead: grace
                // period, SIGKILL if it ignored SIGHUP, then a
                // blocking waitpid — which is safe because an
                // unreaped child's PID cannot be reused.
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    var lateStatus: Int32 = 0
                    if waitpid(pid, &lateStatus, WNOHANG) == 0 {
                        kill(pid, SIGKILL)
                        waitpid(pid, &lateStatus, 0)
                    }
                }
            }
        }

        onExit()
    }
}
#endif
