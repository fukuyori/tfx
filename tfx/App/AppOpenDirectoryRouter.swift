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

/// Hands a folder from a `tfx` process started in the built-in
/// terminal to the tfx instance that owns that terminal, the same way
/// `open -a tfx <folder>` reuses the running app. Each tfx exports its PID to the
/// terminal shell, so the forwarding process can address exactly that
/// instance even when several tfx processes are running.
enum AppOpenDirectoryForwarding {
    nonisolated static let hostPIDEnvironmentKey = "TFX_PID"
    private static let notificationName = Notification.Name("org.spumoni.tfx.openDirectoryInHost")
    private static let pidKey = "pid"
    private static let pathKey = "path"

    /// Sends `directory` to the host tfx. Returns false when this
    /// process was not started from a live tfx terminal, so the
    /// caller can fall back to a normal launch.
    static func forwardToHost(
        _ directory: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        guard let rawPID = environment[hostPIDEnvironmentKey],
              let pid = pid_t(rawPID),
              pid != ProcessInfo.processInfo.processIdentifier,
              let host = NSRunningApplication(processIdentifier: pid),
              !host.isTerminated,
              host.bundleIdentifier == Bundle.main.bundleIdentifier else {
            return false
        }

        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: [pidKey: Int(pid), pathKey: directory.path],
            deliverImmediately: true
        )
        return true
    }

    /// Registered with `.deliverImmediately` so requests still arrive
    /// while tfx is inactive (the usual case: the user is typing in
    /// the built-in terminal of a window that is not frontmost).
    static func startListening() {
        DistributedNotificationCenter.default().addObserver(
            Listener.shared,
            selector: #selector(Listener.handle(_:)),
            name: notificationName,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    /// Distributed notifications are not authenticated: any local
    /// process can post one. Accept only requests addressed to this
    /// process that name an existing folder, so a stray or forged
    /// notification can at most navigate to a real directory — the
    /// same thing `open -a tfx <folder>` can already do.
    static func requestedDirectory(from userInfo: [AnyHashable: Any]?, ownPID: pid_t) -> URL? {
        guard let userInfo,
              userInfo[pidKey] as? Int == Int(ownPID),
              let path = userInfo[pathKey] as? String,
              path.hasPrefix("/") else {
            return nil
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }

    private final class Listener: NSObject {
        static let shared = Listener()

        @objc func handle(_ notification: Notification) {
            guard let directory = AppOpenDirectoryForwarding.requestedDirectory(
                from: notification.userInfo,
                ownPID: ProcessInfo.processInfo.processIdentifier
            ) else {
                return
            }
            // Delivered on the main thread, where the observer was
            // registered from `applicationDidFinishLaunching`.
            MainActor.assumeIsolated {
                AppOpenDirectoryRouter.shared.open([directory])
            }
        }
    }
}

@MainActor
final class AppOpenDirectoryDelegate: NSObject, NSApplicationDelegate {
    /// Take the "open documents" Apple Event (`open -a tfx <folder>`,
    /// Finder's Open With) away from NSApplication before launch
    /// finishes. Through the default path SwiftUI also handles the
    /// event and re-presents the `Window` scene, so the already-open
    /// window was animated out (shrink + fade, like minimizing to the
    /// Dock) and back in. Routing it here leaves SwiftUI behaving as
    /// for a plain launch, both when the event launches tfx and when
    /// tfx is already running.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocumentsEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
    }

    @objc private func handleOpenDocumentsEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent reply: NSAppleEventDescriptor
    ) {
        AppOpenDirectoryRouter.shared.open(Self.fileURLs(in: event))
    }

    static func fileURLs(in event: NSAppleEventDescriptor) -> [URL] {
        guard let list = event.paramDescriptor(forKeyword: keyDirectObject) else {
            return []
        }
        // A single file arrives as a bare descriptor, several as a list.
        guard list.numberOfItems > 0 else {
            return list.fileURLValue.map { [$0] } ?? []
        }
        return (1...list.numberOfItems).compactMap { list.atIndex($0)?.fileURLValue }
    }

    /// Refuse to quit silently while a file copy / move is
    /// running. `FileOperationRegistry` shows a confirmation
    /// alert and either cancels the work and waits for cleanup
    /// to finish (returning `.terminateLater` and replying
    /// later) or aborts the quit altogether.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        FileOperationRegistry.shared.handleApplicationTerminate(sender)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppOpenDirectoryForwarding.startListening()

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
