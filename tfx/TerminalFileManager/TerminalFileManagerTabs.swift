#if os(macOS)
import Foundation
import SwiftUI

struct FilePaneTab: Identifiable, Equatable {
    let id: UUID
    var directory: URL

    init(id: UUID = UUID(), directory: URL) {
        self.id = id
        self.directory = directory.standardizedFileURL
    }
}

private struct PersistedFilePaneTabs: Codable {
    var paths: [String]
    var activeIndex: Int
}

struct RestoredFilePaneTabs {
    var tabs: [FilePaneTab]
    var activeIndex: Int

    var activeTabID: FilePaneTab.ID {
        tabs[activeIndex].id
    }

    var activeDirectory: URL {
        tabs[activeIndex].directory
    }
}

extension TerminalFileManagerView {
    static func restoredTabs(forKey key: String, fallback: URL) -> RestoredFilePaneTabs {
        let fallbackTab = FilePaneTab(directory: fallback)
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let snapshot = try? JSONDecoder().decode(PersistedFilePaneTabs.self, from: data)
        else {
            return RestoredFilePaneTabs(tabs: [fallbackTab], activeIndex: 0)
        }

        let tabs = snapshot.paths.compactMap { path -> FilePaneTab? in
            guard !path.isEmpty else { return nil }
            let url = URL(fileURLWithPath: path).standardizedFileURL
            if let safeParent = safeRestorationParentForTabs(forPrivacyProtectedUserDirectory: url) {
                return FilePaneTab(directory: safeParent)
            }

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return nil
            }
            return FilePaneTab(directory: url)
        }

        guard !tabs.isEmpty else {
            return RestoredFilePaneTabs(tabs: [fallbackTab], activeIndex: 0)
        }

        let activeIndex = min(max(snapshot.activeIndex, 0), tabs.count - 1)
        return RestoredFilePaneTabs(tabs: tabs, activeIndex: activeIndex)
    }

    private static func safeRestorationParentForTabs(forPrivacyProtectedUserDirectory url: URL) -> URL? {
        guard let protectedDirectory = PrivacyProtectedDirectories.enclosingProtectedDirectory(for: url) else {
            return nil
        }
        return protectedDirectory.deletingLastPathComponent().standardizedFileURL
    }

    func tabs(for paneID: BrowserPaneID) -> [FilePaneTab] {
        paneID == .left ? leftTabs : rightTabs
    }

    func activeTabID(for paneID: BrowserPaneID) -> FilePaneTab.ID {
        paneID == .left ? leftActiveTabID : rightActiveTabID
    }

    func activeTabIndex(for paneID: BrowserPaneID) -> Int {
        let paneTabs = tabs(for: paneID)
        let activeID = activeTabID(for: paneID)
        return paneTabs.firstIndex { $0.id == activeID } ?? 0
    }

    func activeTabDirectory(for paneID: BrowserPaneID) -> URL {
        let paneTabs = tabs(for: paneID)
        let index = activeTabIndex(for: paneID)
        guard paneTabs.indices.contains(index) else {
            return URL(fileURLWithPath: NSHomeDirectory())
        }
        return paneTabs[index].directory
    }

    func setActiveTabID(_ id: FilePaneTab.ID, for paneID: BrowserPaneID) {
        if paneID == .left {
            leftActiveTabID = id
        } else {
            rightActiveTabID = id
        }
    }

    func setTabs(_ tabs: [FilePaneTab], for paneID: BrowserPaneID) {
        if paneID == .left {
            leftTabs = tabs
        } else {
            rightTabs = tabs
        }
    }

    func switchToTab(_ tab: FilePaneTab, in paneID: BrowserPaneID) {
        activePane = paneID
        activeArea = .files
        setActiveTabID(tab.id, for: paneID)
        modelForPane(paneID).navigate(to: tab.directory, recordsHistory: false)
        persistTabs(for: paneID)
    }

    func openNewTab(in paneID: BrowserPaneID? = nil) {
        let paneID = paneID ?? activePane
        var paneTabs = tabs(for: paneID)
        let directory = modelForPane(paneID).currentDirectory
        let tab = FilePaneTab(directory: directory)
        paneTabs.append(tab)
        setTabs(paneTabs, for: paneID)
        setActiveTabID(tab.id, for: paneID)
        activePane = paneID
        activeArea = .files
        persistTabs(for: paneID)
    }

    func closeActiveTab(in paneID: BrowserPaneID? = nil) {
        let paneID = paneID ?? activePane
        var paneTabs = tabs(for: paneID)
        guard paneTabs.count > 1 else { return }

        let closingIndex = activeTabIndex(for: paneID)
        paneTabs.remove(at: closingIndex)
        let nextIndex = min(closingIndex, paneTabs.count - 1)
        let nextTab = paneTabs[nextIndex]
        setTabs(paneTabs, for: paneID)
        setActiveTabID(nextTab.id, for: paneID)
        activePane = paneID
        activeArea = .files
        modelForPane(paneID).navigate(to: nextTab.directory, recordsHistory: false)
        persistTabs(for: paneID)
    }

    func selectAdjacentTab(delta: Int, in paneID: BrowserPaneID? = nil) {
        let paneID = paneID ?? activePane
        let paneTabs = tabs(for: paneID)
        guard paneTabs.count > 1 else { return }
        let currentIndex = activeTabIndex(for: paneID)
        let nextIndex = (currentIndex + delta + paneTabs.count) % paneTabs.count
        switchToTab(paneTabs[nextIndex], in: paneID)
    }

    func updateActiveTabDirectory(_ directory: URL, for paneID: BrowserPaneID) {
        var paneTabs = tabs(for: paneID)
        guard !paneTabs.isEmpty else {
            let tab = FilePaneTab(directory: directory)
            setTabs([tab], for: paneID)
            setActiveTabID(tab.id, for: paneID)
            persistTabs(for: paneID)
            return
        }

        let index = activeTabIndex(for: paneID)
        guard paneTabs.indices.contains(index) else { return }
        let standardizedDirectory = directory.standardizedFileURL
        guard paneTabs[index].directory != standardizedDirectory else { return }
        paneTabs[index].directory = standardizedDirectory
        setTabs(paneTabs, for: paneID)
        persistTabs(for: paneID)
    }

    func persistTabs(for paneID: BrowserPaneID) {
        let paneTabs = tabs(for: paneID)
        guard !paneTabs.isEmpty else { return }
        let snapshot = PersistedFilePaneTabs(
            paths: paneTabs.map(\.directory.path),
            activeIndex: activeTabIndex(for: paneID)
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: tabStorageKey(for: paneID))
    }

    func tabStorageKey(for paneID: BrowserPaneID) -> String {
        switch paneID {
        case .left:
            return "TerminalFileManager.leftTabs"
        case .right:
            return "TerminalFileManager.rightTabs"
        }
    }

    func modelForPane(_ paneID: BrowserPaneID) -> FileBrowserModel {
        paneID == .left ? leftModel : rightModel
    }
}
#endif
