#if os(macOS)
import AppKit
import Combine
import Foundation

struct AppOpenDirectoryRequest: Equatable, Identifiable {
    let id = UUID()
    let directory: URL
}

@MainActor
final class AppOpenDirectoryRouter: ObservableObject {
    static let shared = AppOpenDirectoryRouter()

    @Published private(set) var request: AppOpenDirectoryRequest?

    func open(_ urls: [URL]) {
        guard let directory = urls.lazy.compactMap(Self.directoryURL(for:)).first else {
            return
        }

        request = AppOpenDirectoryRequest(directory: directory)
    }

    private static func directoryURL(for url: URL) -> URL? {
        let fileURL = url.isFileURL ? url : URL(fileURLWithPath: url.path)
        if let directoryURL = FileBrowserExternalActions.directoryURLForNavigation(fileURL) {
            return directoryURL
        }

        return fileURL.deletingLastPathComponent().standardizedFileURL
    }
}

@MainActor
final class AppOpenDirectoryDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        AppOpenDirectoryRouter.shared.open(urls)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply startup geometry once the first window has been
        // created. Precedence: command-line `--geometry` / `-g`
        // overrides `[startup] geometry = "..."` in config.toml.
        // The window is restored to normal (non-zoomed) state
        // first so the requested geometry actually takes effect
        // — a zoomed window would re-snap to the screen frame on
        // the next layout pass.
        let parsed = AppLaunchArguments.parse()
        let configGeometry = (try? AppLaunchConfigurationLoader.load())?.startupGeometry
        guard let geometry = parsed.geometry ?? configGeometry else { return }
        DispatchQueue.main.async {
            self.applyGeometry(geometry)
        }
    }

    private func applyGeometry(_ geometry: AppLaunchArguments.Geometry) {
        guard let window = NSApp.windows.first(where: { $0.contentViewController != nil || $0.contentView != nil }),
              let screen = window.screen ?? NSScreen.main else { return }
        if window.isZoomed { window.zoom(nil) }

        let screenFrame = screen.visibleFrame
        let chromeWidth = window.frame.width - window.contentLayoutRect.width
        let chromeHeight = window.frame.height - window.contentLayoutRect.height

        var width = window.frame.width
        if let w = geometry.width { width = w + chromeWidth }
        var height = window.frame.height
        if let h = geometry.height { height = h + chromeHeight }

        // Clamp to screen visible frame.
        width = min(width, screenFrame.width)
        height = min(height, screenFrame.height)

        var originX = window.frame.origin.x
        if let ox = geometry.offsetX {
            originX = geometry.anchorRight
                ? screenFrame.maxX - width - ox
                : screenFrame.minX + ox
        }
        var originY = window.frame.origin.y
        if let oy = geometry.offsetY {
            // X11 Y is measured from TOP; AppKit screen origin
            // is bottom-left. Convert: top offset oy → AppKit y
            // = screenFrame.maxY - height - oy.
            originY = geometry.anchorBottom
                ? screenFrame.minY + oy
                : screenFrame.maxY - height - oy
        }

        window.setFrame(NSRect(x: originX, y: originY, width: width, height: height),
                        display: true,
                        animate: false)
    }
}
#endif
