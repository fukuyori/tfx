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

    static let `default` = DesignFontTokens(
        uiFamily: nil,
        monoFamily: nil,
        baseSize: 13
    )

    func swiftUIFont(for role: DesignFontRole, weight: Font.Weight = .regular) -> Font {
        let size = size(for: role)
        switch familyKind(for: role) {
        case .ui:
            if let uiFamily, !uiFamily.isEmpty {
                return .custom(uiFamily, size: size).weight(weight)
            }
            return .system(size: size, weight: weight)
        case .mono:
            if let monoFamily, !monoFamily.isEmpty {
                return .custom(monoFamily, size: size).weight(weight)
            }
            return .system(size: size, weight: weight, design: .monospaced)
        }
    }

    func nsFont(for role: DesignFontRole, weight: NSFont.Weight = .regular) -> NSFont {
        let size = size(for: role)
        switch familyKind(for: role) {
        case .ui:
            if let uiFamily,
               !uiFamily.isEmpty,
               let font = NSFont(name: uiFamily, size: size) {
                return font
            }
            return .systemFont(ofSize: size, weight: weight)
        case .mono:
            if let monoFamily,
               !monoFamily.isEmpty,
               let font = NSFont(name: monoFamily, size: size) {
                return font
            }
            return .monospacedSystemFont(ofSize: size, weight: weight)
        }
    }

    private func size(for role: DesignFontRole) -> CGFloat {
        switch role {
        case .fileList, .folderTree, .previewCode, .previewText:
            return baseSize
        case .header, .paneTitle:
            return max(8, baseSize - 1)
        case .statusLine:
            return max(8, baseSize - 2)
        case .title:
            return baseSize + 2
        case .caption:
            return max(8, baseSize - 2)
        }
    }

    private func familyKind(for role: DesignFontRole) -> DesignFontFamilyKind {
        switch role {
        case .fileList, .statusLine, .previewCode:
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
