#if os(macOS)
import Foundation

extension FileBrowserModel {
    /// Replace the current directory watcher with one targeting `url`.
    ///
    /// Wired up from `init` through a Combine subscription on
    /// `$currentDirectory`, so this runs once at startup and again on every
    /// navigation. Zip-archive virtual paths and missing directories are
    /// skipped because there is nothing meaningful to watch.
    func startWatchingDirectory(_ url: URL) {
        directoryWatcher?.stop()
        directoryWatcher = nil

        guard ZipArchiveBrowser.location(for: url) == nil else { return }

        // `DispatchSource.makeFileSystemObjectSource` only receives events
        // for local file systems — the kernel does not get notifications
        // from remote SMB / AFP / NFS servers. Skipping the watcher on
        // network volumes avoids holding an open file descriptor that
        // never fires, and makes the behavior explicit. Users on network
        // shares still refresh through `⌘R` or any post-operation reload.
        if let values = try? url.resourceValues(forKeys: [.volumeIsLocalKey]),
           values.volumeIsLocal == false {
            return
        }

        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            return
        }

        let watcher = DirectoryWatcher(url: url) { [weak self] in
            self?.handleExternalDirectoryChange()
        }
        watcher.start()
        directoryWatcher = watcher
    }

    /// Reload triggered by an external file-system change.
    ///
    /// The watcher already debounces by ~250ms, and `reload()` cancels any
    /// in-flight load before starting a fresh one, so this is safe to call
    /// even when tfx itself triggered the change.
    private func handleExternalDirectoryChange() {
        reload()
    }
}

#endif
