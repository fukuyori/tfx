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
        let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL
        let protectedDirectories = [
            home.appendingPathComponent("Desktop", isDirectory: true),
            home.appendingPathComponent("Documents", isDirectory: true),
            home.appendingPathComponent("Downloads", isDirectory: true)
        ]
        let target = url.standardizedFileURL

        for protectedDirectory in protectedDirectories {
            if target == protectedDirectory {
                return home
            }

            if target.path.hasPrefix(protectedDirectory.path + "/") {
                return protectedDirectory.deletingLastPathComponent().standardizedFileURL
            }
        }

        return nil
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

        if isVisible {
            let sourceModel = activeModel
            let targetModel = activePane == .left ? rightModel : leftModel
            targetModel.navigate(
                to: sourceModel.currentDirectory,
                recordsHistory: false
            )
        }

        isSplitViewVisible = isVisible
    }
}
#endif
