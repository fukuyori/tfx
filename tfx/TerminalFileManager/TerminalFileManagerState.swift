#if os(macOS)
import AppKit
import Foundation

extension TerminalFileManagerView {
    var activePane: BrowserPaneID {
        get {
            BrowserPaneID(rawValue: activePaneRawValue) ?? .left
        }
        nonmutating set {
            activePaneRawValue = newValue.rawValue
        }
    }

    var activeArea: ActiveArea {
        get {
            ActiveArea(rawValue: activeAreaRawValue) ?? .files
        }
        nonmutating set {
            activeAreaRawValue = newValue.rawValue
        }
    }

    var activeModel: FileBrowserModel {
        activePane == .left ? leftModel : rightModel
    }

    var model: FileBrowserModel {
        activeModel
    }

    static func restoredDirectory(forKey key: String, fallback: URL) -> URL {
        guard let path = UserDefaults.standard.string(forKey: key), !path.isEmpty else {
            return fallback
        }

        let url = URL(fileURLWithPath: path)
        if let safeParent = safeRestorationParent(forPrivacyProtectedUserDirectory: url) {
            return safeParent
        }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return url
        }

        return fallback
    }

    private static func safeRestorationParent(forPrivacyProtectedUserDirectory url: URL) -> URL? {
        guard let protectedDirectory = PrivacyProtectedDirectories.enclosingProtectedDirectory(for: url) else {
            return nil
        }
        return protectedDirectory.deletingLastPathComponent().standardizedFileURL
    }

    func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Self.clampedDouble(value, min: minValue, max: maxValue)
    }

    static func clampedDouble(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.min(Swift.max(value, minValue), maxValue)
    }

    func reloadAllPanes() {
        leftModel.reload()
        rightModel.reload()
        // Expand only — each `reload()` seeds its own folder-tree
        // cache from the listing it just read, so an extra
        // `loadChildren` enumeration here would be redundant.
        activeModel.markFolderExpanded(activeModel.currentDirectory)
    }

    func setSplitViewVisible(_ isVisible: Bool) {
        guard isSplitViewVisible != isVisible else { return }
        isSplitViewVisible = isVisible
        // The directory-sync side effect now lives in `onSplitViewVisibilityChange`
        // so the same behavior runs whether the flag is flipped from the toolbar,
        // the View menu, or a keyboard shortcut.
    }

    func setTerminalPaneVisible(_ isVisible: Bool, focus: Bool = false) {
        let wasVisible = isTerminalPaneVisible
        isTerminalPaneVisible = isVisible
        guard isVisible else {
            // Hiding the pane no longer terminates the shell.
            // The PTY session keeps running in the background so
            // re-opening the pane shows the same shell with its
            // history, environment, and any long-running output
            // intact. The only paths that actually tear down the
            // session are the user typing `exit` / `logout` in
            // the shell (handled by the natural PTY exit →
            // `terminalExitRequestID` flow that just hides the
            // pane on top of an already-dead session) and the
            // app quitting (`BuiltInTerminalModel.deinit`).
            deactivateTerminalPaneIfNeeded()
            return
        }
        if !wasVisible {
            terminalModel.followDirectory(activeModel.currentDirectory)
        }
        if focus {
            activateTerminalPane()
        }
    }

    func toggleTerminalPane(focus: Bool = true) {
        setTerminalPaneVisible(!isTerminalPaneVisible, focus: focus)
    }

    func focusTerminalPane() {
        setTerminalPaneVisible(true, focus: true)
    }

    /// Move keyboard focus to the active file pane (left or
    /// right). Restores `.files` as the active area so arrow
    /// keys, return, and the configured shortcuts operate on
    /// the file list — useful after focus drifted into the
    /// search field, folder tree, or terminal.
    func focusFilePane() {
        activeArea = .files
        activeModel.ensureFileSelection()
        isSearchFocused = false
        isTerminalInputFocused = false
    }

    func executeUserCommand(_ command: UserCommand, selection: [FileItem], in model: FileBrowserModel) {
        if command.terminal {
            terminalModel.showOutput()
            isTerminalPaneVisible = true
        }

        UserCommandRunner.execute(
            command,
            selection: selection,
            currentDirectory: model.currentDirectory,
            terminalModel: command.terminal ? terminalModel : nil,
            onError: { error in
                model.show(error)
            }
        )
    }

    func onTerminalPaneVisibilityChange(isVisible: Bool) {
        if isVisible {
            // `followDirectory` early-returns once a session
            // exists, so re-opening the pane onto a still-alive
            // shell does not yank its CWD around — the shell
            // keeps wherever the user left it. The cwd sync
            // therefore only applies the very first time the
            // pane comes up after `exit` / app launch.
            terminalModel.followDirectory(activeModel.currentDirectory)
            if terminalModel.activeTab == .shell {
                // `open()` → `startSessionIfNeeded()` is a
                // no-op when the PTY is already running, so this
                // just refreshes the shell tab without spawning
                // a new session.
                terminalModel.open()
                activateTerminalPane()
            }
        } else {
            // Mirrors `setTerminalPaneVisible(false)`: hiding
            // the pane keeps the shell session alive in the
            // background.
            deactivateTerminalPaneIfNeeded()
        }
    }

    func activateTerminalPane() {
        terminalModel.open()
        activeArea = .terminal
        DispatchQueue.main.async {
            isTerminalInputFocused = true
        }
    }

    func deactivateTerminalPaneIfNeeded() {
        isTerminalInputFocused = false
        if activeArea == .terminal {
            activeArea = .files
        }
    }

    func refocusTerminalInputAfterCommandIfNeeded(isRunning: Bool) {
        guard !isRunning, isTerminalPaneVisible, activeArea == .terminal else { return }
        DispatchQueue.main.async {
            isTerminalInputFocused = true
        }
    }

    func closeTerminalPaneFromExitCommand() {
        setTerminalPaneVisible(false, focus: false)
    }

    /// Side-effect handler for `isSplitViewVisible` changes.
    /// `MainPaneSplitView.Coordinator` re-renders on this AppStorage
    /// flip (via its bound input) and refreshes
    /// `NSWindow.contentMinSize` itself; this handler only owns the
    /// directory-sync side effect that pulls the other pane onto
    /// the active directory when split first turns on.
    func onSplitViewVisibilityChange(from oldValue: Bool, to newValue: Bool) {
        guard oldValue != newValue else { return }
        if newValue {
            fileSplitRatio = 0.5
            fileSplitDragStart = nil
        } else {
            fileSplitDragStart = nil
            return
        }
        let sourceModel = activeModel
        let targetModel = activePane == .left ? rightModel : leftModel
        targetModel.navigate(
            to: sourceModel.currentDirectory,
            recordsHistory: false
        )
    }

    /// Side-effect handler for `isFolderTreeVisible` changes.
    /// `MainPaneSplitView.Coordinator` owns the window
    /// `contentMinSize` and pane reallocation; this handler only
    /// owns the focus fallback (arrow keys / Return must not route
    /// to an invisible pane).
    func onFolderTreeVisibilityChange(from oldValue: Bool, to newValue: Bool) {
        guard oldValue != newValue else { return }
        if !newValue, activeArea == .folderTree {
            activeArea = .files
        }
    }

    /// Side-effect handler for `isPreviewVisible` changes.
    /// `MainPaneSplitView.Coordinator` owns the window
    /// `contentMinSize` and pane reallocation; this handler has
    /// nothing else to do.
    func onPreviewVisibilityChange(from oldValue: Bool, to newValue: Bool) {
        _ = (oldValue, newValue)
    }

    /// Swap the left and right pane directories. No-op when split is off or
    /// both panes are already on the same directory. Navigation records
    /// history on both sides so `Cmd+[` rolls back the swap.
    func swapPanes() {
        guard isSplitViewVisible else { return }
        let leftDirectory = leftModel.currentDirectory
        let rightDirectory = rightModel.currentDirectory
        guard leftDirectory.standardizedFileURL != rightDirectory.standardizedFileURL else { return }
        leftModel.navigate(to: rightDirectory)
        rightModel.navigate(to: leftDirectory)
    }
}

extension Notification.Name {
    /// Posted by `ViewMenuCommands` to request a left ⇄ right pane swap.
    /// Observed by `TerminalFileManagerView`.
    static let terminalFileManagerSwapPanes = Notification.Name("TerminalFileManager.swapPanes")
    static let terminalFileManagerNewTab = Notification.Name("TerminalFileManager.newTab")
    static let terminalFileManagerCloseTab = Notification.Name("TerminalFileManager.closeTab")
    static let terminalFileManagerPreviousTab = Notification.Name("TerminalFileManager.previousTab")
    static let terminalFileManagerNextTab = Notification.Name("TerminalFileManager.nextTab")
    static let terminalFileManagerToggleTerminalPane = Notification.Name("TerminalFileManager.toggleTerminalPane")
    static let terminalFileManagerFocusTerminalPane = Notification.Name("TerminalFileManager.focusTerminalPane")
    static let terminalFileManagerFocusFilePane = Notification.Name("TerminalFileManager.focusFilePane")
}
#endif
