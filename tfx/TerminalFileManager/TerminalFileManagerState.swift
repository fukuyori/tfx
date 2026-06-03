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

    /// Side-effect handler for `isSplitViewVisible` changes. Invoked from
    /// `.onChange` in the view body so toolbar, menu, and shortcut paths all
    /// converge here.
    func onSplitViewVisibilityChange(from oldValue: Bool, to newValue: Bool) {
        guard oldValue != newValue else { return }
        applyWindowContentMinSize()
        guard newValue else { return }

        // Activating split — bring the other pane onto the same directory.
        let sourceModel = activeModel
        let targetModel = activePane == .left ? rightModel : leftModel
        targetModel.navigate(
            to: sourceModel.currentDirectory,
            recordsHistory: false
        )
    }

    /// Keep the file area from shrinking when the preview pane is shown by
    /// expanding the window width only. The origin is intentionally preserved
    /// so toggling preview never moves the window.
    func onPreviewVisibilityChange(from oldValue: Bool, to newValue: Bool) {
        guard oldValue != newValue else { return }
        applyWindowContentMinSize()
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }

        if newValue {
            previewAutoResizeDelta = growWindowForPreview(window)
        } else {
            shrinkWindowAfterPreview(window)
            previewAutoResizeDelta = 0
        }
    }

    /// Push the layout's dynamic minimum content width into AppKit so
    /// the user cannot drag the window narrower than the current
    /// `isSplitViewVisible` / `isPreviewVisible` configuration can
    /// honor. Deferred to the next runloop tick because mutating
    /// `NSWindow.contentMinSize` (or `setFrame` after growth) from
    /// inside SwiftUI's body / `.onChange` reentrantly triggers
    /// AppKit's layout pipeline and trips
    /// `_NSDetectedLayoutRecursion`.
    func applyWindowContentMinSize() {
        let isSplit = isSplitViewVisible
        let isPreview = isPreviewVisible

        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }

            let minWidth = TerminalFileManagerLayout.minimumWindowWidth(
                isSplitViewVisible: isSplit,
                isPreviewVisible: isPreview
            )
            let minHeight = TerminalFileManagerLayout.minimumWindowHeight
            window.contentMinSize = NSSize(width: minWidth, height: minHeight)

            // Grow the window if its current width is below the new
            // minimum (e.g. the user toggled split on while the window
            // was sitting at the single-pane minimum). Leave the
            // origin alone so the window doesn't visually leap.
            if window.frame.width < minWidth {
                var frame = window.frame
                frame.size.width = minWidth
                window.setFrame(frame, display: true, animate: false)
            }
        }
    }

    private func growWindowForPreview(_ window: NSWindow) -> CGFloat {
        let currentFrame = window.frame
        let contentWidth = window.contentLayoutRect.width
        let folderWidth = clampedFolderWidth(totalWidth: contentWidth)
        let previewPaneWidth = clampedPreviewWidth(totalWidth: contentWidth, folderWidth: folderWidth)
        let requestedGrowth = previewPaneWidth + 1
        let maximumFrameWidth = window.screen.map { screen in
            max(currentFrame.width, screen.visibleFrame.maxX - currentFrame.minX)
        } ?? currentFrame.width + requestedGrowth
        let targetFrameWidth = min(currentFrame.width + requestedGrowth, maximumFrameWidth)
        let actualGrowth = max(0, targetFrameWidth - currentFrame.width)
        guard actualGrowth > 0 else { return 0 }

        var frame = currentFrame
        frame.size.width = targetFrameWidth
        frame.origin = currentFrame.origin
        window.setFrame(frame, display: true, animate: false)
        return actualGrowth
    }

    private func shrinkWindowAfterPreview(_ window: NSWindow) {
        guard previewAutoResizeDelta > 0 else { return }

        var frame = window.frame
        frame.size.width = max(Self.minimumPreviewWindowWidth, frame.width - previewAutoResizeDelta)
        frame.origin = window.frame.origin
        window.setFrame(frame, display: true, animate: false)
    }

    private static let minimumPreviewWindowWidth: CGFloat = 600

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
