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
    @AppStorage("TerminalFileManager.isFolderTreeVisible") var isFolderTreeVisible = true
    @AppStorage("TerminalFileManager.isTerminalPaneVisible") var isTerminalPaneVisible = false
    @AppStorage("TerminalFileManager.terminalPaneHeight") var terminalPaneHeight = TerminalFileManagerLayout.defaultTerminalPaneHeight
    @AppStorage("TerminalFileManager.activePane") var activePaneRawValue = BrowserPaneID.left.rawValue
    @AppStorage("TerminalFileManager.activeArea") var activeAreaRawValue = ActiveArea.files.rawValue
    @AppStorage("TerminalFileManager.folderTreeWidth") var folderTreeWidth = TerminalFileManagerLayout.defaultFolderTreeWidth
    @AppStorage("TerminalFileManager.previewWidth") var previewWidth = TerminalFileManagerLayout.defaultPreviewPaneWidth
    @AppStorage("TerminalFileManager.fileNameColumnWidth") var fileNameColumnWidth = TerminalFileManagerLayout.defaultFileNameColumnWidth
    @AppStorage("TerminalFileManager.fileColumnConfiguration") var fileColumnConfigurationRaw = FileListColumnConfiguration.defaultRawValue
    @StateObject private var openDirectoryRouter = AppOpenDirectoryRouter.shared
    @State var leftTabs: [FilePaneTab]
    @State var rightTabs: [FilePaneTab]
    @State var leftActiveTabID: FilePaneTab.ID
    @State var rightActiveTabID: FilePaneTab.ID
    @State private var folderDragStartWidth: Double?
    @State private var previewDragStartWidth: Double?
    @State private var terminalDragStartHeight: Double?
    @State var previewAutoResizeDelta: CGFloat = 0
    @State var isFileListSettingsPresented = false
    @State var hoverHelpText = ""
    @State private var hasAppliedStartupFocus = false
    @FocusState var isSearchFocused: Bool
    @FocusState var isTerminalInputFocused: Bool
    @Environment(\.design) var design
    @Environment(\.theme) var theme
    @EnvironmentObject var shortcutStore: ShortcutStore
    @EnvironmentObject var userCommandStore: UserCommandStore

    init(launchArguments: AppLaunchArguments.Parsed = AppLaunchArguments.parse()) {
        let defaults = UserDefaults.standard
        var launchConfiguration = (try? AppLaunchConfigurationLoader.load()) ?? .default
        if let startupLayout = launchArguments.startupLayout {
            launchConfiguration.startupLayout = startupLayout
        }
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let leftURL = launchArguments.initialDirectory ?? Self.restoredDirectory(forKey: "TerminalFileManager.leftDirectory", fallback: homeURL)
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
        if let previewVisible = launchArguments.previewVisible {
            defaults.set(previewVisible, forKey: "TerminalFileManager.isPreviewVisible")
        }
        if let terminalVisible = launchArguments.terminalVisible {
            defaults.set(terminalVisible, forKey: "TerminalFileManager.isTerminalPaneVisible")
        }
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
            .background(WindowMinSizeBinder(
                minSize: NSSize(
                    width: TerminalFileManagerLayout.minimumWindowWidth(
                        isFolderTreeVisible: isFolderTreeVisible,
                        isSplitViewVisible: isSplitViewVisible,
                        isPreviewVisible: isPreviewVisible
                    ),
                    height: TerminalFileManagerLayout.minimumWindowHeight
                )
            ))
            .background(KeyboardEventHandler(isEnabled: !isSearchFocused && activeArea != .terminal) { event in
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
            .onChange(of: isTerminalPaneVisible) { _, isVisible in
                onTerminalPaneVisibilityChange(isVisible: isVisible)
            }
            .onChange(of: terminalModel.isRunning) { _, isRunning in
                refocusTerminalInputAfterCommandIfNeeded(isRunning: isRunning)
            }
            .onChange(of: terminalModel.terminalExitRequestID) {
                closeTerminalPaneFromExitCommand()
            }
            .onChange(of: activeArea) { _, newValue in
                if newValue != .terminal {
                    isTerminalInputFocused = false
                }
            }
            .onChange(of: isSplitViewVisible) { oldValue, newValue in
                onSplitViewVisibilityChange(from: oldValue, to: newValue)
            }
            .onChange(of: isPreviewVisible) { oldValue, newValue in
                onPreviewVisibilityChange(from: oldValue, to: newValue)
            }
            .onChange(of: isFolderTreeVisible) { oldValue, newValue in
                onFolderTreeVisibilityChange(from: oldValue, to: newValue)
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
        // CRITICAL invariant: `folderWidth + dividers + mainWidth +
        // previewPaneWidth` MUST equal `totalWidth`, which itself MUST
        // equal `geometry.size.width`. If the sum exceeds geometry,
        // the HStack overflows on both sides (center-aligned within
        // its parent) and adjacent panes draw on top of the file
        // pane's outer edges — visually erasing the active pane's
        // left and right borders. So:
        //   * `totalWidth` is taken straight from geometry. The
        //     per-configuration minimum is enforced upstream via
        //     `NSWindow.contentMinSize` (`applyWindowContentMinSize`),
        //     never by inflating the layout width here.
        //   * `mainWidth` has NO floor — the file area is the
        //     designated squeeze target if the window is briefly
        //     narrower than its content-min during a resize. Folder
        //     and preview keep their per-pane minimums (via their
        //     clamp helpers), the file area absorbs whatever is left
        //     (down to zero, clamped non-negative).
        // Snap pane widths to integer points so every pane boundary
        // lands on a whole pixel (sub-pixel divider positions blur
        // their 1pt strokes and accumulate visible rounding errors
        // across the layout). The file area absorbs whatever residue
        // remains so the `Σ = geometry.size.width` invariant still
        // holds exactly.
        let totalWidth = geometry.size.width
        let folderWidthRaw = isFolderTreeVisible ? clampedFolderWidth(totalWidth: totalWidth) : 0
        let previewPaneWidthRaw = isPreviewVisible ? clampedPreviewWidth(totalWidth: totalWidth, folderWidth: folderWidthRaw) : 0
        let folderWidth = folderWidthRaw.rounded()
        let previewPaneWidth = previewPaneWidthRaw.rounded()
        let dividers: CGFloat = (isFolderTreeVisible ? 1 : 0) + (isPreviewVisible ? 1 : 0)
        let mainWidth = max(0, totalWidth - folderWidth - previewPaneWidth - dividers)
        let terminalHeight = isTerminalPaneVisible ? clampedTerminalHeight(totalHeight: geometry.size.height) : 0
        let mainHeight = max(TerminalFileManagerLayout.minimumMainAreaHeight, geometry.size.height - terminalHeight - (isTerminalPaneVisible ? 1 : 0))

        return VStack(spacing: 0) {
            mainHorizontalLayout(
                totalWidth: totalWidth,
                folderWidth: folderWidth,
                mainWidth: mainWidth,
                mainHeight: mainHeight,
                previewPaneWidth: previewPaneWidth
            )
            .frame(width: totalWidth, height: mainHeight)
            .clipped()

            if isTerminalPaneVisible {
                terminalArea(totalHeight: geometry.size.height, terminalHeight: terminalHeight)
                    .frame(width: totalWidth, height: terminalHeight + 1)
                    .clipped()
            }
        }
        .frame(width: totalWidth, height: geometry.size.height, alignment: .top)
        .clipped()
    }

    private func mainHorizontalLayout(
        totalWidth: CGFloat,
        folderWidth: CGFloat,
        mainWidth: CGFloat,
        mainHeight: CGFloat,
        previewPaneWidth: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            if isFolderTreeVisible {
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
                    let reserved = TerminalFileManagerLayout.widthReservedRightOfFolderTree(
                        isSplitViewVisible: isSplitViewVisible,
                        isPreviewVisible: isPreviewVisible
                    )
                    folderTreeWidth = clamp(
                        baseWidth + translation,
                        min: Double(TerminalFileManagerLayout.minimumFolderTreeWidth),
                        max: max(
                            Double(TerminalFileManagerLayout.minimumFolderTreeWidth),
                            Double(totalWidth - reserved)
                        )
                    )
                } onEnded: {
                    folderDragStartWidth = nil
                }
            }

            fileArea
                .frame(width: mainWidth, height: mainHeight)
                .clipped()

            if isPreviewVisible {
                SplitDragHandle {
                    previewDragStartWidth = previewWidth
                } onChanged: { translation in
                    let baseWidth = previewDragStartWidth ?? previewWidth
                    let reserved = TerminalFileManagerLayout.widthReservedLeftOfPreview(
                        currentFolderWidth: folderWidth,
                        isFolderTreeVisible: isFolderTreeVisible,
                        isSplitViewVisible: isSplitViewVisible
                    )
                    previewWidth = clamp(
                        baseWidth - translation,
                        min: Double(TerminalFileManagerLayout.minimumPreviewPaneWidth),
                        max: max(
                            Double(TerminalFileManagerLayout.minimumPreviewPaneWidth),
                            Double(totalWidth - reserved)
                        )
                    )
                } onEnded: {
                    previewDragStartWidth = nil
                }

                PreviewPane(urls: activeModel.previewURLs)
                    .frame(width: previewPaneWidth, height: mainHeight)
                    .clipped()
            }
        }
        .frame(width: totalWidth, height: mainHeight)
        .clipped()
    }

    private func terminalArea(totalHeight: CGFloat, terminalHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            HorizontalSplitDragHandle {
                terminalDragStartHeight = terminalPaneHeight
            } onChanged: { translation in
                let baseHeight = terminalDragStartHeight ?? terminalPaneHeight
                terminalPaneHeight = clamp(
                    baseHeight - translation,
                    min: Double(TerminalFileManagerLayout.minimumTerminalPaneHeight),
                    max: max(
                        Double(TerminalFileManagerLayout.minimumTerminalPaneHeight),
                        Double(totalHeight - TerminalFileManagerLayout.minimumMainAreaHeight)
                    )
                )
            } onEnded: {
                terminalDragStartHeight = nil
            }

            BuiltInTerminalPane(
                model: terminalModel,
                isActive: activeArea == .terminal,
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
        isSearchFocused = false
    }

    private func handleAppear() {
        openRequestedDirectoryIfNeeded()
        applyStartupFocusIfNeeded()
        applyWindowContentMinSize()
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

    func clampedFolderWidth(totalWidth: CGFloat) -> CGFloat {
        Self.clampedFolderWidth(
            totalWidth: totalWidth,
            storedFolderWidth: folderTreeWidth,
            isSplitViewVisible: isSplitViewVisible,
            isPreviewVisible: isPreviewVisible
        )
    }

    func clampedPreviewWidth(totalWidth: CGFloat, folderWidth: CGFloat) -> CGFloat {
        Self.clampedPreviewWidth(
            totalWidth: totalWidth,
            folderWidth: folderWidth,
            storedPreviewWidth: previewWidth,
            isFolderTreeVisible: isFolderTreeVisible,
            isSplitViewVisible: isSplitViewVisible
        )
    }

    private func clampedTerminalHeight(totalHeight: CGFloat) -> CGFloat {
        CGFloat(clamp(
            terminalPaneHeight,
            min: Double(TerminalFileManagerLayout.minimumTerminalPaneHeight),
            max: max(
                Double(TerminalFileManagerLayout.minimumTerminalPaneHeight),
                Double(totalHeight - TerminalFileManagerLayout.minimumMainAreaHeight)
            )
        ))
    }

    static func clampedFolderWidth(
        totalWidth: CGFloat,
        storedFolderWidth: Double,
        isSplitViewVisible: Bool,
        isPreviewVisible: Bool
    ) -> CGFloat {
        let reserved = TerminalFileManagerLayout.widthReservedRightOfFolderTree(
            isSplitViewVisible: isSplitViewVisible,
            isPreviewVisible: isPreviewVisible
        )
        return CGFloat(clampedDouble(
            storedFolderWidth,
            min: Double(TerminalFileManagerLayout.minimumFolderTreeWidth),
            max: max(
                Double(TerminalFileManagerLayout.minimumFolderTreeWidth),
                Double(totalWidth - reserved)
            )
        ))
    }

    static func clampedPreviewWidth(
        totalWidth: CGFloat,
        folderWidth: CGFloat,
        storedPreviewWidth: Double,
        isFolderTreeVisible: Bool,
        isSplitViewVisible: Bool
    ) -> CGFloat {
        let reserved = TerminalFileManagerLayout.widthReservedLeftOfPreview(
            currentFolderWidth: folderWidth,
            isFolderTreeVisible: isFolderTreeVisible,
            isSplitViewVisible: isSplitViewVisible
        )
        return CGFloat(clampedDouble(
            storedPreviewWidth,
            min: Double(TerminalFileManagerLayout.minimumPreviewPaneWidth),
            max: max(
                Double(TerminalFileManagerLayout.minimumPreviewPaneWidth),
                Double(totalWidth - reserved)
            )
        ))
    }

}

#endif
