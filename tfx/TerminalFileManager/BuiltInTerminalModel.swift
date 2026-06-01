#if os(macOS)
import Combine
import Darwin
import Foundation

@MainActor
final class BuiltInTerminalModel: ObservableObject {
    struct OutputEvent: Equatable {
        let id: UUID
        let text: String
    }

    @Published var currentDirectory: URL
    @Published var transcript: String
    @Published var displayTranscript: String
    @Published var outputEvent: OutputEvent?
    @Published var commandText = ""
    @Published var isRunning = false
    @Published var terminalExitRequestID = UUID()

    private var shellPath: String
    private var session: PTYTerminalSession?
    private var outputDecoder = TerminalOutputDecoder()

    init(
        currentDirectory: URL = URL(fileURLWithPath: NSHomeDirectory()),
        shellPath: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    ) {
        let initialDirectory = currentDirectory.standardizedFileURL
        self.currentDirectory = initialDirectory
        self.shellPath = shellPath.isEmpty ? "/bin/zsh" : shellPath
        let initialTranscript = "tfx built-in terminal\n"
        transcript = initialTranscript
        displayTranscript = initialTranscript
        outputDecoder.reset(with: initialTranscript)
        displayTranscript = outputDecoder.renderedTextWithCursor()
    }

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
        startSessionIfNeeded()
    }

    func reportStartupError(_ message: String) {
        appendTerminalOutput("Terminal startup error: \(message)\n")
        isRunning = false
    }

    func submitCommand() {
        let command = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        commandText = ""
        guard !command.isEmpty else { return }

        if session == nil, Self.isExitCommand(command) {
            terminalExitRequestID = UUID()
            return
        }

        startSessionIfNeeded()
        updateCurrentDirectoryIfSimpleCD(command)
        session?.write(command + "\n")
    }

    func sendInterrupt() {
        startSessionIfNeeded()
        session?.write(Data([3]))
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

    func insertPaths(_ urls: [URL]) {
        let arguments = urls
            .map { Self.shellQuotedPath($0.path) }
            .joined(separator: " ")
        guard !arguments.isEmpty else { return }

        if session != nil {
            sendText(arguments + " ")
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
                        self.terminalExitRequestID = UUID()
                    }
                }
            )
            session = terminalSession
            terminalSession.start()
        } catch {
            transcript += "Failed to start terminal: \(error.localizedDescription)\n"
            outputDecoder.reset(with: transcript)
            displayTranscript = outputDecoder.renderedTextWithCursor()
            isRunning = false
        }
    }

    private func appendTerminalOutput(_ output: String) {
        outputEvent = OutputEvent(id: UUID(), text: output)
        transcript = outputDecoder.renderedText(appending: output)
        displayTranscript = outputDecoder.renderedTextWithCursor()
    }

    func resize(columns: Int, rows: Int) {
        session?.resize(columns: columns, rows: rows)
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

    mutating func renderedText(appending rawOutput: String) -> String {
        for scalar in rawOutput.unicodeScalars {
            append(scalar)
        }
        return lines.joined(separator: "\n")
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

    private func childExecuteShell(shellPath: String, shellName: String, directoryPath: String) -> Never {
        _ = chdir(directoryPath)
        setenv("TERM", "xterm-256color", 1)
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
            waitpid(pid, &status, WNOHANG)
        }

        onExit()
    }
}
#endif
