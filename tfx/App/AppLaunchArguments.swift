#if os(macOS)
import Foundation

enum AppLaunchArguments {
    /// X11-style window geometry: optional WxH, optional +X+Y (or
    /// -X / -Y to anchor the offset to the right / bottom edge of
    /// the screen).
    struct Geometry: Equatable {
        var width: CGFloat?
        var height: CGFloat?
        /// `nil` = unset. Otherwise: positive = offset from
        /// left/top of visible screen frame; negative = offset
        /// from right/bottom edge (X11 convention).
        var offsetX: CGFloat?
        var offsetY: CGFloat?
        /// True if X was written with a leading minus sign in
        /// the original geometry string (so a value of 0 still
        /// means "anchor to right edge"). Same for Y / bottom.
        var anchorRight: Bool = false
        var anchorBottom: Bool = false
    }

    struct Parsed: Equatable {
        var initialDirectory: URL?
        var startupLayout: StartupLayoutMode?
        var previewVisible: Bool?
        var terminalVisible: Bool?
        var geometry: Geometry?
        var shouldPrintHelp = false
        var shouldPrintVersion = false
    }

    static func parse(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath
    ) -> Parsed {
        var parsed = Parsed()

        let rest = Array(arguments.dropFirst())
        var index = 0
        while index < rest.count {
            let argument = rest[index]
            switch argument {
            case "--help", "-h":
                parsed.shouldPrintHelp = true
            case "--version", "-v":
                parsed.shouldPrintVersion = true
            case "--single", "-1":
                parsed.startupLayout = .single
            case "--split", "-2":
                parsed.startupLayout = .split
            case "--restore", "-r":
                parsed.startupLayout = .restore
            case "--preview", "-p":
                parsed.previewVisible = true
            case "--no-preview", "-P":
                parsed.previewVisible = false
            case "--terminal", "-t":
                parsed.terminalVisible = true
            case "--no-terminal", "-T":
                parsed.terminalVisible = false
            case "--geometry", "-g":
                // Geometry spec is the following argument.
                if index + 1 < rest.count,
                   let geometry = parseGeometry(rest[index + 1]) {
                    parsed.geometry = geometry
                    index += 1
                }
            default:
                // Inline form: --geometry=WxH+X+Y or -g=...
                if argument.hasPrefix("--geometry=") {
                    let raw = String(argument.dropFirst("--geometry=".count))
                    if let geometry = parseGeometry(raw) {
                        parsed.geometry = geometry
                    }
                } else if argument.hasPrefix("-g=") {
                    let raw = String(argument.dropFirst("-g=".count))
                    if let geometry = parseGeometry(raw) {
                        parsed.geometry = geometry
                    }
                } else if parsed.initialDirectory == nil {
                    parsed.initialDirectory = directoryURL(for: argument, currentDirectoryPath: currentDirectoryPath)
                }
            }
            index += 1
        }

        return parsed
    }

    /// Parse an X11-style geometry string. Accepted forms:
    ///   - `WxH`         (size only)
    ///   - `+X+Y`        (offset only, top-left origin)
    ///   - `-X-Y`        (offset only, anchored bottom-right)
    ///   - `WxH+X+Y`     (size + offset; X/Y signs independent)
    ///   - `WxH-X+Y` etc. (any sign combination on X/Y)
    /// Returns `nil` if the string can't be parsed at all (e.g.
    /// the user typed garbage).
    static func parseGeometry(_ raw: String) -> Geometry? {
        guard !raw.isEmpty else { return nil }
        var geometry = Geometry()

        var rest = raw
        // Size first if it's there. Look for 'x' that doesn't
        // come AFTER a sign character — once we hit +/-, we're
        // in the offset portion.
        var sizeEnd = rest.startIndex
        while sizeEnd < rest.endIndex {
            let c = rest[sizeEnd]
            if c == "+" || c == "-" { break }
            sizeEnd = rest.index(after: sizeEnd)
        }
        let sizePart = String(rest[..<sizeEnd])
        let offsetPart = String(rest[sizeEnd...])

        if !sizePart.isEmpty {
            let dims = sizePart.split(separator: "x", omittingEmptySubsequences: false)
            // Allow empty width or height: e.g. "x800" = height
            // only; "1200x" = width only.
            if dims.count == 2 {
                if !dims[0].isEmpty, let w = Double(dims[0]) { geometry.width = CGFloat(w) }
                if !dims[1].isEmpty, let h = Double(dims[1]) { geometry.height = CGFloat(h) }
            } else if dims.count == 1, !dims[0].isEmpty, let w = Double(dims[0]) {
                geometry.width = CGFloat(w)
            }
        }

        // Offset: walk through the remaining +X+Y / -X-Y blocks.
        // The first sign is for X; the second (if present) is
        // for Y.
        var parsedX = false
        var i = offsetPart.startIndex
        while i < offsetPart.endIndex {
            let sign = offsetPart[i]
            guard sign == "+" || sign == "-" else { break }
            let valueStart = offsetPart.index(after: i)
            var valueEnd = valueStart
            while valueEnd < offsetPart.endIndex,
                  offsetPart[valueEnd] != "+",
                  offsetPart[valueEnd] != "-" {
                valueEnd = offsetPart.index(after: valueEnd)
            }
            let valueString = String(offsetPart[valueStart..<valueEnd])
            if let v = Double(valueString) {
                if !parsedX {
                    geometry.offsetX = CGFloat(v)
                    geometry.anchorRight = (sign == "-")
                    parsedX = true
                } else {
                    geometry.offsetY = CGFloat(v)
                    geometry.anchorBottom = (sign == "-")
                    break
                }
            }
            i = valueEnd
        }

        // Reject pure noise: nothing recognized at all.
        if geometry.width == nil, geometry.height == nil,
           geometry.offsetX == nil, geometry.offsetY == nil {
            return nil
        }
        return geometry
    }

    static func initialDirectory(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath
    ) -> URL? {
        parse(arguments: arguments, currentDirectoryPath: currentDirectoryPath).initialDirectory
    }

    static func versionString(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?) where !version.isEmpty && !build.isEmpty:
            return "tfx \(version) (\(build))"
        case let (version?, _) where !version.isEmpty:
            return "tfx \(version)"
        default:
            return "tfx"
        }
    }

    static let helpText = """
    Usage: tfx [options] [folder]

    Options:
      -h, --help          Show this help and exit.
      -v, --version       Show the app version and exit.
      -1, --single        Start with a single file pane.
      -2, --split         Start with split file panes.
      -r, --restore       Restore the previous pane layout and tabs.
      -p, --preview       Show the preview pane.
      -P, --no-preview    Hide the preview pane.
      -t, --terminal      Show the built-in terminal pane.
      -T, --no-terminal   Hide the built-in terminal pane.
      -g, --geometry SPEC
                          Set initial window geometry, X11 style
                          (e.g. 1200x800+100+50, or -10-10 to
                          anchor 10pt from right/bottom). Each
                          dimension is optional.

    folder may be an absolute path, a relative path, or a path beginning with ~.
    """

    private static func resolvedPath(for rawPath: String, currentDirectoryPath: String) -> String {
        let expandedPath = (rawPath as NSString).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return expandedPath
        }

        return URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(expandedPath)
            .path
    }

    private static func directoryURL(for rawPath: String, currentDirectoryPath: String) -> URL? {
        guard !rawPath.isEmpty, !rawPath.hasPrefix("-") else {
            return nil
        }

        let path = resolvedPath(for: rawPath, currentDirectoryPath: currentDirectoryPath)
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        return url
    }
}
#endif
