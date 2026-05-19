#if os(macOS)
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
}
#endif
