#if os(macOS)
import AppKit
import SwiftUI

/// App-wide design tokens that sit above color themes.
///
/// The color theme remains available through `theme` for the existing views.
/// Font roles live here so user configuration can later override one compact
/// `[font]` block without each view knowing the parsing or fallback rules.
struct DesignTokens {
    let theme: Theme
    let fonts: DesignFontTokens
    let opacity: DesignOpacityTokens

    static let `default` = DesignTokens(theme: .default, fonts: .default, opacity: .default)
}

struct DesignFontTokens: Equatable {
    var uiFamily: String?
    var monoFamily: String?
    var baseSize: CGFloat

    /// Per-pane overrides. Each pane's family / size, when
    /// non-nil and non-empty / non-zero, beats the global
    /// `uiFamily` / `monoFamily` / `baseSize`. Adjustments
    /// applied by role (e.g. status-line text is `base - 2pt`)
    /// are computed against the pane's effective base size, so
    /// `fileListSize = 14` makes the rows 14pt and the status
    /// line below them 12pt — relative spacing is preserved.
    var fileListFamily: String?
    var fileListSize: CGFloat?
    var folderTreeFamily: String?
    var folderTreeSize: CGFloat?
    var previewFamily: String?
    var previewSize: CGFloat?
    var terminalFamily: String?
    var terminalSize: CGFloat?

    static let `default` = DesignFontTokens(
        uiFamily: nil,
        monoFamily: nil,
        baseSize: 13,
        fileListFamily: nil,
        fileListSize: nil,
        folderTreeFamily: nil,
        folderTreeSize: nil,
        previewFamily: nil,
        previewSize: nil,
        terminalFamily: nil,
        terminalSize: nil
    )

    func swiftUIFont(for role: DesignFontRole, weight: Font.Weight = .regular) -> Font {
        let size = size(for: role)
        if let family = resolvedFamily(for: role), !family.isEmpty {
            return .custom(family, size: size).weight(weight)
        }
        switch familyKind(for: role) {
        case .ui:
            return .system(size: size, weight: weight)
        case .mono:
            return .system(size: size, weight: weight, design: .monospaced)
        }
    }

    func nsFont(for role: DesignFontRole, weight: NSFont.Weight = .regular) -> NSFont {
        let size = size(for: role)
        if let family = resolvedFamily(for: role),
           !family.isEmpty,
           let font = NSFont(name: family, size: size) {
            return font
        }
        switch familyKind(for: role) {
        case .ui:
            return .systemFont(ofSize: size, weight: weight)
        case .mono:
            return .monospacedSystemFont(ofSize: size, weight: weight)
        }
    }

    /// User-facing family name effective for `role`, accounting
    /// for the per-pane override layer. Exposed so non-SwiftUI
    /// surfaces (notably the xterm.js WebView, which has to
    /// build a CSS `font-family` string) can stay in sync with
    /// what `nsFont(for:)` actually resolved to.
    func resolvedFamily(for role: DesignFontRole) -> String? {
        if let override = paneFamilyOverride(for: pane(for: role)) {
            return override
        }
        switch familyKind(for: role) {
        case .ui: return uiFamily
        case .mono: return monoFamily
        }
    }

    private func size(for role: DesignFontRole) -> CGFloat {
        let base = paneSizeOverride(for: pane(for: role)) ?? baseSize
        switch role {
        case .fileList, .folderTree, .previewCode, .previewText, .terminal:
            return base
        case .header, .paneTitle:
            return max(8, base - 1)
        case .statusLine:
            return max(8, base - 2)
        case .title:
            return base + 2
        case .caption:
            return max(8, base - 2)
        }
    }

    private func paneFamilyOverride(for pane: DesignFontPane) -> String? {
        let candidate: String?
        switch pane {
        case .fileList: candidate = fileListFamily
        case .folderTree: candidate = folderTreeFamily
        case .preview: candidate = previewFamily
        case .terminal: candidate = terminalFamily
        case .none: candidate = nil
        }
        guard let candidate, !candidate.isEmpty else { return nil }
        return candidate
    }

    private func paneSizeOverride(for pane: DesignFontPane) -> CGFloat? {
        let candidate: CGFloat?
        switch pane {
        case .fileList: candidate = fileListSize
        case .folderTree: candidate = folderTreeSize
        case .preview: candidate = previewSize
        case .terminal: candidate = terminalSize
        case .none: candidate = nil
        }
        guard let candidate, candidate > 0 else { return nil }
        return candidate
    }

    private func pane(for role: DesignFontRole) -> DesignFontPane {
        switch role {
        case .fileList, .statusLine: return .fileList
        case .folderTree: return .folderTree
        case .previewCode, .previewText: return .preview
        case .terminal: return .terminal
        case .header, .paneTitle, .title, .caption: return .none
        }
    }

    private func familyKind(for role: DesignFontRole) -> DesignFontFamilyKind {
        switch role {
        case .fileList, .statusLine, .previewCode, .terminal:
            return .mono
        case .folderTree, .header, .paneTitle, .previewText, .title, .caption:
            return .ui
        }
    }
}

enum DesignFontRole {
    case fileList
    case folderTree
    case header
    case statusLine
    case paneTitle
    case previewCode
    case previewText
    case terminal
    case title
    case caption
}

struct DesignOpacityTokens: Equatable {
    var background: Double
    var inactivePane: Double
    var disabledItem: Double
    var headerSecondary: Double
    var selectedParentRow: Double
    var dropIndicator: Double
    var dragPreview: Double
    var dragPreviewShadow: Double
    var subtleBackground: Double

    static let `default` = DesignOpacityTokens(
        background: 1,
        inactivePane: 0.5,
        disabledItem: 0.45,
        headerSecondary: 0.75,
        selectedParentRow: 0.8,
        dropIndicator: 0.85,
        dragPreview: 0.96,
        dragPreviewShadow: 0.18,
        subtleBackground: 0.07
    )
}

private enum DesignFontFamilyKind {
    case ui
    case mono
}

/// Logical groupings used to route per-pane font / size
/// overrides. `.none` is the bucket for UI chrome (header,
/// pane title, generic captions) that isn't tied to a single
/// pane and therefore can't be tuned independently.
private enum DesignFontPane {
    case fileList
    case folderTree
    case preview
    case terminal
    case none
}

private struct DesignEnvironmentKey: EnvironmentKey {
    static let defaultValue: DesignTokens = .default
}

extension EnvironmentValues {
    var design: DesignTokens {
        get { self[DesignEnvironmentKey.self] }
        set { self[DesignEnvironmentKey.self] = newValue }
    }
}
#endif
