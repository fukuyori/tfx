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
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            return fileURL.standardizedFileURL
        }

        return fileURL.deletingLastPathComponent().standardizedFileURL
    }
}

@MainActor
final class AppOpenDirectoryDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        AppOpenDirectoryRouter.shared.open(urls)
    }
}
#endif
