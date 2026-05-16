#if os(macOS)
import Foundation

/// Watches a single directory's file descriptor and invokes a debounced handler
/// on the main queue when the directory's contents change (file creation,
/// deletion, rename, attribute change).
///
/// Backed by `DispatchSource.makeFileSystemObjectSource`, so kernel-level
/// filtering is used rather than polling. The watcher only observes the
/// directory itself; it does not recurse into subdirectories.
///
/// External tools (Finder, the shell, other apps) that mutate the watched
/// directory will trigger the handler. tfx's own file operations will also
/// trigger it, in which case `FileBrowserModel.reload()` short-circuits the
/// duplicate work by cancelling the in-flight load and starting a new one.
final class DirectoryWatcher {
    private let url: URL
    private let debounce: DispatchTimeInterval
    private let handler: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    init(
        url: URL,
        debounce: DispatchTimeInterval = .milliseconds(250),
        handler: @escaping () -> Void
    ) {
        self.url = url
        self.debounce = debounce
        self.handler = handler
    }

    deinit {
        source?.cancel()
        pending?.cancel()
    }

    /// Begin watching. Silently no-ops when the descriptor cannot be opened
    /// (for example, when the directory was already removed).
    func start() {
        guard source == nil else { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )
        dispatchSource.setEventHandler { [weak self] in
            self?.scheduleDelivery()
        }
        dispatchSource.setCancelHandler { [fd] in
            close(fd)
        }
        dispatchSource.resume()
        source = dispatchSource
    }

    /// Stop watching. Safe to call multiple times.
    func stop() {
        source?.cancel()
        source = nil
        pending?.cancel()
        pending = nil
    }

    private func scheduleDelivery() {
        let work = DispatchWorkItem { [weak self] in
            self?.handler()
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                work.cancel()
                return
            }
            self.pending?.cancel()
            self.pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + self.debounce, execute: work)
        }
    }
}

#endif
