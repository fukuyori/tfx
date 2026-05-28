#if os(macOS)
import Foundation
import Testing
@testable import tfx

@Suite("AppLaunchConfiguration")
struct AppLaunchConfigurationTests {
    @Test
    func parsesTerminalAndOpenWithConfiguration() throws {
        let configuration = try AppLaunchConfigurationLoader.parse("""
        version = 1

        [terminal]
        app = "/Applications/iTerm.app"

        [openWith]
        md = "com.microsoft.VSCode"
        pdf = "/Applications/Preview.app"
        ".tar.gz" = "com.example.ArchiveApp"
        """)

        #expect(configuration.terminalApplication == .path(URL(fileURLWithPath: "/Applications/iTerm.app")))
        #expect(configuration.openWithApplications["md"] == .bundleIdentifier("com.microsoft.VSCode"))
        #expect(configuration.openWithApplications["pdf"] == .path(URL(fileURLWithPath: "/Applications/Preview.app")))
        #expect(configuration.openWithApplications["tar.gz"] == .bundleIdentifier("com.example.ArchiveApp"))
    }

    @Test
    func terminalBundleIdentifierIsUsedWhenAppIsOmitted() throws {
        let configuration = try AppLaunchConfigurationLoader.parse("""
        version = 1

        [terminal]
        bundleIdentifier = "com.googlecode.iterm2"
        """)

        #expect(configuration.terminalApplication == .bundleIdentifier("com.googlecode.iterm2"))
    }

    @Test
    func appPathTakesPrecedenceOverTerminalBundleIdentifier() throws {
        let configuration = try AppLaunchConfigurationLoader.parse("""
        version = 1

        [terminal]
        app = "/Applications/Ghostty.app"
        bundleIdentifier = "com.googlecode.iterm2"
        """)

        #expect(configuration.terminalApplication == .path(URL(fileURLWithPath: "/Applications/Ghostty.app")))
    }

    @Test
    func extensionLookupIsCaseInsensitive() throws {
        let configuration = try AppLaunchConfigurationLoader.parse("""
        version = 1

        [openWith]
        md = "com.microsoft.VSCode"
        """)

        #expect(configuration.application(forFile: URL(fileURLWithPath: "/tmp/README.MD")) == .bundleIdentifier("com.microsoft.VSCode"))
    }
}
#endif
