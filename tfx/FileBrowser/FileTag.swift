#if os(macOS)
import AppKit
import SwiftUI

/// A single Finder-compatible color tag.
///
/// macOS stores tags as strings of the form `"<name>"` (uncolored) or
/// `"<name>\n<colorID>"` (with color). Color IDs map to the legacy file
/// label palette exposed by `NSWorkspace.shared.fileLabelColors`, which
/// Finder also uses for the colored dots in its file list and sidebar.
struct FileTag: Equatable, Hashable {
    let name: String
    let colorID: Int?

    init(name: String, colorID: Int? = nil) {
        self.name = name
        self.colorID = colorID
    }

    init(rawTagName: String) {
        let components = rawTagName.split(
            separator: "\n",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        if components.count == 2, let id = Int(components[1]) {
            self.name = String(components[0])
            self.colorID = id
        } else {
            // `URLResourceKey.tagNamesKey` sometimes returns the bare name
            // for the seven built-in system tags (Red, Blue, …) without the
            // `\n<colorID>` suffix that custom / renamed tags carry. Look
            // the name up in `NSWorkspace.shared.fileLabels`, which is the
            // localized array of system label names — that maps "Red",
            // "レッド", and any other locale's translation back to the same
            // color index Finder uses.
            self.name = rawTagName
            self.colorID = Self.systemLabelColorMap[rawTagName]
        }
    }

    /// Localized system-label name → color ID, built once from
    /// `NSWorkspace.shared.fileLabels`. Index 0 is "no color" and is
    /// excluded so an unmatched lookup correctly returns nil.
    private static let systemLabelColorMap: [String: Int] = {
        var map: [String: Int] = [:]
        let labels = NSWorkspace.shared.fileLabels
        for (index, label) in labels.enumerated() where index > 0 {
            map[label] = index
        }
        return map
    }()

    /// `NSColor` for the tag's color, or nil for uncolored / unknown tags.
    ///
    /// Apple's macOS tag color IDs map onto the seven standard tag colors
    /// Finder exposes in `System Settings → Tags`. The system semantic
    /// colors (`.systemRed`, `.systemGreen`, …) match Finder's vivid dot
    /// rendering much more closely than `NSWorkspace.shared.fileLabelColors`,
    /// which still returns the older pastel-tinted *label* palette.
    var nsColor: NSColor? {
        guard let colorID, colorID > 0, colorID < Self.palette.count else { return nil }
        return Self.palette[colorID]
    }

    /// Index 0 is reserved for the "no color" case so the colorID-to-NSColor
    /// lookup is a direct array access.
    private static let palette: [NSColor] = [
        .clear,         // 0: no color
        .systemGray,    // 1: Gray
        .systemGreen,   // 2: Green
        .systemPurple,  // 3: Purple
        .systemBlue,    // 4: Blue
        .systemYellow,  // 5: Yellow
        .systemRed,     // 6: Red
        .systemOrange,  // 7: Orange
    ]

    /// SwiftUI `Color` derived from `nsColor`.
    var color: Color? {
        nsColor.map { Color(nsColor: $0) }
    }

    /// A pre-built description of one of macOS's seven standard tag colors,
    /// used to render the Tags submenu in the file row context menu and as
    /// the payload of toggle actions on `FileBrowserModel`.
    struct SystemOption: Identifiable {
        let colorID: Int
        let localizedName: String
        let color: Color
        /// Pre-rendered, non-template `NSImage` of a filled circle in the
        /// tag color. SwiftUI's macOS `Menu` strips custom foreground
        /// colors from `Image(systemName:)`, so the only reliable way to
        /// show colored icons in menu items is to ship them as
        /// non-template `NSImage` instances.
        let menuIcon: NSImage

        var id: Int { colorID }
    }

    /// The seven standard tag colors in Finder's `System Settings → Tags`
    /// visual order. Names come from `NSWorkspace.shared.fileLabels` so
    /// they match the user's locale automatically.
    static let systemTagOptions: [SystemOption] = {
        let labels = NSWorkspace.shared.fileLabels
        // Finder's visual order in the Tags inspector.
        let orderedColorIDs = [6, 7, 5, 2, 4, 3, 1]
        return orderedColorIDs.compactMap { colorID -> SystemOption? in
            guard colorID < palette.count, colorID < labels.count else { return nil }
            let nsColor = palette[colorID]
            return SystemOption(
                colorID: colorID,
                localizedName: labels[colorID],
                color: Color(nsColor: nsColor),
                menuIcon: renderMenuIcon(color: nsColor)
            )
        }
    }()

    /// Render a small filled circle in `color`. Flagged as non-template so
    /// `NSMenu` does not re-tint it with the system foreground color.
    private static func renderMenuIcon(color: NSColor) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Raw `tagNames` representation for this tag. System / colored tags
    /// use the `"<name>\n<colorID>"` form; uncolored custom tags are just
    /// `"<name>"`. Matches what Finder writes back to disk.
    var rawTagString: String {
        if let colorID {
            return "\(name)\n\(colorID)"
        }
        return name
    }

    /// True when this tag is one of the seven built-in system tags with its
    /// default localized name. Renamed or no-color tags are considered
    /// custom and are surfaced separately in the Tags submenu.
    var isStandardSystemTag: Bool {
        guard let colorID, colorID > 0, colorID < Self.palette.count else { return false }
        return name == Self.systemTagName(forColorID: colorID)
    }

    /// Pre-rendered menu icon for the tag's color, or nil for uncolored
    /// custom tags (rendered without an icon).
    var menuIcon: NSImage? {
        guard let nsColor else { return nil }
        return Self.renderMenuIcon(color: nsColor)
    }

    /// Tag name to write for a given color ID, derived from the locale's
    /// system label palette. Falls back to "Tag" when the index is out of
    /// range, which should never happen for the seven supported colors.
    static func systemTagName(forColorID colorID: Int) -> String {
        let labels = NSWorkspace.shared.fileLabels
        guard colorID >= 0, colorID < labels.count else { return "Tag" }
        return labels[colorID]
    }
}

#endif
