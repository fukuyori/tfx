#if os(macOS)
import Foundation

struct FileBrowserNavigationHistory {
    private var backStack: [URL] = []
    private var forwardStack: [URL] = []

    var canGoBack: Bool {
        !backStack.isEmpty
    }

    var canGoForward: Bool {
        !forwardStack.isEmpty
    }

    mutating func recordNavigation(from currentDirectory: URL) {
        backStack.append(currentDirectory.standardizedFileURL)
        forwardStack.removeAll()
    }

    mutating func previous(from currentDirectory: URL) -> URL? {
        guard let previous = backStack.popLast() else { return nil }
        forwardStack.append(currentDirectory.standardizedFileURL)
        return previous
    }

    mutating func next(from currentDirectory: URL) -> URL? {
        guard let next = forwardStack.popLast() else { return nil }
        backStack.append(currentDirectory.standardizedFileURL)
        return next
    }
}

#endif
