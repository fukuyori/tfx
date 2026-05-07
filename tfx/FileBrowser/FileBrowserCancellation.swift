#if os(macOS)
import Foundation

final class DirectoryLoadCancellation {
    private let lock = NSLock()
    private var isCancelledStorage = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelledStorage
    }

    func cancel() {
        lock.lock()
        isCancelledStorage = true
        lock.unlock()
    }
}

final class PreviewLoadCancellation {
    private let lock = NSLock()
    private var isCancelledStorage = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelledStorage
    }

    func cancel() {
        lock.lock()
        isCancelledStorage = true
        lock.unlock()
    }
}

final class FilterSortCancellation: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var isCancelledStorage = false

    nonisolated var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelledStorage
    }

    nonisolated func cancel() {
        lock.lock()
        isCancelledStorage = true
        lock.unlock()
    }
}

final class MetadataPrefetchCancellation: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var isCancelledStorage = false

    nonisolated var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelledStorage
    }

    nonisolated func cancel() {
        lock.lock()
        isCancelledStorage = true
        lock.unlock()
    }
}

final class SubfolderSearchCancellation: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var isCancelledStorage = false

    nonisolated var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelledStorage
    }

    nonisolated func cancel() {
        lock.lock()
        isCancelledStorage = true
        lock.unlock()
    }
}
#endif
