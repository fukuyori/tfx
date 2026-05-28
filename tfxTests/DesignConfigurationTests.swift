#if os(macOS)
import CoreGraphics
import SwiftUI
import Testing
@testable import tfx

@Suite("DesignConfiguration")
struct DesignConfigurationTests {
    @Test
    func parsesFontBlock() throws {
        let configuration = try DesignConfigurationLoader.parse("""
        version = 1

        [font]
        ui = "Hiragino Sans"
        mono = "JetBrains Mono"
        size = 14
        """)

        #expect(configuration.fonts.uiFamily == "Hiragino Sans")
        #expect(configuration.fonts.monoFamily == "JetBrains Mono")
        #expect(configuration.fonts.baseSize == 14)
    }

    @Test
    func systemFontAliasesUseDefaults() throws {
        let configuration = try DesignConfigurationLoader.parse("""
        version = 1

        [font]
        ui = "system"
        mono = "monospace"
        size = 13
        """)

        #expect(configuration.fonts.uiFamily == nil)
        #expect(configuration.fonts.monoFamily == nil)
        #expect(configuration.fonts.baseSize == 13)
    }

    @Test
    func ignoresCommentsOutsideStrings() throws {
        let configuration = try DesignConfigurationLoader.parse("""
        version = 1

        [font]
        ui = "Name # With Hash" # comment
        mono = "monospace"
        size = 12 # comment
        """)

        #expect(configuration.fonts.uiFamily == "Name # With Hash")
        #expect(configuration.fonts.baseSize == 12)
    }

    @Test
    func parsesColorOverrides() throws {
        let configuration = try DesignConfigurationLoader.parse("""
        version = 1

        [colors]
        fileListBackground = "#112233"
        directoryForeground = "#AABBCC"
        gitDeleted = "#FF0000"
        """)

        #expect(configuration.theme.fileListBackground == Color(red: 0x11 / 255.0, green: 0x22 / 255.0, blue: 0x33 / 255.0))
        #expect(configuration.theme.directoryForeground == Color(red: 0xaa / 255.0, green: 0xbb / 255.0, blue: 0xcc / 255.0))
        #expect(configuration.theme.gitDeleted == Color(red: 1, green: 0, blue: 0))
        #expect(configuration.theme.fileForeground == Theme.default.fileForeground)
    }

    @Test
    func parsesOpacityOverrides() throws {
        let configuration = try DesignConfigurationLoader.parse("""
        version = 1

        [opacity]
        background = 0.88
        inactivePane = 0.62
        disabledItem = 0.31
        dragPreviewShadow = 0.22
        """)

        #expect(configuration.opacity.background == 0.88)
        #expect(configuration.opacity.inactivePane == 0.62)
        #expect(configuration.opacity.disabledItem == 0.31)
        #expect(configuration.opacity.dragPreviewShadow == 0.22)
        #expect(configuration.opacity.headerSecondary == DesignOpacityTokens.default.headerSecondary)
    }

    @Test
    func rejectsUnsupportedVersion() {
        #expect(throws: DesignConfigurationError.self) {
            _ = try DesignConfigurationLoader.parse("version = 2")
        }
    }

    @Test
    func rejectsOutOfRangeFontSize() {
        #expect(throws: DesignConfigurationError.self) {
            _ = try DesignConfigurationLoader.parse("""
            version = 1

            [font]
            size = 4
            """)
        }
    }

    @Test
    func rejectsInvalidColor() {
        #expect(throws: DesignConfigurationError.self) {
            _ = try DesignConfigurationLoader.parse("""
            version = 1

            [colors]
            fileForeground = "green"
            """)
        }
    }

    @Test
    func rejectsOutOfRangeOpacity() {
        #expect(throws: DesignConfigurationError.self) {
            _ = try DesignConfigurationLoader.parse("""
            version = 1

            [opacity]
            inactivePane = 1.2
            """)
        }
    }
}
#endif
