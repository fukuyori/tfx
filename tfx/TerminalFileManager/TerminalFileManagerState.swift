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

    func onTerminalPaneVisibilityChange(isVisible: Bool) {
        if isVisible {
            terminalModel.open()
            activateTerminalPane()
        } else {
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
        guard newValue else { return }

        // Activating split — bring the other pane onto the same directory.
        let sourceModel = activeModel
        let targetModel = activePane == .left ? rightModel : leftModel
        targetModel.navigate(
            to: sourceModel.currentDirectory,
            recordsHistory: false
        )
    }

    /// Side-effect handler for `isPreviewVisible` changes. Resizes the
    /// window so that toggling preview reveals or hides the pane by
    /// growing / shrinking the window to the right, rather than squeezing
    /// the existing folder-tree and file-pane widths.
    func onPreviewVisibilityChange(from oldValue: Bool, to newValue: Bool) {
        guard oldValue != newValue else { return }
        guard let window = previewToggleTargetWindow() else { return }

        var frame = window.frame
        let folderWidth = clampedFolderWidth(totalWidth: frame.width)
        let previewPaneWidth = clampedPreviewWidth(totalWidth: frame.width, folderWidth: folderWidth)
        // The preview area takes the actual clamped preview width plus the
        // 1pt drag-handle separator between file area and preview pane.
        let delta = previewPaneWidth + 1

        if newValue {
            // Showing preview — extend the window to the right. Try to keep
            // the window's left edge in place; if doing so pushes the right
            // edge off the visible screen, shift left as needed.
            frame.size.width += delta
            if let visibleFrame = window.screen?.visibleFrame {
                if frame.maxX > visibleFrame.maxX {
                    let shiftedX = max(visibleFrame.minX, visibleFrame.maxX - frame.size.width)
                    frame.origin.x = shiftedX
                }
                if frame.size.width > visibleFrame.width {
                    frame.size.width = visibleFrame.width
                    frame.origin.x = visibleFrame.minX
                }
            }
        } else {
            // Hiding preview — pull the right edge back. Floor the width so
            // the window cannot collapse below something usable.
            frame.size.width = max(Self.minimumPreviewToggleWindowWidth, frame.size.width - delta)
        }

        window.setFrame(frame, display: true, animate: true)
    }

    /// Minimum width preserved when shrinking the window after the preview
    /// pane is hidden. Roughly: folder tree minimum (180) + drag handle (1)
    /// + file pane minimum (360) + window chrome / margins.
    static let minimumPreviewToggleWindowWidth: CGFloat = 600

    /// Resolve the window the preview-visibility resize should target. We
    /// prefer `NSApp.keyWindow` so the resize follows the user's active
    /// window when multiple tfx windows are open.
    private func previewToggleTargetWindow() -> NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow
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
