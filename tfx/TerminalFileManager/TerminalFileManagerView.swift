#if os(macOS)
import AppKit
import Foundation
import SwiftUI

private enum DebugPaneToggleObserver {
    static var installed = false
}

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

        // Startup-only settings: applied EXACTLY ONCE per process,
        // not on every re-init of the SwiftUI struct. SwiftUI
        // re-creates `TerminalFileManagerView` whenever a parent
        // re-renders (e.g. after `didBecomeActive` reloads any
        // EnvironmentObject store), so unguarded writes here used
        // to clobber the user's in-session pane toggles every
        // time they switched away from and back to the app.
        // Precedence: command-line flag > config.toml >
        // previously saved @AppStorage value (unchanged).
        Self.applyStartupOverridesIfNeeded(
            defaults: defaults,
            initialSplitViewVisible: initialSplitViewVisible,
            launchArguments: launchArguments,
            launchConfiguration: launchConfiguration
        )
    }

    private static var hasAppliedStartupOverrides = false
    private static func applyStartupOverridesIfNeeded(
        defaults: UserDefaults,
        initialSplitViewVisible: Bool,
        launchArguments: AppLaunchArguments.Parsed,
        launchConfiguration: AppLaunchConfiguration
    ) {
        guard !hasAppliedStartupOverrides else { return }
        hasAppliedStartupOverrides = true

        defaults.set(initialSplitViewVisible, forKey: "TerminalFileManager.isSplitViewVisible")
        if let previewVisible = launchArguments.previewVisible ?? launchConfiguration.startupPreviewVisible {
            defaults.set(previewVisible, forKey: "TerminalFileManager.isPreviewVisible")
        }
        if let terminalVisible = launchArguments.terminalVisible ?? launchConfiguration.startupTerminalVisible {
            defaults.set(terminalVisible, forKey: "TerminalFileManager.isTerminalPaneVisible")
        }
        if let folderTreeVisible = launchConfiguration.startupFolderTreeVisible {
            defaults.set(folderTreeVisible, forKey: "TerminalFileManager.isFolderTreeVisible")
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
            // `NSWindow.contentMinSize` and the toggle-driven
            // window resize are owned by
            // `MainPaneSplitView.Coordinator` — see
            // `applyContentMinSize` / `resizeWindowForToggleIfNeeded`
            // in that file. Adding another writer here would split
            // ownership again, which is exactly what the previous
            // round of layout bugs traced back to.
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
            .onReceive(NotificationCenter.default.publisher(for: .terminalFileManagerFocusFilePane)) { _ in
                focusFilePane()
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
        let terminalHeight = isTerminalPaneVisible ? clampedTerminalHeight(totalHeight: geometry.size.height) : 0
        let mainHeight = max(TerminalFileManagerLayout.minimumMainAreaHeight, geometry.size.height - terminalHeight - (isTerminalPaneVisible ? 1 : 0))

        return VStack(spacing: 0) {
            mainPaneSplit
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

    /// Folder | file area | preview, backed by an `NSSplitView` so
    /// each side pane's width is fully decoupled from window-size
    /// changes and from the other pane's toggle state. See
    /// `MainPaneSplitView` for the architectural reasoning.
    private var mainPaneSplit: some View {
        MainPaneSplitView(
            folderContent: AnyView(
                FolderTreePane(
                    model: activeModel,
                    isActive: activeArea == .folderTree,
                    activate: { activeArea = .folderTree }
                )
            ),
            fileAreaContent: AnyView(fileArea),
            previewContent: AnyView(PreviewPane(urls: activeModel.previewURLs)),
            isFolderVisible: isFolderTreeVisible,
            isPreviewVisible: isPreviewVisible,
            // Folder tree is intentionally width-locked: there are
            // only two valid states, hidden (0) and shown
            // (`defaultFolderTreeWidth`). Any "drag the folder
            // divider" gesture would just snap back. The setter
            // is a no-op so NSSplitView's transient frame widths
            // during toggles can't corrupt the stored value.
            folderWidth: Binding(
                get: { TerminalFileManagerLayout.defaultFolderTreeWidth },
                set: { _ in }
            ),
            previewWidth: Binding(
                get: { previewWidth },
                set: { setStoredWidth(.preview, $0) }
            ),
            isSplitViewVisible: isSplitViewVisible,
            fileAreaMinimumWidth: TerminalFileManagerLayout.minimumFileAreaWidth(
                isSplitViewVisible: isSplitViewVisible
            ),
            minimumWindowHeight: TerminalFileManagerLayout.minimumWindowHeight
        )
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
                    setStoredWidth(.folderTree, clamp(
                        baseWidth + translation,
                        min: Double(TerminalFileManagerLayout.minimumFolderTreeWidth),
                        max: max(
                            Double(TerminalFileManagerLayout.minimumFolderTreeWidth),
                            Double(totalWidth - reserved)
                        )
                    ))
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
                    setStoredWidth(.preview, clamp(
                        baseWidth - translation,
                        min: Double(TerminalFileManagerLayout.minimumPreviewPaneWidth),
                        max: max(
                            Double(TerminalFileManagerLayout.minimumPreviewPaneWidth),
                            Double(totalWidth - reserved)
                        )
                    ))
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
                activate: focusTerminalPane,
                syncFilePaneToTerminal: { url in
                    activeModel.navigate(to: url)
                }
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
        installDebugPaneToggleObserverIfNeeded()
        // `NSWindow.contentMinSize` is set by
        // `MainPaneSplitView.Coordinator.applyContentMinSize` on
        // the first `updateNSView`, which fires right after
        // `makeNSView` schedules its initial async pass — no
        // additional appear-time setup needed here.
    }

    /// Listens (when `TFX_PANE_LAYOUT_LOGS=1`) for distributed
    /// notifications driving pane visibility from the probe shell
    /// script. Lets the probe trigger in-process toggles of preview/
    /// folder without needing Accessibility permission for osascript
    /// keystroke injection.
    private func installDebugPaneToggleObserverIfNeeded() {
        guard ProcessInfo.processInfo.environment["TFX_PANE_LAYOUT_LOGS"] == "1" else { return }
        guard !DebugPaneToggleObserver.installed else { return }
        DebugPaneToggleObserver.installed = true
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            forName: Notification.Name("org.spumoni.tfx.debug.togglePreview"),
            object: nil,
            queue: .main
        ) { _ in
            let key = "TerminalFileManager.isPreviewVisible"
            let current = UserDefaults.standard.object(forKey: key) as? Bool ?? true
            UserDefaults.standard.set(!current, forKey: key)
        }
        center.addObserver(
            forName: Notification.Name("org.spumoni.tfx.debug.toggleFolder"),
            object: nil,
            queue: .main
        ) { _ in
            let key = "TerminalFileManager.isFolderTreeVisible"
            let current = UserDefaults.standard.object(forKey: key) as? Bool ?? true
            UserDefaults.standard.set(!current, forKey: key)
        }
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
        if leftModel.canGoUp {
            leftModel.isParentDirectorySelected = true
        }
        // Use `focusFilePane()` so the keyboard focus actually
        // lands on the file pane's key-handler view at startup.
        // Just setting `activeArea = .files` isn't enough: the
        // search field's hosted `NSTextView` may already be
        // first responder (SwiftUI default), which
        // `KeyHandlingNSView` won't pre-empt unless we
        // explicitly clear `isSearchFocused` /
        // `isTerminalInputFocused`. Without this, arrow keys
        // don't work until the user clicks into the file list.
        focusFilePane()
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
