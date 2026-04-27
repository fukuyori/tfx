#if os(macOS)
import Foundation

enum FileBrowserDropTargetState {
    static func isTarget(_ highlightedDirectory: URL?, matching url: URL) -> Bool {
        highlightedDirectory?.standardizedFileURL == url.standardizedFileURL
    }

    static func setting(_ url: URL?, current: URL?) -> URL? {
        let target = url?.standardizedFileURL
        return current == target ? current : target
    }

    static func clearing(_ url: URL?, current: URL?) -> URL? {
        guard let url else { return nil }
        return current?.standardizedFileURL == url.standardizedFileURL ? nil : current
    }
}

#endif
