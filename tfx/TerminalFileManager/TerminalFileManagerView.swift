#if os(macOS)
import AppKit
import Foundation
import SwiftUI

struct TerminalFileManagerView: View {
    @StateObject var leftModel: FileBrowserModel
    @StateObject var rightModel: FileBrowserModel
    @StateObject var terminalModel: BuiltInTerminalModel
    @AppStorage("TerminalFileManager.isPreviewVisible") var isPreviewVisible = true
    @AppStorage("TerminalFileManager.isSplitViewVisible") var isSplitViewVisible = false
    @AppStorage("TerminalFileManager.isTerminalPaneVisible") var isTerminalPaneVisible = false
    @AppStorage("TerminalFileManager.terminalPaneHeight") var terminalPaneHeight = 220.0
    @AppStorage("TerminalFileManager.terminalFollowsActiveFolder") var terminalFollowsActiveFolder = true
    @AppStorage("TerminalFileManager.activePane") var activePaneRawValue = BrowserPaneID.left.rawValue
    @AppStorage("TerminalFileManager.activeArea") var activeAreaRawValue = ActiveArea.files.rawValue
    @AppStorage("TerminalFileManager.folderTreeWidth") private var folderTreeWidth = 250.0
    @AppStorage("TerminalFileManager.previewWidth") var previewWidth = 320.0
    @AppStorage("TerminalFileManager.fileSplitRatio") var fileSplitRatio = 0.5
    @AppStorage("TerminalFileManager.fileNameColumnWidth") var fileNameColumnWidth = 320.0
    @AppStorage("TerminalFileManager.fileColumnConfiguration") var fileColumnConfigurationRaw = FileListColumnConfiguration.defaultRawValue
    @StateObject private var openDirectoryRouter = AppOpenDirectoryRouter.shared
    @State var leftTabs: [FilePaneTab]
    @State var rightTabs: [FilePaneTab]
    @State var leftActiveTabID: FilePaneTab.ID
    @State var rightActiveTabID: FilePaneTab.ID
    @State private var folderDragStartWidth: Double?
    @State private var previewDragStartWidth: Double?
    @State var fileSplitDragStartRatio: Double?
    @State private var terminalDragStartHeight: Double?
    @State var isFileListSettingsPresented = false
    @State var hoverHelpText = ""
    @State private var hasAppliedStartupFocus = false
    @FocusState var isSearchFocused: Bool
    @FocusState var isTerminalInputFocused: Bool
    @Environment(\.design) var design
    @Environment(\.theme) var theme
    @EnvironmentObject var shortcutStore: ShortcutStore

    init(initialDirectory: URL? = AppLaunchArguments.initialDirectory()) {
        let defaults = UserDefaults.standard
        let launchConfiguration = (try? AppLaunchConfigurationLoader.load()) ?? .default
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let leftURL = initialDirectory ?? Self.restoredDirectory(forKey: "TerminalFileManager.leftDirectory", fallback: homeURL)
        let restoredRightURL = Self.restoredDirectory(forKey: "TerminalFileManager.rightDirectory", fallback: leftURL)
        let configuredSplitRightTabs = Self.startupTabs(
            launchConfiguration.startupRightFolderURLs
        )
        let restoredLeftTabs = Self.restoredTabs(
            forKey: "TerminalFileManager.leftTabs",
            fallback: leftURL
        )
        let restoredRightTabs = Self.restoredTabs(
            forKey: "TerminalFileManager.rightTabs",
            fallback: restoredRightURL
        )
        let leftTab = FilePaneTab(directory: leftURL)
        let initialLeftTabs: [FilePaneTab]
        let initialRightTabs: [FilePaneTab]
        let initialLeftActiveTabID: FilePaneTab.ID
        let initialRightActiveTabID: FilePaneTab.ID
        let initialLeftDirectory: URL
        let initialRightDirectory: URL
        let initialSplitViewVisible: Bool

        switch launchConfiguration.startupLayout {
        case .single:
            initialLeftTabs = [leftTab]
            initialRightTabs = [FilePaneTab(directory: leftURL)]
            initialLeftActiveTabID = leftTab.id
            initialRightActiveTabID = initialRightTabs[0].id
            initialLeftDirectory = leftURL
            initialRightDirectory = leftURL
            initialSplitViewVisible = false
        case .split:
            let splitRightTabs: [FilePaneTab]
            let splitRightActiveTabID: FilePaneTab.ID
            let splitRightDirectory: URL
            if let configuredSplitRightTabs {
                splitRightTabs = configuredSplitRightTabs.tabs
                splitRightActiveTabID = configuredSplitRightTabs.activeTabID
                splitRightDirectory = configuredSplitRightTabs.activeDirectory
            } else {
                splitRightTabs = restoredRightTabs.tabs
                splitRightActiveTabID = restoredRightTabs.activeTabID
                splitRightDirectory = restoredRightTabs.activeDirectory
            }
            initialLeftTabs = [leftTab]
            initialRightTabs = splitRightTabs
            initialLeftActiveTabID = leftTab.id
            initialRightActiveTabID = splitRightActiveTabID
            initialLeftDirectory = leftURL
            initialRightDirectory = splitRightDirectory
            initialSplitViewVisible = true
        case .restore:
            initialLeftTabs = restoredLeftTabs.tabs
            initialRightTabs = restoredRightTabs.tabs
            initialLeftActiveTabID = restoredLeftTabs.activeTabID
            initialRightActiveTabID = restoredRightTabs.activeTabID
            initialLeftDirectory = restoredLeftTabs.activeDirectory
            initialRightDirectory = restoredRightTabs.activeDirectory
            initialSplitViewVisible = defaults.bool(forKey: "TerminalFileManager.isSplitViewVisible")
        }

        _leftModel = StateObject(wrappedValue: FileBrowserModel(initialDirectory: initialLeftDirectory))
        _rightModel = StateObject(wrappedValue: FileBrowserModel(initialDirectory: initialRightDirectory))
        _terminalModel = StateObject(wrappedValue: BuiltInTerminalModel(currentDirectory: initialLeftDirectory))
        _leftTabs = State(initialValue: initialLeftTabs)
        _rightTabs = State(initialValue: initialRightTabs)
        _leftActiveTabID = State(initialValue: initialLeftActiveTabID)
        _rightActiveTabID = State(initialValue: initialRightActiveTabID)

        defaults.set(initialSplitViewVisible, forKey: "TerminalFileManager.isSplitViewVisible")
        defaults.set(BrowserPaneID.left.rawValue, forKey: "TerminalFileManager.activePane")
        defaults.set(ActiveArea.files.rawValue, forKey: "TerminalFileManager.activeArea")
    }

    var body: some View {
        errorAlertView
    }

    private var baseView: AnyView {
        AnyView(AnyView(rootLayout)
            .background(WindowFrameAutosaver(
                name: "TerminalFileManagerWindow",
                allowsTransparency: design.opacity.background < 1
            ))
            .background(KeyboardEventHandler(isEnabled: !isSearchFocused && !isTerminalInputFocused) { event in
                handleKeyEvent(event)
            })
            .background(Color.clear)
        )
    }

    private var lifecycleView: AnyView {
        AnyView(baseView
            .onAppear(perform: handleAppear)
            .onChange(of: openDirectoryRouter.request) {
                openRequestedDirectoryIfNeeded()
            }
            .onChange(of: leftModel.currentDirectory) {
                onPaneDirectoryChange(.left)
            }
            .onChange(of: rightModel.currentDirectory) {
                onPaneDirectoryChange(.right)
            }
            .onChange(of: activePaneRawValue) {
                followActiveFolderIfNeeded()
            }
            .onChange(of: terminalFollowsActiveFolder) {
                followActiveFolderIfNeeded()
            }
            .onChange(of: isTerminalPaneVisible) { _, isVisible in
                onTerminalPaneVisibilityChange(isVisible: isVisible)
            }
            .onChange(of: terminalModel.isRunning) { _, isRunning in
                refocusTerminalInputAfterCommandIfNeeded(isRunning: isRunning)
            }
            .onChange(of: isSplitViewVisible) { oldValue, newValue in
                onSplitViewVisibilityChange(from: oldValue, to: newValue)
            }
            .onChange(of: isPreviewVisible) { oldValue, newValue in
                onPreviewVisibilityChange(from: oldValue, to: newValue)
            }
        )
    }

    private var notificationView: AnyView {
        AnyView(lifecycleView
            .onReceive(NotificationCenter.default.publisher(for: .terminalFileManagerSwapPanes)) { _ in
                swapPanes()
            }
            .onReceive(NotificationCenter.default.publisher(for: .terminalFileManagerNewTab)) { _ in
                openNewTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: .terminalFileManagerCloseTab)) { _ in
                closeActiveTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: .terminalFileManagerPreviousTab)) { _ in
                selectAdjacentTab(delta: -1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .terminalFileManagerNextTab)) { _ in
                selectAdjacentTab(delta: 1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .terminalFileManagerToggleTerminalPane)) { _ in
                toggleTerminalPane()
            }
            .onReceive(NotificationCenter.default.publisher(for: .terminalFileManagerFocusTerminalPane)) { _ in
                focusTerminalPane()
            }
        )
    }

    private var errorAlertView: AnyView {
        AnyView(notificationView
            .alert(activeErrorTitle, isPresented: Binding(
                get: { leftModel.isShowingError || rightModel.isShowingError },
                set: { isPresented in
                    if !isPresented {
                        leftModel.dismissError()
                        rightModel.dismissError()
                    }
                }
            )) {
                Button(activeErrorButtonTitle, role: .cancel) {
                    leftModel.dismissError()
                    rightModel.dismissError()
                }
            } message: {
                Text(activeErrorMessage)
            }
        )
    }

    private var rootLayout: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { geometry in
                mainLayout(in: geometry)
            }
        }
    }

    private var activeErrorTitle: String {
        leftModel.isShowingError ? leftModel.errorTitle : rightModel.errorTitle
    }

    private var activeErrorButtonTitle: String {
        leftModel.isShowingError ? leftModel.errorButtonTitle : rightModel.errorButtonTitle
    }

    private var activeErrorMessage: String {
        leftModel.isShowingError ? leftModel.errorMessage : rightModel.errorMessage
    }

    private func mainLayout(in geometry: GeometryProxy) -> some View {
        let totalWidth = max(geometry.size.width, 900)
        let folderWidth = clampedFolderWidth(totalWidth: totalWidth)
        let previewPaneWidth = isPreviewVisible ? clampedPreviewWidth(totalWidth: totalWidth, folderWidth: folderWidth) : 0
        let mainWidth = max(360, totalWidth - folderWidth - (isPreviewVisible ? previewPaneWidth : 0) - (isPreviewVisible ? 2 : 1))
        let terminalHeight = isTerminalPaneVisible ? clampedTerminalHeight(totalHeight: geometry.size.height) : 0
        let mainHeight = max(260, geometry.size.height - terminalHeight - (isTerminalPaneVisible ? 1 : 0))

        return VStack(spacing: 0) {
            mainHorizontalLayout(
                totalWidth: totalWidth,
                folderWidth: folderWidth,
                mainWidth: mainWidth,
                mainHeight: mainHeight,
                previewPaneWidth: previewPaneWidth
            )

            if isTerminalPaneVisible {
                terminalArea(totalHeight: geometry.size.height, terminalHeight: terminalHeight)
            }
        }
    }

    private func mainHorizontalLayout(
        totalWidth: CGFloat,
        folderWidth: CGFloat,
        mainWidth: CGFloat,
        mainHeight: CGFloat,
        previewPaneWidth: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            FolderTreePane(
                model: activeModel,
                isActive: activeArea == .folderTree,
                activate: { activeArea = .folderTree }
            )
            .frame(width: folderWidth, height: mainHeight)

            SplitDragHandle {
                folderDragStartWidth = folderTreeWidth
            } onChanged: { translation in
                let baseWidth = folderDragStartWidth ?? folderTreeWidth
                folderTreeWidth = clamp(baseWidth + translation, min: 180, max: max(180, Double(totalWidth - 520)))
            } onEnded: {
                folderDragStartWidth = nil
            }

            fileArea
                .frame(width: mainWidth, height: mainHeight)

            if isPreviewVisible {
                SplitDragHandle {
                    previewDragStartWidth = previewWidth
                } onChanged: { translation in
                    let baseWidth = previewDragStartWidth ?? previewWidth
                    previewWidth = clamp(baseWidth - translation, min: 240, max: max(240, Double(totalWidth - folderWidth - 360)))
                } onEnded: {
                    previewDragStartWidth = nil
                }

                PreviewPane(urls: activeModel.previewURLs)
                    .frame(width: previewPaneWidth, height: mainHeight)
            }
        }
    }

    private func terminalArea(totalHeight: CGFloat, terminalHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            HorizontalSplitDragHandle {
                terminalDragStartHeight = terminalPaneHeight
            } onChanged: { translation in
                let baseHeight = terminalDragStartHeight ?? terminalPaneHeight
                terminalPaneHeight = clamp(baseHeight - translation, min: 120, max: max(120, Double(totalHeight - 260)))
            } onEnded: {
                terminalDragStartHeight = nil
            }

            BuiltInTerminalPane(
                model: terminalModel,
                followsActiveFolder: $terminalFollowsActiveFolder,
                isInputFocused: $isTerminalInputFocused,
                activate: focusTerminalPane
            )
            .frame(height: terminalHeight)
        }
    }

    private func onPaneDirectoryChange(_ paneID: BrowserPaneID) {
        let paneModel = modelForPane(paneID)
        UserDefaults.standard.set(paneModel.currentDirectory.path, forKey: "TerminalFileManager.\(paneID.rawValue)Directory")
        updateActiveTabDirectory(paneModel.currentDirectory, for: paneID)
        followActiveFolderIfNeeded()
        isSearchFocused = false
    }

    private func handleAppear() {
        openRequestedDirectoryIfNeeded()
        applyStartupFocusIfNeeded()
    }

    /// Set the initial keyboard focus to the left file pane with the `..`
    /// row pre-selected (when navigation up is possible). Runs once on the
    /// first appear so subsequent re-entries — including window restoration
    /// — do not clobber the user's selection.
    private func applyStartupFocusIfNeeded() {
        guard !hasAppliedStartupFocus else { return }
        hasAppliedStartupFocus = true

        // Pending an open-from-Finder request always wins; that path sets
        // its own focus through `openRequestedDirectoryIfNeeded`.
        guard openDirectoryRouter.request == nil else { return }

        activePane = .left
        activeArea = .files
        if leftModel.canGoUp {
            leftModel.isParentDirectorySelected = true
        }
    }

    private func openRequestedDirectoryIfNeeded() {
        guard let directory = openDirectoryRouter.request?.directory else {
            return
        }

        activePane = .left
        activeArea = .files
        leftModel.navigate(to: directory)
        NSApp.activate()
    }

    private func clampedFolderWidth(totalWidth: CGFloat) -> CGFloat {
        CGFloat(clamp(folderTreeWidth, min: 180, max: max(180, Double(totalWidth - 520))))
    }

    private func clampedPreviewWidth(totalWidth: CGFloat, folderWidth: CGFloat) -> CGFloat {
        CGFloat(clamp(previewWidth, min: 240, max: max(240, Double(totalWidth - folderWidth - 360))))
    }

    private func clampedTerminalHeight(totalHeight: CGFloat) -> CGFloat {
        CGFloat(clamp(terminalPaneHeight, min: 120, max: max(120, Double(totalHeight - 260))))
    }

}

#endif
