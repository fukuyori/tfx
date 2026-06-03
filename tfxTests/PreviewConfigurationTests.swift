#if os(macOS)
import Foundation
import Testing
@testable import tfx

@Suite("PreviewConfiguration", .serialized)
struct PreviewConfigurationTests {
    @Test
    func parsesPreviewDefaultsAndExtensionModes() throws {
        let configuration = try PreviewConfigurationLoader.parse("""
        version = 1

        [preview]
        default = "auto"

        [preview.extensions]
        md = "rendered"
        log = "text"
        zip = "none"
        "tar.gz" = "none"

        [preview.markdown]
        externalImages = "button"
        """)

        #expect(configuration.defaultMode == .auto)
        #expect(configuration.extensionModes["md"] == .rendered)
        #expect(configuration.extensionModes["log"] == .text)
        #expect(configuration.extensionModes["zip"] == PreviewConfiguration.Mode.none)
        #expect(configuration.extensionModes["tar.gz"] == PreviewConfiguration.Mode.none)
        #expect(configuration.markdownExternalImages == .button)
    }

    @Test
    func modeForURLUsesExtensionOverrideBeforeDefault() throws {
        let configuration = try PreviewConfigurationLoader.parse("""
        version = 1

        [preview]
        default = "text"

        [preview.extensions]
        md = "rendered"
        """)

        #expect(configuration.mode(for: URL(fileURLWithPath: "/tmp/readme.md")) == .rendered)
        #expect(configuration.mode(for: URL(fileURLWithPath: "/tmp/notes.txt")) == .text)
    }

    @Test
    func modeForURLSupportsCompoundExtensionOverrides() throws {
        let configuration = try PreviewConfigurationLoader.parse("""
        version = 1

        [preview]
        default = "auto"

        [preview.extensions]
        gz = "text"
        "tar.gz" = "none"
        """)

        #expect(configuration.mode(for: URL(fileURLWithPath: "/tmp/archive.tar.gz")) == PreviewConfiguration.Mode.none)
        #expect(configuration.mode(for: URL(fileURLWithPath: "/tmp/log.gz")) == .text)
    }

    @Test
    func renderedModeStillSupportsRawSourceToggle() {
        let markdownURL = URL(fileURLWithPath: "/tmp/readme.md")

        #expect(PreviewPane.supportsRawSourceToggle(markdownURL, mode: .rendered))
        #expect(!PreviewPane.supportsRawSourceToggle(markdownURL, mode: .text))
        #expect(!PreviewPane.supportsRawSourceToggle(markdownURL, mode: PreviewConfiguration.Mode.none))
    }

    @Test
    func autoModeUsesRenderedPreviewUntilSourceToggleIsEnabled() {
        #expect(PreviewPane.previewDisplay(mode: .auto, showsRawSource: false, supportsRawSourceToggle: true) == .rendered)
        #expect(PreviewPane.previewDisplay(mode: .auto, showsRawSource: true, supportsRawSourceToggle: true) == .rawSource)
        #expect(PreviewPane.previewDisplay(mode: .rendered, showsRawSource: false, supportsRawSourceToggle: true) == .rendered)
        #expect(PreviewPane.previewDisplay(mode: .text, showsRawSource: false, supportsRawSourceToggle: false) == .rawSource)
        #expect(PreviewPane.previewDisplay(mode: PreviewConfiguration.Mode.none, showsRawSource: true, supportsRawSourceToggle: true) == .noPreview)
    }

    @Test
    func invalidPreviewModeThrows() {
        #expect(throws: PreviewConfigurationError.self) {
            _ = try PreviewConfigurationLoader.parse("""
            version = 1

            [preview.extensions]
            md = "fancy"
            """)
        }
    }

    @Test
    func invalidExternalImagePolicyThrows() {
        #expect(throws: PreviewConfigurationError.self) {
            _ = try PreviewConfigurationLoader.parse("""
            version = 1

            [preview.markdown]
            externalImages = "remote"
            """)
        }
    }
}
#endif
