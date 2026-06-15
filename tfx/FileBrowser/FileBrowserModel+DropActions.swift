#if os(macOS)
import AppKit
import Foundation
import UniformTypeIdentifiers

extension FileBrowserModel {
    func moveDroppedFiles(
        _ providers: [NSItemProvider],
        to targetDirectory: URL,
        operation: FileClipboard.Operation,
        completion: (() -> Void)? = nil
    ) -> Bool {
        // Collect every dropped URL into a single batch, then run
        // the copy / move through the chunk-copying progress
        // runner. The pre-batch approach gives one progress card
        // covering the whole drop instead of one per item, and
        // lets Cancel actually stop the operation between files.
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else { return false }

        let total = fileProviders.count
        var collected: [URL] = []
        var completed = 0

        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    completed += 1
                    if let error {
                        self.show(error)
                    } else if let url = FileBrowserDropItemDecoder.url(from: item) {
                        collected.append(url)
                    }
                    if completed == total, !collected.isEmpty {
                        self.runBatchDrop(
                            collected,
                            to: targetDirectory,
                            operation: operation,
                            completion: completion
                        )
                    }
                }
            }
        }
        return true
    }

    /// Dispatches the batched drop through `runFileOperation`,
    /// then mirrors the bookkeeping the old per-item path used
    /// to do (item-list update, folder-children refresh,
    /// directories-changed notification with the source-side
    /// removals).
    private func runBatchDrop(
        _ sources: [URL],
        to targetDirectory: URL,
        operation: FileClipboard.Operation,
        completion: (() -> Void)?
    ) {
        // Drop-in-place is a no-op: copying a file onto the same
        // folder it already lives in would synthesize a
        // "<name> 2.ext" via the conflict resolver, and a move
        // there has no work to do. Neither matches the user
        // intent for "I let go of the drag inside the same pane".
        // Filter those rows out before kicking off the copy /
        // move pipeline so we don't show a 0-byte progress card
        // either.
        let targetStandardized = targetDirectory.standardizedFileURL
        let effectiveSources = sources.filter {
            $0.deletingLastPathComponent().standardizedFileURL != targetStandardized
        }
        guard !effectiveSources.isEmpty else {
            completion?()
            return
        }

        // Same-listing folder drop: every source AND the target
        // folder are direct children of the current file pane.
        // Confirm before running so a stray release while
        // scrolling the file list doesn't quietly relocate rows
        // into a sibling folder.
        guard confirmSameListingFolderDropIfNeeded(
            sources: effectiveSources,
            targetDirectory: targetStandardized,
            operation: operation
        ) else {
            completion?()
            return
        }

        let kind: FileOperationProgressViewModel.Kind = (operation == .copy) ? .copying : .moving
        runFileOperation(
            kind: kind,
            items: effectiveSources,
            destination: targetDirectory
        ) { [weak self] added, removed in
            guard let self else { return }
            let sourceDirectories = Set(sources.map { $0.deletingLastPathComponent().standardizedFileURL })
            for dir in sourceDirectories {
                self.refreshFolderChildren(dir)
            }
            self.refreshFolderChildren(targetDirectory)
            self.updateCurrentDirectoryItems(
                adding: added,
                removing: removed,
                selecting: added
            )
            let affectedDirectories = sourceDirectories.union([targetDirectory.standardizedFileURL])
            self.notifyDirectoriesChanged(
                Array(affectedDirectories),
                removedURLs: removed
            )
            completion?()
        }
    }

    /// Launch / spawn `executableURL`, passing every dropped
    /// file URL as an argument. `.app` bundles go through
    /// `NSWorkspace` (they get the dropped files as documents
    /// via the standard "open with" channel). Regular
    /// executables run via `Process` with `arguments` set to
    /// each dropped URL's path. Returns true when the providers
    /// included file URLs; the actual execution is asynchronous.
    @discardableResult
    func executeDroppedFiles(
        _ providers: [NSItemProvider],
        on executableURL: URL,
        isApplicationBundle: Bool
    ) -> Bool {
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else { return false }

        // Collect every dropped URL into a single batch and then
        // run the target once with all of them as arguments —
        // matching `program file1 file2 file3` semantics rather
        // than spawning N independent runs. `NSItemProvider`'s
        // loader is async so we wait for all per-provider
        // callbacks to land before dispatching the single run.
        let total = fileProviders.count
        var collected: [URL] = []
        var completed = 0

        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    completed += 1
                    if let error {
                        self.show(error)
                    } else if let url = FileBrowserDropItemDecoder.url(from: item) {
                        collected.append(url)
                    }
                    if completed == total {
                        guard !collected.isEmpty else { return }
                        self.runExecutable(
                            executableURL,
                            isApplicationBundle: isApplicationBundle,
                            with: collected
                        )
                    }
                }
            }
        }
        return true
    }

    private func runExecutable(_ executableURL: URL, isApplicationBundle: Bool, with arguments: [URL]) {
        if isApplicationBundle {
            FileBrowserExternalActions.open(arguments, withApplicationAt: executableURL) { [weak self] error in
                self?.show(error)
            }
            return
        }

        // Prefer the built-in terminal when available: TUI
        // programs (`tbla`, `vim`, `htop`, …) need a real PTY,
        // and we already own one. The handler is responsible
        // for un-hiding the terminal pane and writing the
        // command line + return into the live session.
        if let handler = runInTerminalHandler {
            handler(shellCommand(for: executableURL, arguments: arguments))
            return
        }

        // Fallback for windows that have not registered a
        // terminal handler: spawn the executable detached from
        // any PTY. Works for GUI helpers but produces unusable
        // output for TUI programs (escape codes go to stdout
        // and nothing reads them). We keep this branch so the
        // feature is still useful in setups that disable the
        // built-in terminal entirely.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments.map(\.path)
            do {
                try process.run()
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.show(error)
                }
            }
        }
    }

    /// Show the "are you sure?" alert when the user dragged
    /// rows from the file list onto a folder row in the **same**
    /// file list (both sources and target sit directly under
    /// `currentDirectory`). Returns `true` when the operation
    /// should proceed — either because the drop is between
    /// different listings (cross-pane / from outside) and needs
    /// no confirmation, or because the user clicked the action
    /// button. Returns `false` only when the user explicitly
    /// cancelled.
    @MainActor
    private func confirmSameListingFolderDropIfNeeded(
        sources: [URL],
        targetDirectory: URL,
        operation: FileClipboard.Operation
    ) -> Bool {
        let currentDir = currentDirectory.standardizedFileURL
        let targetParent = targetDirectory.deletingLastPathComponent().standardizedFileURL
        guard targetParent == currentDir else { return true }
        guard sources.allSatisfy({ $0.deletingLastPathComponent().standardizedFileURL == currentDir }) else {
            return true
        }

        let folderName = targetDirectory.lastPathComponent
        let count = sources.count

        let alert = NSAlert()
        alert.alertStyle = .warning
        let actionTitle: String
        switch operation {
        case .copy:
            actionTitle = String(localized: "Copy")
            alert.messageText = count == 1
                ? String(localized: "Copy \"\(sources[0].lastPathComponent)\" into \"\(folderName)\"?")
                : String(localized: "Copy \(count) items into \"\(folderName)\"?")
        case .move:
            actionTitle = String(localized: "Move")
            alert.messageText = count == 1
                ? String(localized: "Move \"\(sources[0].lastPathComponent)\" into \"\(folderName)\"?")
                : String(localized: "Move \(count) items into \"\(folderName)\"?")
        }
        alert.informativeText = String(localized: "Dragging within the same file list — confirm so a stray release doesn't relocate rows by mistake.")
        alert.addButton(withTitle: actionTitle)
        alert.addButton(withTitle: String(localized: "Cancel"))

        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Quote a path for safe interpolation into a single shell
    /// command line. Wraps in single quotes and escapes any
    /// embedded single quotes via the standard `'\''` sequence.
    private func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func shellCommand(for executableURL: URL, arguments: [URL]) -> String {
        let parts = [executableURL.path] + arguments.map(\.path)
        return parts.map(shellQuote).joined(separator: " ")
    }

    func drop(_ sourceURL: URL, to targetDirectory: URL, operation: FileClipboard.Operation, completion: (() -> Void)? = nil) {
        // Same drop-in-place guard as `runBatchDrop`: if the
        // dragged URL already lives in the destination folder,
        // skip the operation so we don't end up with
        // `name 2.ext` on a same-pane drag-and-release.
        let targetStandardized = targetDirectory.standardizedFileURL
        if sourceURL.deletingLastPathComponent().standardizedFileURL == targetStandardized {
            completion?()
            return
        }

        guard confirmSameListingFolderDropIfNeeded(
            sources: [sourceURL],
            targetDirectory: targetStandardized,
            operation: operation
        ) else {
            completion?()
            return
        }

        do {
            guard let result = try FileBrowserFileOperations.drop(sourceURL, to: targetDirectory, operation: operation) else { return }
            refreshFolderChildren(sourceURL.deletingLastPathComponent())
            refreshFolderChildren(targetDirectory)
            updateCurrentDirectoryItems(
                adding: [result.destinationURL],
                removing: result.removedSourceURL.map { [$0] } ?? [],
                selecting: [result.destinationURL]
            )
            // Pass `removedSourceURL` along so another pane
            // pointed at the source directory can drop the row
            // immediately on receiving the notification instead
            // of waiting for its directory-watcher reload —
            // gives the cross-pane drag the instant
            // disappear-from-source feel.
            notifyDirectoriesChanged(
                Array(result.affectedDirectories),
                removedURLs: result.removedSourceURL.map { [$0] } ?? []
            )
            completion?()
        } catch {
            show(error)
        }
    }
}

#endif
