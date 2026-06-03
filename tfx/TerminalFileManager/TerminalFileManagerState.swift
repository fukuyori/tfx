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
        activeModel.expandFolder(activeModel.currentDirectory)
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
            terminalModel.close()
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
            terminalModel.followDirectory(activeModel.currentDirectory)
            if terminalModel.activeTab == .shell {
                terminalModel.open()
                activateTerminalPane()
            }
        } else {
            terminalModel.close()
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
        guard oldValue != newValue, newValue else { return }
        let sourceModel = activeModel
        let targetModel = activePane == .left ? rightModel : leftModel
        targetModel.navigate(
            to: sourceModel.currentDirectory,
            recordsHistory: false
        )
    }

    /// Side-effect handler for `isFolderTreeVisible` changes.
    /// `MainPaneSplitView.Coordinator` owns the window
    /// `contentMinSize` and the toggle-driven resize; this handler
    /// only owns the focus fallback (arrow keys / Return must not
    /// route to an invisible pane).
    func onFolderTreeVisibilityChange(from oldValue: Bool, to newValue: Bool) {
        guard oldValue != newValue else { return }
        if !newValue, activeArea == .folderTree {
            activeArea = .files
        }
    }

    /// Side-effect handler for `isPreviewVisible` changes.
    /// `MainPaneSplitView.Coordinator` owns the window
    /// `contentMinSize` and the toggle-driven resize; this handler
    /// has nothing else to do.
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
}
#endif
