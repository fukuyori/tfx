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

        [startup]
        layout = "split"
        rightFolder = "~/Downloads"
        rightFolders = ["~/Downloads", "~/Documents"]

        [terminal]
        app = "/Applications/iTerm.app"

        [openWith]
        md = "com.microsoft.VSCode"
        pdf = "/Applications/Preview.app"
        ".tar.gz" = "com.example.ArchiveApp"
        """)

        #expect(configuration.startupLayout == .split)
        #expect(configuration.startupRightFolder?.path == NSString(string: "~/Downloads").expandingTildeInPath)
        #expect(configuration.startupRightFolders.map(\.path) == [
            NSString(string: "~/Downloads").expandingTildeInPath,
            NSString(string: "~/Documents").expandingTildeInPath,
        ])
        #expect(configuration.startupRightFolderURLs.map(\.path) == configuration.startupRightFolders.map(\.path))
        #expect(configuration.terminalApplication == .path(URL(fileURLWithPath: "/Applications/iTerm.app")))
        #expect(configuration.openWithApplications["md"] == .bundleIdentifier("com.microsoft.VSCode"))
        #expect(configuration.openWithApplications["pdf"] == .path(URL(fileURLWithPath: "/Applications/Preview.app")))
        #expect(configuration.openWithApplications["tar.gz"] == .bundleIdentifier("com.example.ArchiveApp"))
    }

    @Test
    func parsesStartupRestoreLayout() throws {
        let configuration = try AppLaunchConfigurationLoader.parse("""
        version = 1

        [startup]
        layout = "restore"
        """)

        #expect(configuration.startupLayout == .restore)
    }

    @Test
    func configuredStartupDirectoryKeepsProtectedUserFolder() {
        let downloads = URL(fileURLWithPath: NSString(string: "~/Downloads").expandingTildeInPath)
            .standardizedFileURL

        #expect(TerminalFileManagerView.startupDirectory(downloads) == downloads)
    }

    @Test
    func configuredStartupTabsKeepMultipleProtectedUserFolders() throws {
        let folders = ["~/Downloads", "~/Documents"].map {
            URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath).standardizedFileURL
        }
        let tabs = try #require(TerminalFileManagerView.startupTabs(folders))

        #expect(tabs.tabs.map(\.directory) == folders)
        #expect(tabs.activeDirectory == folders[0])
    }

    @Test
    func rejectsInvalidStartupLayout() {
        #expect(throws: AppLaunchConfigurationError.self) {
            _ = try AppLaunchConfigurationLoader.parse("""
            version = 1

            [startup]
            layout = "previous"
            """)
        }
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
