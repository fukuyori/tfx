#if os(macOS)
import AppKit
import AVKit
import Combine
import Foundation
import PDFKit
import QuickLookUI
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct TerminalFileManagerView: View {
    @StateObject private var leftModel: FileBrowserModel
    @StateObject private var rightModel: FileBrowserModel
    @AppStorage("TerminalFileManager.isPreviewVisible") private var isPreviewVisible = true
    @AppStorage("TerminalFileManager.isSplitViewVisible") private var isSplitViewVisible = true
    @AppStorage("TerminalFileManager.activePane") private var activePaneRawValue = BrowserPaneID.left.rawValue
    @AppStorage("TerminalFileManager.activeArea") private var activeAreaRawValue = ActiveArea.files.rawValue
    @AppStorage("TerminalFileManager.folderTreeWidth") private var folderTreeWidth = 250.0
    @AppStorage("TerminalFileManager.previewWidth") private var previewWidth = 320.0
    @AppStorage("TerminalFileManager.fileSplitRatio") private var fileSplitRatio = 0.5
    @AppStorage("TerminalFileManager.fileNameColumnWidth") private var fileNameColumnWidth = 320.0
    @AppStorage("TerminalFileManager.fileColumnConfiguration") private var fileColumnConfigurationRaw = FileListColumnConfiguration.defaultRawValue
    @State private var folderDragStartWidth: Double?
    @State private var previewDragStartWidth: Double?
    @State private var fileSplitDragStartRatio: Double?
    @State private var isFileListSettingsPresented = false
    @State private var hoverHelpText = ""
    @FocusState private var isSearchFocused: Bool

    init() {
        let defaults = UserDefaults.standard
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? homeURL
        let leftURL = Self.restoredDirectory(forKey: "TerminalFileManager.leftDirectory", fallback: homeURL)
        let rightURL = Self.restoredDirectory(forKey: "TerminalFileManager.rightDirectory", fallback: downloadsURL)

        _leftModel = StateObject(wrappedValue: FileBrowserModel(initialDirectory: leftURL))
        _rightModel = StateObject(wrappedValue: FileBrowserModel(initialDirectory: rightURL))

        let activePane = defaults.string(forKey: "TerminalFileManager.activePane") ?? BrowserPaneID.left.rawValue
        if BrowserPaneID(rawValue: activePane) == nil {
            defaults.set(BrowserPaneID.left.rawValue, forKey: "TerminalFileManager.activePane")
        }
    }

    private var activePane: BrowserPaneID {
        get {
            BrowserPaneID(rawValue: activePaneRawValue) ?? .left
        }
        nonmutating set {
            activePaneRawValue = newValue.rawValue
        }
    }

    private var activeArea: ActiveArea {
        get {
            ActiveArea(rawValue: activeAreaRawValue) ?? .files
        }
        nonmutating set {
            activeAreaRawValue = newValue.rawValue
        }
    }

    private var activeModel: FileBrowserModel {
        activePane == .left ? leftModel : rightModel
    }

    private var model: FileBrowserModel {
        activeModel
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { geometry in
                let totalWidth = max(geometry.size.width, 900)
                let folderWidth = clampedFolderWidth(totalWidth: totalWidth)
                let previewPaneWidth = isPreviewVisible ? clampedPreviewWidth(totalWidth: totalWidth, folderWidth: folderWidth) : 0
                let mainWidth = max(360, totalWidth - folderWidth - (isPreviewVisible ? previewPaneWidth : 0) - (isPreviewVisible ? 2 : 1))

                HStack(spacing: 0) {
                    FolderTreePane(
                        model: activeModel,
                        isActive: activeArea == .folderTree,
                        activate: { activeArea = .folderTree }
                    )
                        .frame(width: folderWidth)

                    SplitDragHandle {
                        folderDragStartWidth = folderTreeWidth
                    } onChanged: { translation in
                        let baseWidth = folderDragStartWidth ?? folderTreeWidth
                        folderTreeWidth = clamp(baseWidth + translation, min: 180, max: max(180, Double(totalWidth - 520)))
                    } onEnded: {
                        folderDragStartWidth = nil
                    }

                    fileArea
                        .frame(width: mainWidth, height: geometry.size.height)

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
                            .frame(width: previewPaneWidth)
                    }
                }
            }
        }
        .background(WindowFrameAutosaver(name: "TerminalFileManagerWindow"))
        .background(KeyboardEventHandler(isEnabled: !isSearchFocused) { event in
            handleKeyEvent(event)
        })
        .background(Color(nsColor: .textBackgroundColor))
        .onChange(of: leftModel.currentDirectory) {
            UserDefaults.standard.set(leftModel.currentDirectory.path, forKey: "TerminalFileManager.leftDirectory")
        }
        .onChange(of: rightModel.currentDirectory) {
            UserDefaults.standard.set(rightModel.currentDirectory.path, forKey: "TerminalFileManager.rightDirectory")
        }
        .alert("File operation failed", isPresented: Binding(
            get: { leftModel.isShowingError || rightModel.isShowingError },
            set: { isPresented in
                if !isPresented {
                    leftModel.isShowingError = false
                    rightModel.isShowingError = false
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(leftModel.isShowingError ? leftModel.errorMessage : rightModel.errorMessage)
        }
    }

    private static func restoredDirectory(forKey key: String, fallback: URL) -> URL {
        guard let path = UserDefaults.standard.string(forKey: key), !path.isEmpty else {
            return fallback
        }

        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return url
        }

        return fallback
    }

    private func clampedFolderWidth(totalWidth: CGFloat) -> CGFloat {
        CGFloat(clamp(folderTreeWidth, min: 180, max: max(180, Double(totalWidth - 520))))
    }

    private func clampedPreviewWidth(totalWidth: CGFloat, folderWidth: CGFloat) -> CGFloat {
        CGFloat(clamp(previewWidth, min: 240, max: max(240, Double(totalWidth - folderWidth - 360))))
    }

    private func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.min(Swift.max(value, minValue), maxValue)
    }

    private func reloadAllPanes() {
        leftModel.reload()
        rightModel.reload()
        activeModel.expandFolder(activeModel.currentDirectory)
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let unsupportedModifiers = event.modifierFlags.intersection([.command, .option, .control])
        guard unsupportedModifiers.isEmpty else { return false }
        let isRangeSelection = event.modifierFlags.contains(.shift)

        switch event.keyCode {
        case 126:
            activeArea == .folderTree ? activeModel.moveFolderTreeSelection(delta: -1) : activeModel.moveFileSelection(delta: -1, extendingRange: isRangeSelection)
            return true
        case 125:
            activeArea == .folderTree ? activeModel.moveFolderTreeSelection(delta: 1) : activeModel.moveFileSelection(delta: 1, extendingRange: isRangeSelection)
            return true
        case 123:
            moveKeyboardFocusLeft()
            return true
        case 124:
            moveKeyboardFocusRight()
            return true
        case 36, 76:
            activeArea == .folderTree ? activeModel.activateFolderTreeSelection() : activeModel.activateFileSelection()
            return true
        default:
            return false
        }
    }

    private func moveKeyboardFocusLeft() {
        guard activeArea == .files else { return }

        if isSplitViewVisible, activePane == .right {
            activePane = .left
        } else {
            activeArea = .folderTree
            activeModel.ensureFolderTreeSelection()
        }
    }

    private func moveKeyboardFocusRight() {
        if activeArea == .folderTree {
            activeArea = .files
            activeModel.ensureFileSelection()
            return
        }

        guard isSplitViewVisible, activePane == .left else { return }
        activePane = .right
        activeModel.ensureFileSelection()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                model.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(!model.canGoBack)
            .keyboardShortcut("[", modifiers: .command)
            .quickHelp("Back", text: $hoverHelpText)

            Button {
                model.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(!model.canGoForward)
            .keyboardShortcut("]", modifiers: .command)
            .quickHelp("Forward", text: $hoverHelpText)

            Button {
                model.goUp()
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.upArrow, modifiers: .command)
            .quickHelp("Parent folder", text: $hoverHelpText)

            Button {
                model.pickFolder()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .quickHelp("Open folder", text: $hoverHelpText)

            Button {
                model.togglePinnedFolder(model.currentDirectory)
            } label: {
                Image(systemName: model.isFolderPinned(model.currentDirectory) ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .quickHelp(model.isFolderPinned(model.currentDirectory) ? "Unpin current folder" : "Pin current folder", text: $hoverHelpText)

            Text(model.currentDirectory.path(percentEncoded: false))
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))

            TextField("Search", text: Binding(
                get: { model.searchText },
                set: { model.searchText = $0 }
            ))
                .textFieldStyle(.roundedBorder)
                .font(.system(.callout, design: .monospaced))
                .frame(width: 180)
                .focused($isSearchFocused)

            Button {
                isSearchFocused = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("f", modifiers: .command)
            .quickHelp("Focus search", text: $hoverHelpText)

            Menu {
                Picker("Sort", selection: Binding(
                    get: { model.sortKey },
                    set: { model.sortKey = $0 }
                )) {
                    ForEach(FileSortKey.allCases) { key in
                        Text(key.title).tag(key)
                    }
                }

                Divider()

                Button(model.sortAscending ? "Descending" : "Ascending") {
                    model.sortAscending.toggle()
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .quickHelp("Sort", text: $hoverHelpText)

            Toggle(isOn: Binding(
                get: { model.showHiddenFiles },
                set: { model.showHiddenFiles = $0 }
            )) {
                Image(systemName: "eye")
            }
            .toggleStyle(.button)
            .keyboardShortcut(".", modifiers: [.command, .shift])
            .quickHelp("Show hidden files", text: $hoverHelpText)

            Button {
                model.createFolder()
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("n", modifiers: .command)
            .quickHelp("New folder", text: $hoverHelpText)

            Button {
                model.renameSelectedItem()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .disabled(model.selectionCount != 1)
            .keyboardShortcut(.return, modifiers: [])
            .quickHelp("Rename", text: $hoverHelpText)

            Button {
                model.moveSelectedItemsToTrash()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(!model.hasSelection)
            .keyboardShortcut(.delete, modifiers: [])
            .quickHelp("Move to Trash", text: $hoverHelpText)

            Button {
                model.copySelectedItems()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .disabled(!model.hasSelection)
            .keyboardShortcut("c", modifiers: .command)
            .quickHelp("Copy selected items", text: $hoverHelpText)

            Button {
                model.cutSelectedItems()
            } label: {
                Image(systemName: "scissors")
            }
            .buttonStyle(.borderless)
            .disabled(!model.hasSelection)
            .keyboardShortcut("x", modifiers: .command)
            .quickHelp("Cut selected items", text: $hoverHelpText)

            Button {
                model.pasteItems()
            } label: {
                Image(systemName: "clipboard")
            }
            .buttonStyle(.borderless)
            .disabled(!model.canPaste)
            .keyboardShortcut("v", modifiers: .command)
            .quickHelp("Paste into current folder", text: $hoverHelpText)

            Button {
                model.revealSelectedItemsInFinder()
            } label: {
                Image(systemName: "finder")
            }
            .buttonStyle(.borderless)
            .disabled(!model.hasSelection)
            .quickHelp("Reveal in Finder", text: $hoverHelpText)

            Button {
                model.selectAllVisibleItems()
            } label: {
                Image(systemName: "checklist")
            }
            .buttonStyle(.borderless)
            .disabled(model.items.isEmpty)
            .keyboardShortcut("a", modifiers: .command)
            .quickHelp("Select all", text: $hoverHelpText)

            Button {
                model.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("r", modifiers: .command)
            .quickHelp("Reload", text: $hoverHelpText)

            Button {
                model.openTerminal()
            } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .quickHelp("Open Terminal here", text: $hoverHelpText)

            Toggle(isOn: $isPreviewVisible) {
                Image(systemName: "sidebar.right")
            }
            .toggleStyle(.button)
            .keyboardShortcut("p", modifiers: [.command, .option])
            .quickHelp(isPreviewVisible ? "Hide preview" : "Show preview", text: $hoverHelpText)

            Toggle(isOn: $isSplitViewVisible) {
                Image(systemName: "rectangle.split.2x1")
            }
            .toggleStyle(.button)
            .keyboardShortcut("s", modifiers: [.command, .option])
            .quickHelp(isSplitViewVisible ? "Use single pane" : "Use split panes", text: $hoverHelpText)

            Button {
                isFileListSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .quickHelp("File list settings", text: $hoverHelpText)

            Button {
                model.copyPath(model.currentDirectory)
            } label: {
                Image(systemName: "link")
            }
            .buttonStyle(.borderless)
            .quickHelp("Copy current path", text: $hoverHelpText)
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isFileListSettingsPresented) {
            FileListSettingsView(
                configurationRaw: $fileColumnConfigurationRaw
            )
        }
        .overlay(alignment: .bottomTrailing) {
            if !hoverHelpText.isEmpty {
                Text(hoverHelpText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .padding(.trailing, 10)
                    .padding(.bottom, 2)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var fileArea: some View {
        if isSplitViewVisible {
            GeometryReader { geometry in
                let totalWidth = max(geometry.size.width, 760)
                let dividerWidth: CGFloat = 1
                let availableWidth = max(300, totalWidth - dividerWidth)
                let leftWidth = clampedLeftFileWidth(availableWidth: availableWidth)
                let rightWidth = max(260, availableWidth - leftWidth)

                HStack(spacing: 0) {
                    filePane(.left)
                        .frame(width: leftWidth, height: geometry.size.height)

                    SplitDragHandle {
                        fileSplitDragStartRatio = fileSplitRatio
                    } onChanged: { translation in
                        let baseRatio = fileSplitDragStartRatio ?? fileSplitRatio
                        let availableWidthValue = Double(availableWidth)
                        let baseWidth = availableWidthValue * baseRatio
                        fileSplitRatio = clamp((baseWidth + translation) / availableWidthValue, min: 0.2, max: 0.8)
                    } onEnded: {
                        fileSplitDragStartRatio = nil
                    }

                    filePane(.right)
                        .frame(width: rightWidth, height: geometry.size.height)
                }
            }
        } else {
            filePane(activePane)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func clampedLeftFileWidth(availableWidth: CGFloat) -> CGFloat {
        let minPaneWidth = min(260.0, max(120.0, Double(availableWidth) / 2))
        let maxPaneWidth = max(minPaneWidth, Double(availableWidth) - minPaneWidth)
        return CGFloat(clamp(Double(availableWidth) * fileSplitRatio, min: minPaneWidth, max: maxPaneWidth))
    }

    private func filePane(_ paneID: BrowserPaneID) -> some View {
        let paneModel = paneID == .left ? leftModel : rightModel

        return FilePane(
            model: paneModel,
            paneID: paneID,
            isActivePane: activePane == paneID,
            isKeyboardTarget: activePane == paneID && activeArea == .files,
            fileNameColumnWidth: $fileNameColumnWidth,
            columnConfiguration: FileListColumnConfiguration(rawValue: fileColumnConfigurationRaw),
            activate: {
                activePane = paneID
                activeArea = .files
            },
            reloadRelatedPanes: reloadAllPanes
        )
    }

}

private struct SplitDragHandle: View {
    let onStarted: () -> Void
    let onChanged: (Double) -> Void
    let onEnded: () -> Void

    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.green.opacity(0.8) : Color(nsColor: .separatorColor))
            .frame(width: isDragging ? 3 : 1)
            .contentShape(Rectangle().inset(by: -4))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onStarted()
                        }
                        onChanged(Double(value.translation.width))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEnded()
                    }
            )
    }
}

private struct WindowFrameAutosaver: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            view.window?.setFrameAutosaveName(name)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.setFrameAutosaveName(name)
        }
    }
}

private struct KeyboardEventHandler: NSViewRepresentable {
    let isEnabled: Bool
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyHandlingNSView {
        let view = KeyHandlingNSView()
        view.onKeyDown = onKeyDown
        view.isEnabled = isEnabled
        return view
    }

    func updateNSView(_ nsView: KeyHandlingNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        nsView.isEnabled = isEnabled

        if isEnabled {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class KeyHandlingNSView: NSView {
    var isEnabled = true
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if isEnabled {
            DispatchQueue.main.async {
                self.window?.makeFirstResponder(self)
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        if isEnabled, onKeyDown?(event) == true {
            return
        }

        super.keyDown(with: event)
    }
}

private struct ScrollViewScrollerConfiguration: NSViewRepresentable {
    let axes: Axis.Set
    let autohidesScrollers: Bool

    func makeNSView(context: Context) -> ScrollerConfigurationView {
        ScrollerConfigurationView(axes: axes, autohidesScrollers: autohidesScrollers)
    }

    func updateNSView(_ nsView: ScrollerConfigurationView, context: Context) {
        nsView.axes = axes
        nsView.autohidesScrollers = autohidesScrollers
        nsView.configureEnclosingScrollView()
    }
}

private final class ScrollerConfigurationView: NSView {
    var axes: Axis.Set
    var autohidesScrollers: Bool

    init(axes: Axis.Set, autohidesScrollers: Bool) {
        self.axes = axes
        self.autohidesScrollers = autohidesScrollers
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        axes = []
        autohidesScrollers = true
        super.init(coder: coder)
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configureEnclosingScrollView()
    }

    func configureEnclosingScrollView() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let scrollView = self.enclosingScrollView else { return }
            if self.axes.contains(.horizontal) {
                scrollView.hasHorizontalScroller = true
            }
            if self.axes.contains(.vertical) {
                scrollView.hasVerticalScroller = true
            }
            scrollView.autohidesScrollers = self.autohidesScrollers
        }
    }
}

private extension View {
    func quickHelp(_ message: String, text: Binding<String>) -> some View {
        onHover { isHovering in
            text.wrappedValue = isHovering ? message : ""
        }
        .accessibilityHint(message)
    }
}

private enum FileListColumn: String, CaseIterable, Identifiable {
    case icon
    case mode
    case name
    case size
    case kind
    case modified
    case created
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .icon:
            return "Icon"
        case .mode:
            return "Mode"
        case .name:
            return "Name"
        case .size:
            return "Size"
        case .kind:
            return "Kind"
        case .modified:
            return "Modified"
        case .created:
            return "Created"
        case .permissions:
            return "Permissions"
        }
    }

    var headerTitle: String {
        switch self {
        case .icon:
            return "ICO"
        case .mode:
            return "MODE"
        case .name:
            return "NAME"
        case .size:
            return "SIZE"
        case .kind:
            return "KIND"
        case .modified:
            return "MODIFIED"
        case .created:
            return "CREATED"
        case .permissions:
            return "PERM"
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .icon:
            return 28
        case .mode:
            return 54
        case .name:
            return 320
        case .size:
            return 96
        case .kind:
            return 120
        case .modified, .created:
            return 160
        case .permissions:
            return 64
        }
    }

    var alignment: Alignment {
        switch self {
        case .size:
            return .trailing
        default:
            return .leading
        }
    }

    var canHide: Bool {
        self != .name
    }
}

private struct FileListColumnConfiguration {
    private(set) var orderedColumns: [FileListColumn]
    private(set) var visibleColumns: Set<FileListColumn>

    static let defaultColumns: [FileListColumn] = [.mode, .icon, .name, .size, .kind, .modified, .created, .permissions]
    static let defaultRawValue = defaultColumns.map { "\($0.rawValue):1" }.joined(separator: ",")

    init(rawValue: String) {
        var orderedColumns: [FileListColumn] = []
        var visibleColumns = Set<FileListColumn>()

        for component in rawValue.split(separator: ",") {
            let parts = component.split(separator: ":", maxSplits: 1).map(String.init)
            guard let rawColumn = parts.first, let column = FileListColumn(rawValue: rawColumn) else {
                continue
            }

            if !orderedColumns.contains(column) {
                orderedColumns.append(column)
            }

            let isVisible = parts.count < 2 || parts[1] != "0"
            if isVisible || column == .name {
                visibleColumns.insert(column)
            }
        }

        for column in Self.defaultColumns where !orderedColumns.contains(column) {
            orderedColumns.append(column)
            visibleColumns.insert(column)
        }

        visibleColumns.insert(.name)
        self.orderedColumns = orderedColumns
        self.visibleColumns = visibleColumns
    }

    var rawValue: String {
        orderedColumns
            .map { column in
                "\(column.rawValue):\(visibleColumns.contains(column) ? "1" : "0")"
            }
            .joined(separator: ",")
    }

    var visibleOrderedColumns: [FileListColumn] {
        orderedColumns.filter { visibleColumns.contains($0) }
    }

    func isVisible(_ column: FileListColumn) -> Bool {
        visibleColumns.contains(column)
    }

    mutating func setVisible(_ isVisible: Bool, for column: FileListColumn) {
        guard column.canHide else {
            visibleColumns.insert(column)
            return
        }

        if isVisible {
            visibleColumns.insert(column)
        } else {
            visibleColumns.remove(column)
        }
    }

    mutating func move(_ column: FileListColumn, direction: Int) {
        guard
            let currentIndex = orderedColumns.firstIndex(of: column)
        else {
            return
        }

        let nextIndex = min(max(currentIndex + direction, 0), orderedColumns.count - 1)
        guard nextIndex != currentIndex else { return }

        orderedColumns.remove(at: currentIndex)
        orderedColumns.insert(column, at: nextIndex)
    }

    mutating func reset() {
        orderedColumns = Self.defaultColumns
        visibleColumns = Set(Self.defaultColumns)
    }
}

private struct FileListSettingsView: View {
    @Binding var configurationRaw: String
    @Environment(\.dismiss) private var dismiss

    private var configuration: FileListColumnConfiguration {
        get {
            FileListColumnConfiguration(rawValue: configurationRaw)
        }
        nonmutating set {
            configurationRaw = newValue.rawValue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("File List Settings")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Columns")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)

                ForEach(configuration.orderedColumns) { column in
                    columnSettingRow(for: column)
                }
            }

            HStack {
                Button("Reset") {
                    var updated = configuration
                    updated.reset()
                    configuration = updated
                }

                Spacer()
            }
        }
        .padding(18)
        .frame(width: 420)
    }

    private func columnSettingRow(for column: FileListColumn) -> some View {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: {
                    configuration.isVisible(column)
                },
                set: { isVisible in
                    var updated = configuration
                    updated.setVisible(isVisible, for: column)
                    configuration = updated
                }
            )) {
                Text(column.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(!column.canHide)

            Button {
                var updated = configuration
                updated.move(column, direction: -1)
                configuration = updated
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(configuration.orderedColumns.first == column)
            .help("Move up")

            Button {
                var updated = configuration
                updated.move(column, direction: 1)
                configuration = updated
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(configuration.orderedColumns.last == column)
            .help("Move down")
        }
        .font(.system(size: 13, design: .monospaced))
        .padding(.vertical, 3)
    }
}

private struct FilePane: View {
    @ObservedObject var model: FileBrowserModel
    let paneID: BrowserPaneID
    let isActivePane: Bool
    let isKeyboardTarget: Bool
    @Binding var fileNameColumnWidth: Double
    let columnConfiguration: FileListColumnConfiguration
    let activate: () -> Void
    let reloadRelatedPanes: () -> Void
    @State private var nameColumnDragStartWidth: Double?

    private var visibleColumns: [FileListColumn] {
        columnConfiguration.visibleOrderedColumns
    }

    private var rowMinWidth: CGFloat {
        let columnsWidth = visibleColumns.reduce(0) { partialResult, column in
            partialResult + columnWidth(column)
        }
        let spacingWidth = max(0, visibleColumns.count - 1) * 12
        return columnsWidth + CGFloat(spacingWidth) + 24
    }

    var body: some View {
        VStack(spacing: 0) {
            paneTitle

            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    fileHeader

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ParentDirectoryRow(
                                    isEnabled: model.canGoUp,
                                    isSelected: model.isParentDirectorySelected,
                                    columns: visibleColumns,
                                    fileNameColumnWidth: fileNameColumnWidth
                                )
                                    .id(FileListRowID.parentDirectory)
                                    .contentShape(Rectangle())
                                    .simultaneousGesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { _ in
                                                activate()
                                                model.selectParentDirectory()
                                            }
                                    )
                                    .simultaneousGesture(
                                        TapGesture(count: 2)
                                            .onEnded {
                                                activate()
                                                model.selectParentDirectory()
                                                model.goUp()
                                            }
                                    )

                                ForEach(model.items) { item in
                                    FileRow(
                                        item: item,
                                        isSelected: model.isSelected(item),
                                        isDropTarget: item.isDirectory && model.isDropTargetDirectory(item.url),
                                        columns: visibleColumns,
                                        fileNameColumnWidth: fileNameColumnWidth
                                    )
                                        .id(FileListRowID.item(item.id))
                                        .contentShape(Rectangle())
                                        .overlay(
                                            FileRowInteractionOverlay(
                                                item: item,
                                                model: model,
                                                activate: activate
                                            )
                                        )
                                        .onDrop(
                                            of: [UTType.fileURL.identifier],
                                            delegate: FileDropDelegate(
                                                model: model,
                                                targetDirectory: item.isDirectory ? item.url : model.currentDirectory,
                                                highlightedDirectory: item.isDirectory ? item.url : nil,
                                                reloadRelatedPanes: {
                                                    activate()
                                                }
                                            )
                                        )
                                        .contextMenu {
                                            fileContextMenu(for: item)
                                        }
                                }
                            }
                        }
                        .onChange(of: model.selectedFileListRowID) {
                            scrollToSelection(with: proxy)
                        }
                        .onChange(of: isKeyboardTarget) {
                            if isKeyboardTarget {
                                scrollToSelection(with: proxy)
                            }
                        }
                    }
                    .background(Color.black)
                }
                .frame(minWidth: rowMinWidth)
            }
            .scrollIndicators(.visible, axes: .horizontal)
            .background(ScrollViewScrollerConfiguration(axes: .horizontal, autohidesScrollers: false))
            .onTapGesture {
                activate()
            }
            .onDrop(
                of: [UTType.fileURL.identifier],
                delegate: FileDropDelegate(
                    model: model,
                    targetDirectory: model.currentDirectory,
                    highlightedDirectory: nil,
                    reloadRelatedPanes: {
                        activate()
                    }
                )
            )
            .contextMenu {
                emptyFileAreaContextMenu
            }

            statusLine
        }
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isKeyboardTarget ? Color.green : (isActivePane ? Color.green.opacity(0.45) : Color.gray.opacity(0.35)), lineWidth: isKeyboardTarget ? 2 : 1)
        )
        .onAppear {
            model.prefetchVisibleMetadata(for: visibleColumns)
        }
        .onReceive(model.$items) { _ in
            model.prefetchVisibleMetadata(for: visibleColumns)
        }
        .onChange(of: columnConfiguration.rawValue) {
            model.prefetchVisibleMetadata(for: visibleColumns)
        }
    }

    private func scrollToSelection(with proxy: ScrollViewProxy) {
        guard let rowID = model.selectedFileListRowID else { return }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.08)) {
                proxy.scrollTo(rowID)
            }
        }
    }

    private var paneTitle: some View {
        HStack(spacing: 8) {
            Text(paneID.title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(isActivePane ? .black : .secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isActivePane ? Color.green : Color.gray.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))

            Text(model.currentDirectory.path(percentEncoded: false))
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isActivePane ? .green : .secondary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isKeyboardTarget ? Color.green.opacity(0.16) : (isActivePane ? Color.green.opacity(0.08) : Color(nsColor: .windowBackgroundColor)))
        .contentShape(Rectangle())
        .onTapGesture {
            activate()
        }
    }

    @ViewBuilder
    private var emptyFileAreaContextMenu: some View {
        Button("Paste Here") {
            activate()
            model.pasteItems()
        }
        .disabled(!model.canPaste)

        Button("New Folder") {
            activate()
            model.createFolder()
        }

        Button("Select All") {
            activate()
            model.selectAllVisibleItems()
        }
        .disabled(model.items.isEmpty)

        Divider()

        Button("Reveal in Finder") {
            activate()
            model.revealInFinder(model.currentDirectory)
        }

        Button(model.isFolderPinned(model.currentDirectory) ? "Unpin Folder" : "Pin Folder") {
            activate()
            model.togglePinnedFolder(model.currentDirectory)
        }

        Button("Open Terminal Here") {
            activate()
            model.openTerminal()
        }

        Button("Copy Current Path") {
            activate()
            model.copyPath(model.currentDirectory)
        }
    }

    @ViewBuilder
    private func fileContextMenu(for item: FileItem) -> some View {
        Button("Open") {
            activate()
            model.selectForContextMenu(item)
            model.open(item)
        }

        Button("Rename") {
            activate()
            model.selectForContextMenu(item)
            model.renameSelectedItem()
        }

        Button("Move to Trash") {
            activate()
            model.selectForContextMenu(item)
            model.moveSelectedItemsToTrash()
        }

        Button("Copy Items") {
            activate()
            model.selectForContextMenu(item)
            model.copySelectedItems()
        }

        Button("Cut Items") {
            activate()
            model.selectForContextMenu(item)
            model.cutSelectedItems()
        }

        Button("Paste Here") {
            activate()
            model.pasteItems(into: item.isDirectory ? item.url : model.currentDirectory)
        }
        .disabled(!model.canPaste)

        Divider()

        Button("Reveal in Finder") {
            activate()
            model.selectForContextMenu(item)
            model.revealSelectedItemsInFinder()
        }

        Button("Copy Path") {
            model.copyPath(item.url)
        }

        if item.isDirectory {
            Button(model.isFolderPinned(item.url) ? "Unpin Folder" : "Pin Folder") {
                activate()
                model.togglePinnedFolder(item.url)
            }

            Button("Open Terminal Here") {
                activate()
                model.openTerminal(at: item.url)
            }
        }
    }

    private var fileHeader: some View {
        HStack(spacing: 12) {
            ForEach(visibleColumns) { column in
                headerCell(for: column)
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundStyle(.green)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black)
    }

    @ViewBuilder
    private func headerCell(for column: FileListColumn) -> some View {
        if column == .name {
            HStack(spacing: 4) {
                Text(column.headerTitle)
                Spacer(minLength: 4)
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green.opacity(0.75))
            }
            .frame(width: columnWidth(column), alignment: column.alignment)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if nameColumnDragStartWidth == nil {
                            nameColumnDragStartWidth = fileNameColumnWidth
                        }

                        let baseWidth = nameColumnDragStartWidth ?? fileNameColumnWidth
                        fileNameColumnWidth = clampFileNameColumnWidth(baseWidth + Double(value.translation.width))
                    }
                    .onEnded { _ in
                        nameColumnDragStartWidth = nil
                    }
            )
            .help("Drag to resize file name column")
        } else {
            Text(column.headerTitle)
                .frame(width: columnWidth(column), alignment: column.alignment)
        }
    }

    private func columnWidth(_ column: FileListColumn) -> CGFloat {
        column == .name ? CGFloat(fileNameColumnWidth) : column.defaultWidth
    }

    private func clampFileNameColumnWidth(_ width: Double) -> Double {
        min(max(width, 160), 720)
    }

    private var statusLine: some View {
        HStack {
            Text("\(model.items.count) of \(model.allItemCount) items")
            Text("| Free \(model.availableCapacityText)")
            if model.selectionCount > 0 {
                Text("| \(model.selectionCount) selected")
            }
            Spacer()
            Text(model.primarySelectedItem?.url.path(percentEncoded: false) ?? "No selection")
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(isKeyboardTarget ? .green : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture {
            activate()
        }
    }
}

private struct ParentDirectoryRow: View {
    let isEnabled: Bool
    let isSelected: Bool
    let columns: [FileListColumn]
    let fileNameColumnWidth: Double

    var body: some View {
        HStack(spacing: 12) {
            ForEach(columns) { column in
                parentCell(for: column)
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(isSelected ? Color.green.opacity(0.35) : Color.black)
        .opacity(isEnabled ? 1 : 0.45)
    }

    @ViewBuilder
    private func parentCell(for column: FileListColumn) -> some View {
        switch column {
        case .icon:
            Image(systemName: "arrow.turn.up.left")
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(isEnabled ? .cyan : .secondary)
        case .mode:
            Text("drwx")
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(isEnabled ? .cyan : .secondary)
        case .name:
            Text("..")
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(isEnabled ? .cyan : .secondary)
        case .size:
            Text("-")
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        case .kind:
            Text("Parent Folder")
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        case .modified, .created, .permissions:
            Text("-")
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        }
    }

    private func columnWidth(_ column: FileListColumn) -> CGFloat {
        column == .name ? CGFloat(fileNameColumnWidth) : column.defaultWidth
    }
}

private struct FolderTreePane: View {
    @ObservedObject var model: FileBrowserModel
    let isActive: Bool
    let activate: () -> Void

    private var roots: [URL] {
        [URL(fileURLWithPath: "/").standardizedFileURL]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FOLDERS")
                Spacer()
                Button {
                    model.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Reload")
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isActive ? Color.green.opacity(0.16) : Color.black)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !model.pinnedFolders.isEmpty {
                            FolderTreeSectionHeader(title: "PINNED")

                            ForEach(Array(model.pinnedFolders.enumerated()), id: \.element) { index, pinnedFolder in
                                PinnedFolderInsertionSlot(isVisible: model.isPinnedFolderInsertionSlotVisible(at: index))

                                PinnedFolderTreeRow(
                                    model: model,
                                    url: pinnedFolder,
                                    isTreeActive: isActive,
                                    activateTree: activate
                                )
                            }

                            PinnedFolderInsertionSlot(isVisible: model.isPinnedFolderInsertionSlotVisible(at: model.pinnedFolders.count))

                            FolderTreeSectionHeader(title: "FOLDERS")
                        }

                        ForEach(roots, id: \.self) { root in
                            FolderTreeRow(
                                model: model,
                                url: root,
                                depth: 0,
                                isTreeActive: isActive,
                                selectionSection: .tree,
                                activateTree: activate
                            )
                        }
                    }
                }
                .onChange(of: model.folderTreeSelection) {
                    scrollToSelection(with: proxy)
                }
                .onChange(of: model.folderTreeSelectionSection) {
                    scrollToSelection(with: proxy)
                }
                .onChange(of: isActive) {
                    if isActive {
                        scrollToSelection(with: proxy)
                    }
                }
            }
            .background(Color.black)
            .contentShape(Rectangle())
            .onTapGesture {
                activate()
                model.ensureFolderTreeSelection()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isActive ? Color.green : Color.gray.opacity(0.35), lineWidth: isActive ? 2 : 1)
        )
    }

    private func scrollToSelection(with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.08)) {
                proxy.scrollTo(model.selectedFolderTreeRowID)
            }
        }
    }
}

private struct PinnedFolderTreeRow: View {
    @ObservedObject var model: FileBrowserModel
    let url: URL
    let isTreeActive: Bool
    let activateTree: () -> Void
    @State private var rowHeight: CGFloat = 26
    @State private var dragTranslationY: CGFloat = 0

    var body: some View {
        FolderTreeRow(
            model: model,
            url: url,
            depth: 0,
            isTreeActive: isTreeActive,
            selectionSection: .pinned,
            allowsExpansion: false,
            activateTree: activateTree
        )
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            rowHeight = proxy.size.height
                        }
                        .onChange(of: proxy.size.height) {
                            rowHeight = proxy.size.height
                        }
                }
            )
            .offset(y: dragTranslationY)
            .opacity(model.isDraggingPinnedFolder(url) ? 0.82 : 1)
            .zIndex(model.isDraggingPinnedFolder(url) ? 1 : 0)
            .highPriorityGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        model.beginPinnedFolderDrag(url)
                        dragTranslationY = value.translation.height
                        model.updateDraggedPinnedFolder(translationY: value.translation.height, rowHeight: rowHeight)
                    }
                    .onEnded { _ in
                        dragTranslationY = 0
                        model.finishPinnedFolderDrag(applyingMove: true)
                    }
            )
            .help("Drag to reorder pinned folders")
    }
}

private struct PinnedFolderInsertionSlot: View {
    let isVisible: Bool

    var body: some View {
        Rectangle()
            .fill(Color.green.opacity(isVisible ? 0.75 : 0))
            .frame(height: isVisible ? 10 : 0)
            .padding(.horizontal, isVisible ? 10 : 0)
            .animation(.easeOut(duration: 0.08), value: isVisible)
    }
}

private struct FolderTreeSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.green.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.top, 9)
            .padding(.bottom, 4)
            .background(Color.black)
    }
}

private struct FolderTreeRow: View {
    @ObservedObject var model: FileBrowserModel
    let url: URL
    let depth: Int
    let isTreeActive: Bool
    let selectionSection: FolderTreeSelectionSection
    var allowsExpansion = true
    let activateTree: () -> Void

    private var isCurrent: Bool {
        model.currentDirectory.standardizedFileURL == url.standardizedFileURL
    }

    private var isSelected: Bool {
        model.isFolderTreeSelected(url, in: selectionSection)
    }

    private var isExpanded: Bool {
        model.isFolderExpanded(url)
    }

    private var hasChildFolders: Bool {
        model.hasFolderChildren(url)
    }

    private var showsExpansionControl: Bool {
        allowsExpansion && hasChildFolders
    }

    private var isDropTarget: Bool {
        model.isDropTargetDirectory(url)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    guard showsExpansionControl else { return }
                    activateTree()
                    model.selectFolderTree(url, in: selectionSection)
                    model.toggleFolderExpansion(url)
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .frame(width: 14)
                .opacity(showsExpansionControl ? 1 : 0)
                .disabled(!showsExpansionControl)
                .help(isExpanded ? "Collapse" : "Expand")

                Image(systemName: "folder")
                    .foregroundStyle(.cyan)
                    .frame(width: 16)

                Text(displayName(for: url))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle((isCurrent || isSelected) ? .white : .primary)
            .padding(.leading, CGFloat(depth * 14 + 8))
            .padding(.trailing, 8)
            .padding(.vertical, 5)
            .background(rowBackground)
            .id(FolderTreeRowID(url: url, section: selectionSection))
            .contentShape(Rectangle())
            .onTapGesture {
                let shouldCollapse = showsExpansionControl && isExpanded
                activateTree()
                model.selectFolderTree(url, in: selectionSection)
                model.navigate(to: url)
                if shouldCollapse {
                    model.toggleFolderExpansion(url)
                }
            }
            .contextMenu {
                Button("Open") {
                    activateTree()
                    model.selectFolderTree(url, in: selectionSection)
                    model.navigate(to: url)
                    if allowsExpansion {
                        model.expandFolder(url)
                    }
                }

                Button("Reveal in Finder") {
                    model.revealInFinder(url)
                }

                Button("Copy Path") {
                    model.copyPath(url)
                }

                Button(model.isFolderPinned(url) ? "Unpin Folder" : "Pin Folder") {
                    activateTree()
                    model.selectFolderTree(url, in: selectionSection)
                    model.togglePinnedFolder(url)
                }

                Button("Open Terminal Here") {
                    model.openTerminal(at: url)
                }
            }
            .onDrop(
                of: [UTType.fileURL.identifier],
                delegate: FileDropDelegate(
                    model: model,
                    targetDirectory: url,
                    highlightedDirectory: url,
                    reloadRelatedPanes: {
                        activateTree()
                        model.selectFolderTree(url, in: selectionSection)
                    }
                )
            )

            if allowsExpansion && isExpanded {
                ForEach(model.childrenForFolder(url), id: \.self) { child in
                    FolderTreeRow(
                        model: model,
                        url: child,
                        depth: depth + 1,
                        isTreeActive: isTreeActive,
                        selectionSection: .tree,
                        activateTree: activateTree
                    )
                }
            }
        }
        .onChange(of: model.items) {
            if allowsExpansion && isExpanded {
                model.refreshFolderChildren(url)
            }
        }
        .onAppear {
            if allowsExpansion {
                model.refreshFolderChildrenIfNeeded(url)
            }
        }
    }

    private func displayName(for url: URL) -> String {
        FolderDisplayNameCache.shared.displayName(for: url)
    }

    private var rowBackground: Color {
        if isDropTarget {
            return Color.green.opacity(0.55)
        }

        if isTreeActive && isSelected {
            return Color.green.opacity(0.45)
        }

        if isSelected {
            return Color.gray.opacity(0.35)
        }

        return Color.black
    }
}

private struct FileRow: View {
    let item: FileItem
    let isSelected: Bool
    let isDropTarget: Bool
    let columns: [FileListColumn]
    let fileNameColumnWidth: Double

    var body: some View {
        HStack(spacing: 12) {
            ForEach(columns) { column in
                fileCell(for: column)
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(rowBackground)
    }

    @ViewBuilder
    private func fileCell(for column: FileListColumn) -> some View {
        switch column {
        case .icon:
            FileIcon(url: item.url, cacheKey: item.iconCacheKey)
                .frame(width: columnWidth(column), alignment: column.alignment)
        case .mode:
            Text(item.mode)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(item.isDirectory ? .cyan : .secondary)
        case .name:
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(item.isDirectory ? .cyan : .primary)
        case .size:
            Text(item.sizeText)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        case .kind:
            Text(item.kindText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        case .modified:
            Text(item.modifiedText)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        case .created:
            Text(item.createdText)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        case .permissions:
            Text(item.permissionsText)
                .frame(width: columnWidth(column), alignment: column.alignment)
                .foregroundStyle(.secondary)
        }
    }

    private func columnWidth(_ column: FileListColumn) -> CGFloat {
        column == .name ? CGFloat(fileNameColumnWidth) : column.defaultWidth
    }

    private var rowBackground: Color {
        if isDropTarget {
            return Color.green.opacity(0.55)
        }

        if isSelected {
            return Color.accentColor.opacity(0.55)
        }

        return Color.black
    }
}

private struct FileRowInteractionOverlay: NSViewRepresentable {
    let item: FileItem
    let model: FileBrowserModel
    let activate: () -> Void

    func makeNSView(context: Context) -> FileRowInteractionView {
        FileRowInteractionView(item: item, model: model, activate: activate)
    }

    func updateNSView(_ nsView: FileRowInteractionView, context: Context) {
        nsView.item = item
        nsView.model = model
        nsView.activate = activate
    }
}

private final class FileRowInteractionView: NSView, NSDraggingSource {
    var item: FileItem
    weak var model: FileBrowserModel?
    var activate: () -> Void
    private var mouseDownEvent: NSEvent?
    private var hasStartedDrag = false

    init(item: FileItem, model: FileBrowserModel, activate: @escaping () -> Void) {
        self.item = item
        self.model = model
        self.activate = activate
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        item = FileItem(url: URL(fileURLWithPath: "/"))
        activate = {}
        super.init(coder: coder)
    }

    override func mouseDown(with event: NSEvent) {
        activate()
        mouseDownEvent = event
        hasStartedDrag = false

        if event.clickCount >= 2 {
            model?.select(item)
            model?.open(item)
            return
        }

        model?.selectForMouseDown(item, modifiers: event.modifierFlags)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag, let mouseDownEvent, let model else { return }
        hasStartedDrag = true

        let dragItems = model.dragItemsForFileRow(item)
        guard !dragItems.isEmpty else { return }

        let draggingItems = dragItems.map { dragItem in
            let item = NSDraggingItem(pasteboardWriter: dragItem.url as NSURL)
            item.setDraggingFrame(
                NSRect(x: bounds.midX - 16, y: bounds.midY - 16, width: 32, height: 32),
                contents: FileIconCache.shared.icon(for: dragItem.url, cacheKey: dragItem.iconCacheKey, size: 32)
            )
            return item
        }
        beginDraggingSession(with: draggingItems, event: mouseDownEvent, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard !hasStartedDrag else { return }
        model?.selectForMouseUp(item, modifiers: event.modifierFlags)
    }

    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : [.copy, .move]
    }
}

private struct FileIcon: View {
    let url: URL
    var cacheKey: String? = nil

    var body: some View {
        Image(nsImage: FileIconCache.shared.icon(for: url, cacheKey: cacheKey))
            .resizable()
            .frame(width: 18, height: 18)
            .accessibilityHidden(true)
    }
}

private final class FilePermissionCache {
    static let shared = FilePermissionCache()

    nonisolated(unsafe) private let cache = NSCache<NSString, NSNumber>()

    nonisolated func permissions(for url: URL) -> Int? {
        let key = NSString(string: url.path)
        if let cachedPermissions = cache.object(forKey: key) {
            return cachedPermissions.intValue
        }

        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        else {
            return nil
        }

        cache.setObject(NSNumber(value: permissions), forKey: key)
        return permissions
    }

    nonisolated func prefetch(for urls: [URL], cancellation: MetadataPrefetchCancellation) {
        for (index, url) in urls.enumerated() {
            if index.isMultiple(of: 64), cancellation.isCancelled {
                return
            }

            _ = permissions(for: url)
        }
    }
}

private final class FileKindCache {
    static let shared = FileKindCache()

    nonisolated(unsafe) private let cache = NSCache<NSString, NSString>()

    nonisolated func kind(for url: URL, isDirectory: Bool) -> String {
        let key = NSString(string: url.path)
        if let cachedKind = cache.object(forKey: key) {
            return cachedKind as String
        }

        let values = try? url.resourceValues(forKeys: [.localizedTypeDescriptionKey])
        let kind = values?.localizedTypeDescription ?? (isDirectory ? "Folder" : url.pathExtension.uppercased())
        cache.setObject(NSString(string: kind), forKey: key)
        return kind
    }

    nonisolated func prefetch(for items: [FileItem], cancellation: MetadataPrefetchCancellation) {
        for (index, item) in items.enumerated() {
            if index.isMultiple(of: 64), cancellation.isCancelled {
                return
            }

            _ = kind(for: item.url, isDirectory: item.isDirectory)
        }
    }
}

private final class FolderDisplayNameCache: @unchecked Sendable {
    nonisolated static let shared = FolderDisplayNameCache()

    nonisolated(unsafe) private let cache = NSCache<NSString, NSString>()

    private init() {}

    nonisolated func displayName(for url: URL) -> String {
        if url.path == "/" {
            return "/"
        }

        let key = NSString(string: url.standardizedFileURL.path)
        if let cachedName = cache.object(forKey: key) {
            return cachedName as String
        }

        let displayName = FileManager.default.displayName(atPath: url.path)
        let resolvedName = displayName.isEmpty ? url.lastPathComponent : displayName
        cache.setObject(NSString(string: resolvedName), forKey: key)
        return resolvedName
    }
}

private final class FileDisplayTextCache: @unchecked Sendable {
    nonisolated static let shared = FileDisplayTextCache()

    nonisolated(unsafe) private let sizeCache = NSCache<NSNumber, NSString>()
    nonisolated(unsafe) private let dateCache = NSCache<NSString, NSString>()
    nonisolated(unsafe) private let sizeFormatter = ByteCountFormatter()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    private let sizeLock = NSLock()
    private let dateLock = NSLock()

    private init() {
        sizeFormatter.countStyle = .file
    }

    nonisolated func sizeText(byteCount: Int64) -> String {
        let key = NSNumber(value: byteCount)
        if let cachedText = sizeCache.object(forKey: key) {
            return cachedText as String
        }

        sizeLock.lock()
        let text = sizeFormatter.string(fromByteCount: byteCount)
        sizeLock.unlock()
        sizeCache.setObject(NSString(string: text), forKey: key)
        return text
    }

    nonisolated func dateText(for date: Date?) -> String {
        guard let date else { return "-" }

        let key = NSString(string: String(format: "%.0f", date.timeIntervalSinceReferenceDate))
        if let cachedText = dateCache.object(forKey: key) {
            return cachedText as String
        }

        dateLock.lock()
        let text = dateFormatter.string(from: date)
        dateLock.unlock()
        dateCache.setObject(NSString(string: text), forKey: key)
        return text
    }
}

private final class FileIconCache: @unchecked Sendable {
    nonisolated static let shared = FileIconCache()

    nonisolated(unsafe) private let cache = NSCache<NSString, NSImage>()

    nonisolated func icon(for url: URL, cacheKey: String?, size: CGFloat = 18) -> NSImage {
        let key = NSString(string: "\(cacheKey ?? "path:\(url.path)"):\(Int(size))")
        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        cache.setObject(icon, forKey: key)
        return icon
    }

    nonisolated func prefetch(for items: [FileItem], cancellation: MetadataPrefetchCancellation) {
        for (index, item) in items.enumerated() {
            if index.isMultiple(of: 64), cancellation.isCancelled {
                return
            }

            _ = icon(for: item.url, cacheKey: item.iconCacheKey)
        }
    }
}

private struct PreviewPane: View {
    let urls: [URL]
    @State private var selectedPreviewURLs: Set<URL> = []
    @State private var visibleMultiPreviewURLs: Set<URL> = []
    @State private var activeMultiPreviewURLs: Set<URL> = []
    private let maxActiveMultiPreviews = 3

    var body: some View {
        Group {
            if urls.count == 1, let url = urls.first {
                preview(for: url)
            } else if !urls.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(urls, id: \.self) { url in
                            MultiPreviewItem(
                                url: url,
                                isSelected: selectedPreviewURLs.contains(url.standardizedFileURL),
                                isPreviewActive: activeMultiPreviewURLs.contains(url.standardizedFileURL),
                                selectedURLs: $selectedPreviewURLs,
                                requestPreview: {
                                    requestMultiPreview(for: url)
                                },
                                releasePreview: {
                                    releaseMultiPreview(for: url)
                                }
                            ) {
                                preview(for: url)
                            }
                        }
                    }
                    .padding(10)
                }
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28))
                    Text("No preview")
                }
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .onChange(of: urls) {
            let availableURLs = Set(urls.map(\.standardizedFileURL))
            selectedPreviewURLs = selectedPreviewURLs.intersection(availableURLs)
            visibleMultiPreviewURLs = visibleMultiPreviewURLs.intersection(availableURLs)
            updateActiveMultiPreviews()
        }
    }

    private func requestMultiPreview(for url: URL) {
        visibleMultiPreviewURLs.insert(url.standardizedFileURL)
        updateActiveMultiPreviews()
    }

    private func releaseMultiPreview(for url: URL) {
        visibleMultiPreviewURLs.remove(url.standardizedFileURL)
        updateActiveMultiPreviews()
    }

    private func updateActiveMultiPreviews() {
        activeMultiPreviewURLs = Set(
            urls
                .map(\.standardizedFileURL)
                .filter { visibleMultiPreviewURLs.contains($0) }
                .prefix(maxActiveMultiPreviews)
        )
    }

    @ViewBuilder
    private func preview(for url: URL) -> some View {
        switch PreviewKindCache.shared.kind(for: url) {
        case .pdf:
            PDFPreview(url: url)
        case .video:
            VideoPreview(url: url)
        case .markdown:
            MarkdownPreview(url: url)
        case .quickLook:
            QuickLookPreview(url: url)
        }
    }
}

private struct MultiPreviewItem<Content: View>: View {
    let url: URL
    let isSelected: Bool
    let isPreviewActive: Bool
    @Binding var selectedURLs: Set<URL>
    let requestPreview: () -> Void
    let releasePreview: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                FileIcon(url: url)
                Text(displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Group {
                if isPreviewActive {
                    content()
                } else {
                    DeferredPreviewPlaceholder(url: url)
                }
            }
            .frame(height: 220)
            .clipped()
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.green : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            PreviewDragSelectionOverlay(url: url, selectedURLs: $selectedURLs)
        )
        .onAppear(perform: requestPreview)
        .onDisappear(perform: releasePreview)
    }

    private var displayName: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }
}

private struct DeferredPreviewPlaceholder: View {
    let url: URL

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 24))
            Text("Preview queued")
                .font(.system(size: 12, design: .monospaced))
            Text(displayName)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var displayName: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }

    private var iconName: String {
        switch PreviewKindCache.shared.kind(for: url) {
        case .pdf:
            return "doc.richtext"
        case .video:
            return "film"
        case .markdown:
            return "doc.text"
        case .quickLook:
            return "doc"
        }
    }
}

private struct PreviewDragSelectionOverlay: NSViewRepresentable {
    let url: URL
    @Binding var selectedURLs: Set<URL>

    func makeNSView(context: Context) -> PreviewDragSelectionView {
        PreviewDragSelectionView(url: url, selectedURLs: $selectedURLs)
    }

    func updateNSView(_ nsView: PreviewDragSelectionView, context: Context) {
        nsView.url = url
        nsView.selectedURLs = $selectedURLs
    }
}

private final class PreviewDragSelectionView: NSView, NSDraggingSource {
    var url: URL
    var selectedURLs: Binding<Set<URL>>
    private var mouseDownEvent: NSEvent?
    private var hasStartedDrag = false

    init(url: URL, selectedURLs: Binding<Set<URL>>) {
        self.url = url
        self.selectedURLs = selectedURLs
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        url = URL(fileURLWithPath: "/")
        selectedURLs = .constant([])
        super.init(coder: coder)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        hasStartedDrag = false

        let key = url.standardizedFileURL
        if event.modifierFlags.contains(.command) {
            if selectedURLs.wrappedValue.contains(key) {
                selectedURLs.wrappedValue.remove(key)
            } else {
                selectedURLs.wrappedValue.insert(key)
            }
        } else if !selectedURLs.wrappedValue.contains(key) {
            selectedURLs.wrappedValue = [key]
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag, let mouseDownEvent else { return }
        hasStartedDrag = true

        let key = url.standardizedFileURL
        let dragURLs: [URL]
        if selectedURLs.wrappedValue.contains(key) {
            dragURLs = selectedURLs.wrappedValue.sorted {
                $0.path < $1.path
            }
        } else {
            selectedURLs.wrappedValue = [key]
            dragURLs = [key]
        }

        let draggingItems = dragURLs.map { dragURL in
            let item = NSDraggingItem(pasteboardWriter: dragURL as NSURL)
            item.setDraggingFrame(
                NSRect(x: bounds.midX - 16, y: bounds.midY - 16, width: 32, height: 32),
                contents: FileIconCache.shared.icon(for: dragURL, cacheKey: nil, size: 32)
            )
            return item
        }
        beginDraggingSession(with: draggingItems, event: mouseDownEvent, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard !hasStartedDrag, !event.modifierFlags.contains(.command) else { return }
        selectedURLs.wrappedValue = [url.standardizedFileURL]
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : [.copy, .move]
    }
}

private struct PDFPreview: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        guard context.coordinator.currentURL != url else { return }

        context.coordinator.cancellation?.cancel()
        let cancellation = PreviewLoadCancellation()
        context.coordinator.cancellation = cancellation
        context.coordinator.currentURL = url
        context.coordinator.generation += 1
        let generation = context.coordinator.generation
        let targetURL = url
        nsView.document = nil

        DispatchQueue.global(qos: .userInitiated).async {
            guard !cancellation.isCancelled else { return }
            let document = PDFDocument(url: targetURL)
            guard !cancellation.isCancelled else { return }

            DispatchQueue.main.async {
                guard context.coordinator.generation == generation, !cancellation.isCancelled else { return }
                nsView.document = document
            }
        }
    }

    static func dismantleNSView(_ nsView: PDFView, coordinator: Coordinator) {
        coordinator.generation += 1
        coordinator.cancellation?.cancel()
        coordinator.cancellation = nil
        nsView.document = nil
    }

    final class Coordinator {
        var currentURL: URL?
        var generation = 0
        var cancellation: PreviewLoadCancellation?
    }
}

private struct VideoPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        let currentURL = (nsView.player?.currentItem?.asset as? AVURLAsset)?.url
        if currentURL != url {
            nsView.player = AVPlayer(url: url)
        }
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player?.pause()
        nsView.player = nil
    }
}

private struct MarkdownPreview: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard context.coordinator.currentURL != url else { return }

        context.coordinator.cancellation?.cancel()
        let cancellation = PreviewLoadCancellation()
        context.coordinator.cancellation = cancellation
        context.coordinator.currentURL = url
        context.coordinator.generation += 1
        let generation = context.coordinator.generation
        let targetURL = url

        nsView.loadHTMLString(Self.loadingHTML, baseURL: nil)

        DispatchQueue.global(qos: .userInitiated).async {
            guard !cancellation.isCancelled else { return }
            let markdown = (try? String(contentsOf: targetURL, encoding: .utf8))
                ?? String(decoding: ((try? Data(contentsOf: targetURL)) ?? Data()), as: UTF8.self)
            guard !cancellation.isCancelled else { return }
            guard let html = Self.htmlDocument(for: markdown, cancellation: cancellation) else { return }

            DispatchQueue.main.async {
                guard context.coordinator.generation == generation, !cancellation.isCancelled else { return }
                nsView.loadHTMLString(html, baseURL: targetURL.deletingLastPathComponent())
            }
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.generation += 1
        coordinator.cancellation?.cancel()
        coordinator.cancellation = nil
        nsView.stopLoading()
        nsView.loadHTMLString(Self.loadingHTML, baseURL: nil)
    }

    final class Coordinator {
        var currentURL: URL?
        var generation = 0
        var cancellation: PreviewLoadCancellation?
    }

    private static let loadingHTML = """
    <!doctype html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
    :root { color-scheme: light dark; }
    body {
      margin: 0;
      padding: 20px;
      font: -apple-system-body;
      color: color-mix(in srgb, CanvasText 55%, Canvas);
      background: Canvas;
    }
    </style>
    </head>
    <body>Loading preview...</body>
    </html>
    """

    private static func htmlDocument(for markdown: String, cancellation: PreviewLoadCancellation) -> String? {
        guard !cancellation.isCancelled else { return nil }
        guard let body = markdownToHTML(markdown, cancellation: cancellation) else { return nil }
        guard !cancellation.isCancelled else { return nil }

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        :root { color-scheme: light dark; }
        body {
          margin: 0;
          padding: 20px;
          font: -apple-system-body;
          line-height: 1.55;
          color: CanvasText;
          background: Canvas;
        }
        code, pre {
          font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
        }
        pre {
          padding: 12px;
          overflow: auto;
          border-radius: 6px;
          background: color-mix(in srgb, CanvasText 8%, Canvas);
        }
        blockquote {
          margin-left: 0;
          padding-left: 14px;
          border-left: 3px solid color-mix(in srgb, CanvasText 35%, Canvas);
          color: color-mix(in srgb, CanvasText 75%, Canvas);
        }
        img { max-width: 100%; height: auto; }
        a { color: LinkText; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static func markdownToHTML(_ markdown: String, cancellation: PreviewLoadCancellation) -> String? {
        var html: [String] = []
        var paragraph: [String] = []
        var listItems: [String] = []
        var codeBlock: [String] = []
        var isInCodeBlock = false

        func flushParagraph() {
            guard !cancellation.isCancelled else { return }
            guard !paragraph.isEmpty else { return }
            html.append("<p>\(inlineHTML(paragraph.joined(separator: " ")))</p>")
            paragraph.removeAll()
        }

        func flushList() {
            guard !cancellation.isCancelled else { return }
            guard !listItems.isEmpty else { return }
            html.append("<ul>\(listItems.joined())</ul>")
            listItems.removeAll()
        }

        func flushCodeBlock() {
            guard !cancellation.isCancelled else { return }
            guard !codeBlock.isEmpty else { return }
            html.append("<pre><code>\(escapeHTML(codeBlock.joined(separator: "\n")))</code></pre>")
            codeBlock.removeAll()
        }

        for (index, rawLine) in markdown.components(separatedBy: .newlines).enumerated() {
            if index.isMultiple(of: 50), cancellation.isCancelled {
                return nil
            }

            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if isInCodeBlock {
                    flushCodeBlock()
                    isInCodeBlock = false
                } else {
                    flushParagraph()
                    flushList()
                    isInCodeBlock = true
                }
                continue
            }

            if isInCodeBlock {
                codeBlock.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushParagraph()
                flushList()
            } else if let heading = headingHTML(for: line) {
                flushParagraph()
                flushList()
                html.append(heading)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                listItems.append("<li>\(inlineHTML(String(line.dropFirst(2))))</li>")
            } else if line.hasPrefix("> ") {
                flushParagraph()
                flushList()
                html.append("<blockquote>\(inlineHTML(String(line.dropFirst(2))))</blockquote>")
            } else {
                flushList()
                paragraph.append(line)
            }
        }

        if isInCodeBlock {
            flushCodeBlock()
        }
        flushParagraph()
        flushList()

        guard !cancellation.isCancelled else { return nil }
        return html.joined(separator: "\n")
    }

    private static func headingHTML(for line: String) -> String? {
        let markerCount = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(markerCount), line.dropFirst(markerCount).hasPrefix(" ") else {
            return nil
        }

        let level = markerCount
        let text = line.dropFirst(markerCount + 1)
        return "<h\(level)>\(inlineHTML(String(text)))</h\(level)>"
    }

    private static func inlineHTML(_ text: String) -> String {
        var html = escapeHTML(text)
        html = html.replacingOccurrences(of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "<em>$1</em>", options: .regularExpression)
        html = html.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#,
            with: #"<a href="$2">$1</a>"#,
            options: .regularExpression
        )
        return html
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = true
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        guard context.coordinator.currentURL != url else { return }
        context.coordinator.currentURL = url
        nsView.previewItem = url as NSURL
    }

    static func dismantleNSView(_ nsView: QLPreviewView, coordinator: Coordinator) {
        coordinator.currentURL = nil
        nsView.previewItem = nil
    }

    final class Coordinator {
        var currentURL: URL?
    }
}

private enum PreviewKind {
    case pdf
    case video
    case markdown
    case quickLook

    nonisolated init(url: URL) {
        let extensionName = url.pathExtension.lowercased()
        let type = UTType(filenameExtension: extensionName)

        if ["md", "markdown", "mdown", "mkd"].contains(extensionName) {
            self = .markdown
        } else if type?.conforms(to: .pdf) == true {
            self = .pdf
        } else if type?.conforms(to: .movie) == true {
            self = .video
        } else {
            self = .quickLook
        }
    }
}

private final class PreviewKindCache: @unchecked Sendable {
    nonisolated static let shared = PreviewKindCache()

    nonisolated(unsafe) private var cache: [String: PreviewKind] = [:]
    private let lock = NSLock()

    private init() {}

    nonisolated func kind(for url: URL) -> PreviewKind {
        let key = url.pathExtension.lowercased()
        lock.lock()
        if let cachedKind = cache[key] {
            lock.unlock()
            return cachedKind
        }
        lock.unlock()

        let kind = PreviewKind(url: url)
        lock.lock()
        cache[key] = kind
        lock.unlock()
        return kind
    }
}

private final class FileBrowserModel: ObservableObject {
    @Published var currentDirectory = URL(fileURLWithPath: NSHomeDirectory())
    @Published var items: [FileItem] = [] {
        didSet {
            rebuildVisibleItemIndexes()
        }
    }
    @Published var selectedItemIDs: Set<FileItem.ID> = [] {
        didSet {
            refreshPreviewURLs()
        }
    }
    @Published var primarySelectedItemID: FileItem.ID?
    @Published var isParentDirectorySelected = false {
        didSet {
            refreshPreviewURLs()
        }
    }
    @Published var folderTreeSelection: URL?
    @Published var folderTreeSelectionSection: FolderTreeSelectionSection = .tree
    @Published var isShowingError = false
    @Published var errorMessage = ""
    @Published var searchText = "" {
        didSet {
            scheduleFilterAndSort()
        }
    }
    @Published var showHiddenFiles = false {
        didSet {
            applyFiltersAndSortImmediately()
        }
    }
    @Published var sortKey = FileSortKey.fastName {
        didSet {
            applyFiltersAndSortImmediately()
        }
    }
    @Published var sortAscending = true {
        didSet {
            applyFiltersAndSortImmediately()
        }
    }
    @Published private var expandedFolders: Set<URL> = []
    @Published private var folderChildrenCache: [URL: [URL]] = [:]
    @Published private(set) var availableCapacityText = "-"
    @Published private(set) var pinnedFolders: [URL] = []
    @Published private(set) var pinnedFolderInsertionIndex: Int?
    @Published private(set) var highlightedDropDirectory: URL?
    @Published private(set) var previewURLs: [URL] = []

    private var allItems: [FileItem] = []
    private var allItemLookup: [FileItem.ID: FileItem] = [:]
    private var visibleItemIndexLookup: [FileItem.ID: Int] = [:]
    private var backStack: [URL] = []
    private var forwardStack: [URL] = []
    private var selectionAnchorItemID: FileItem.ID?
    private var clipboard: FileClipboard?
    private var draggedPinnedFolder: URL?
    private var draggedPinnedFolderOriginalIndex: Int?
    private var filterWorkItem: DispatchWorkItem?
    private var metadataPrefetchWorkItem: DispatchWorkItem?
    private var pinnedFoldersObserver: AnyCancellable?
    private var fileOperationObserver: AnyCancellable?
    private var directoryLoadCancellation: DirectoryLoadCancellation?
    private var filterSortCancellation: FilterSortCancellation?
    private var metadataPrefetchCancellation: MetadataPrefetchCancellation?
    private var reloadGeneration = 0
    private var filterGeneration = 0
    private var folderChildrenLoadGenerations: [URL: Int] = [:]
    private var folderChildrenLoadQueue: [URL] = []
    private var queuedFolderChildrenLoads: Set<URL> = []
    private var activeFolderChildrenLoadCount = 0
    private let maxConcurrentFolderChildrenLoads = 4
    private let directoryLoadChunkSize = 300
    private let modelID = UUID()
    private let pinnedFoldersKey = "TerminalFileManager.pinnedFolders"

    init(initialDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        currentDirectory = initialDirectory.standardizedFileURL
        folderTreeSelection = currentDirectory
        pinnedFoldersObserver = NotificationCenter.default
            .publisher(for: .pinnedFoldersDidChange)
            .sink { [weak self] _ in
                self?.loadPinnedFolders()
        }
        fileOperationObserver = NotificationCenter.default
            .publisher(for: .fileManagerDirectoriesDidChange)
            .sink { [weak self] notification in
                guard
                    let self,
                    let change = notification.object as? FileOperationChange,
                    change.originModelID != self.modelID,
                    change.affectedDirectories.contains(self.currentDirectory.standardizedFileURL)
                else {
                    return
                }

                self.reload()
            }
        loadPinnedFolders()
        reload()
        expandAncestors(of: currentDirectory)
        expandFolder(currentDirectory)
    }

    var canGoBack: Bool {
        !backStack.isEmpty
    }

    var canGoForward: Bool {
        !forwardStack.isEmpty
    }

    var canGoUp: Bool {
        currentDirectory.deletingLastPathComponent() != currentDirectory
    }

    var allItemCount: Int {
        allItems.count
    }

    var hasSelection: Bool {
        !selectedItemIDs.isEmpty
    }

    var selectionCount: Int {
        selectedItemIDs.count
    }

    var canPaste: Bool {
        clipboard?.urls.isEmpty == false
    }

    var primarySelectedItem: FileItem? {
        guard !isParentDirectorySelected else { return nil }
        guard let primarySelectedItemID else { return nil }
        return allItemLookup[primarySelectedItemID.standardizedFileURL]
    }

    var selectedItems: [FileItem] {
        selectedItemIDs
            .compactMap { allItemLookup[$0.standardizedFileURL] }
            .sorted {
                $0.url.path < $1.url.path
            }
    }

    private var selectedVisibleItems: [FileItem] {
        selectedItemIDs
            .compactMap { id -> (index: Int, item: FileItem)? in
                let key = id.standardizedFileURL
                guard
                    let index = visibleItemIndexLookup[key],
                    let item = allItemLookup[key]
                else {
                    return nil
                }

                return (index, item)
            }
            .sorted { $0.index < $1.index }
            .map(\.item)
    }

    var selectedFolderTreeURL: URL {
        folderTreeSelection ?? currentDirectory
    }

    var selectedFolderTreeRowID: FolderTreeRowID {
        FolderTreeRowID(url: selectedFolderTreeURL.standardizedFileURL, section: folderTreeSelectionSection)
    }

    var selectedFileListRowID: FileListRowID? {
        if isParentDirectorySelected {
            return .parentDirectory
        }

        guard let primarySelectedItemID else { return nil }
        return .item(primarySelectedItemID)
    }

    func reload() {
        reloadGeneration += 1
        let generation = reloadGeneration
        let directory = currentDirectory
        let chunkSize = directoryLoadChunkSize
        directoryLoadCancellation?.cancel()
        let cancellation = DirectoryLoadCancellation()
        directoryLoadCancellation = cancellation
        filterSortCancellation?.cancel()
        filterWorkItem?.cancel()
        filterWorkItem = nil
        metadataPrefetchWorkItem?.cancel()
        metadataPrefetchWorkItem = nil
        metadataPrefetchCancellation?.cancel()
        metadataPrefetchCancellation = nil
        filterGeneration += 1

        allItems = []
        allItemLookup = [:]
        items = []
        refreshPreviewURLs()
        availableCapacityText = "-"

        DispatchQueue.global(qos: .userInitiated).async {
            let headerStart = PerformanceTrace.now()
            let result = Self.loadDirectoryHeader(for: directory)
            PerformanceTrace.log("directory-header", startedAt: headerStart, detail: directory.path)
            let publishBatch: ([FileItem], Bool) -> Void = { [weak self] batch, isFinalBatch in
                DispatchQueue.main.async { [weak self] in
                    guard
                        let self,
                        !cancellation.isCancelled,
                        self.reloadGeneration == generation,
                        self.currentDirectory.standardizedFileURL == directory.standardizedFileURL
                    else {
                        return
                    }

                    self.appendLoadedDirectoryItems(batch, pruneAfterUpdate: isFinalBatch)
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    self.reloadGeneration == generation,
                    self.currentDirectory.standardizedFileURL == directory.standardizedFileURL
                else {
                    return
                }

                switch result {
                case let .success(header):
                    self.availableCapacityText = header.availableCapacityText
                case let .failure(error):
                    self.show(error)
                    cancellation.cancel()
                }
            }

            guard case let .success(header) = result else { return }

            let itemsStart = PerformanceTrace.now()
            var pendingItems: [FileItem] = []
            pendingItems.reserveCapacity(min(header.urls.count, chunkSize))

            for url in header.urls {
                guard !cancellation.isCancelled else { return }

                pendingItems.append(FileItem(url: url))

                if pendingItems.count >= chunkSize {
                    let batch = pendingItems
                    pendingItems.removeAll(keepingCapacity: true)
                    publishBatch(batch, false)
                }
            }

            publishBatch(pendingItems, true)
            PerformanceTrace.log("directory-items", startedAt: itemsStart, detail: "\(header.urls.count) items \(directory.path)")
        }
    }

    private func appendLoadedDirectoryItems(_ loadedItems: [FileItem], pruneAfterUpdate: Bool) {
        if !loadedItems.isEmpty {
            allItems.append(contentsOf: loadedItems)
            for item in loadedItems {
                allItemLookup[item.id.standardizedFileURL] = item
            }
            refreshPreviewURLs()
        }

        if pruneAfterUpdate {
            applyFiltersAndSortAsync(pruneAfterUpdate: true)
        } else {
            scheduleFilterAndSort(pruneAfterUpdate: false)
        }
    }

    private func updateCurrentDirectoryItems(
        adding addedURLs: [URL] = [],
        removing removedURLs: [URL] = [],
        selecting selectionURLs: [URL] = [],
        pruneAfterUpdate: Bool = true
    ) {
        let removedIDs = Set(removedURLs.map { $0.standardizedFileURL })
        let addedItems = addedURLs
            .map(\.standardizedFileURL)
            .filter { $0.deletingLastPathComponent().standardizedFileURL == currentDirectory.standardizedFileURL }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map(FileItem.init)

        if !removedIDs.isEmpty {
            allItems.removeAll { removedIDs.contains($0.id.standardizedFileURL) }
            for removedID in removedIDs {
                allItemLookup.removeValue(forKey: removedID)
            }
            refreshPreviewURLs()
        }

        if !addedItems.isEmpty {
            let addedIDs = Set(addedItems.map { $0.id.standardizedFileURL })
            allItems.removeAll { addedIDs.contains($0.id.standardizedFileURL) }
            allItems.append(contentsOf: addedItems)
            for addedID in addedIDs {
                allItemLookup.removeValue(forKey: addedID)
            }
            for item in addedItems {
                allItemLookup[item.id.standardizedFileURL] = item
            }
            refreshPreviewURLs()
        }

        updateAvailableCapacity()

        let selectedURLs = selectionURLs
            .map(\.standardizedFileURL)
            .filter { $0.deletingLastPathComponent().standardizedFileURL == currentDirectory.standardizedFileURL }
        if !selectedURLs.isEmpty {
            selectedItemIDs = Set(selectedURLs)
            primarySelectedItemID = selectedURLs.last
            selectionAnchorItemID = selectedURLs.first
            isParentDirectorySelected = false
        }

        applyFiltersAndSortAsync(pruneAfterUpdate: pruneAfterUpdate)
    }

    private func rebuildVisibleItemIndexes() {
        var lookup: [FileItem.ID: Int] = [:]
        lookup.reserveCapacity(items.count)
        for (index, item) in items.enumerated() {
            lookup[item.id.standardizedFileURL] = index
        }
        visibleItemIndexLookup = lookup
    }

    private func refreshPreviewURLs() {
        let nextPreviewURLs: [URL]
        if isParentDirectorySelected {
            nextPreviewURLs = []
        } else {
            nextPreviewURLs = selectedItemIDs
                .compactMap { allItemLookup[$0.standardizedFileURL]?.url }
                .sorted {
                    $0.path < $1.path
                }
        }

        if previewURLs != nextPreviewURLs {
            previewURLs = nextPreviewURLs
        }
    }

    func prefetchVisibleMetadata(for columns: [FileListColumn]) {
        let needsIcons = columns.contains(.icon)
        let needsKind = columns.contains(.kind)
        let needsPermissions = columns.contains(.permissions)
        guard needsIcons || needsKind || needsPermissions else {
            metadataPrefetchWorkItem?.cancel()
            metadataPrefetchWorkItem = nil
            metadataPrefetchCancellation?.cancel()
            metadataPrefetchCancellation = nil
            return
        }

        metadataPrefetchWorkItem?.cancel()
        metadataPrefetchCancellation?.cancel()

        guard !items.isEmpty else {
            metadataPrefetchWorkItem = nil
            metadataPrefetchCancellation = nil
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            let cancellation = MetadataPrefetchCancellation()
            self.metadataPrefetchCancellation = cancellation
            let visibleItems = self.items
            let prefetchLimit = 1_000
            let itemsToPrefetch = visibleItems.count > prefetchLimit
                ? Array(visibleItems.prefix(prefetchLimit))
                : visibleItems

            DispatchQueue.global(qos: .utility).async {
                let prefetchStart = PerformanceTrace.now()
                guard !cancellation.isCancelled else { return }

                if needsIcons {
                    FileIconCache.shared.prefetch(for: itemsToPrefetch, cancellation: cancellation)
                }

                guard !cancellation.isCancelled else { return }

                if needsKind {
                    FileKindCache.shared.prefetch(for: itemsToPrefetch, cancellation: cancellation)
                }

                guard !cancellation.isCancelled else { return }

                if needsPermissions {
                    FilePermissionCache.shared.prefetch(for: itemsToPrefetch.map(\.url), cancellation: cancellation)
                }

                PerformanceTrace.log("metadata-prefetch", startedAt: prefetchStart, detail: "\(itemsToPrefetch.count) items")
            }
        }
        metadataPrefetchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private func notifyDirectoriesChanged(_ directories: [URL]) {
        let affectedDirectories = Set(directories.map(\.standardizedFileURL))
        guard !affectedDirectories.isEmpty else { return }

        NotificationCenter.default.post(
            name: .fileManagerDirectoriesDidChange,
            object: FileOperationChange(originModelID: modelID, affectedDirectories: affectedDirectories)
        )
    }

    func isSelected(_ item: FileItem) -> Bool {
        selectedItemIDs.contains(item.id)
    }

    func isDropTargetDirectory(_ url: URL) -> Bool {
        highlightedDropDirectory?.standardizedFileURL == url.standardizedFileURL
    }

    func setDropTargetDirectory(_ url: URL?) {
        let target = url?.standardizedFileURL
        guard highlightedDropDirectory != target else { return }
        highlightedDropDirectory = target
    }

    func clearDropTargetDirectory(_ url: URL?) {
        guard let url else {
            highlightedDropDirectory = nil
            return
        }

        if highlightedDropDirectory?.standardizedFileURL == url.standardizedFileURL {
            highlightedDropDirectory = nil
        }
    }

    func select(_ item: FileItem, extending: Bool = false) {
        if extending {
            isParentDirectorySelected = false
            selectionAnchorItemID = selectionAnchorItemID ?? primarySelectedItemID ?? item.id
            if selectedItemIDs.contains(item.id) {
                selectedItemIDs.remove(item.id)
                if primarySelectedItemID == item.id {
                    primarySelectedItemID = selectedItemIDs.first
                }
                if selectedItemIDs.isEmpty {
                    selectionAnchorItemID = nil
                }
            } else {
                selectedItemIDs.insert(item.id)
                primarySelectedItemID = item.id
                selectionAnchorItemID = selectionAnchorItemID ?? item.id
            }
        } else {
            isParentDirectorySelected = false
            selectedItemIDs = [item.id]
            primarySelectedItemID = item.id
            selectionAnchorItemID = item.id
        }
    }

    func selectForMouseDown(_ item: FileItem, modifiers: NSEvent.ModifierFlags) {
        isParentDirectorySelected = false

        if modifiers.contains(.shift) {
            selectRange(to: item)
        } else if modifiers.contains(.command) {
            select(item, extending: true)
        } else if !selectedItemIDs.contains(item.id) {
            select(item)
        } else {
            primarySelectedItemID = item.id
        }
    }

    func selectForMouseUp(_ item: FileItem, modifiers: NSEvent.ModifierFlags) {
        guard !modifiers.contains(.shift), !modifiers.contains(.command) else { return }
        select(item)
    }

    func dragItemsForFileRow(_ item: FileItem) -> [FileDragItem] {
        if !selectedItemIDs.contains(item.id) {
            select(item)
        }

        if selectedItemIDs.contains(item.id) {
            return selectedVisibleItems.map { item in
                FileDragItem(url: item.url, iconCacheKey: item.iconCacheKey)
            }
        }

        return [FileDragItem(url: item.url, iconCacheKey: item.iconCacheKey)]
    }

    func selectParentDirectory() {
        guard canGoUp else { return }
        isParentDirectorySelected = true
        selectedItemIDs.removeAll()
        primarySelectedItemID = nil
        selectionAnchorItemID = nil
    }

    func ensureFileSelection() {
        if isParentDirectorySelected || primarySelectedItem != nil {
            return
        }

        if canGoUp {
            selectParentDirectory()
        } else if let firstItem = items.first {
            select(firstItem)
        }
    }

    func moveFileSelection(delta: Int, extendingRange: Bool = false) {
        let parentOffset = canGoUp ? 1 : 0
        let rowCount = parentOffset + items.count
        guard rowCount > 0 else { return }

        let currentIndex: Int
        if isParentDirectorySelected {
            currentIndex = 0
        } else if let primarySelectedItemID, let itemIndex = visibleItemIndexLookup[primarySelectedItemID.standardizedFileURL] {
            currentIndex = parentOffset + itemIndex
        } else {
            currentIndex = delta >= 0 ? -1 : rowCount
        }

        let nextIndex = clampIndex(currentIndex + delta, count: rowCount)
        if extendingRange {
            selectRange(toRow: nextIndex, fallbackCurrentRow: currentIndex)
            return
        }

        if canGoUp, nextIndex == 0 {
            selectParentDirectory()
        } else {
            select(items[nextIndex - parentOffset])
        }
    }

    func selectRange(to item: FileItem) {
        guard let itemIndex = visibleItemIndexLookup[item.id.standardizedFileURL] else {
            return
        }

        selectRange(toRow: (canGoUp ? 1 : 0) + itemIndex, fallbackCurrentRow: nil)
    }

    private func selectRange(toRow targetRow: Int, fallbackCurrentRow: Int?) {
        guard !items.isEmpty else { return }

        let parentOffset = canGoUp ? 1 : 0
        let targetItemIndex = targetRow - parentOffset
        let fallbackItemIndex = (fallbackCurrentRow ?? targetRow) - parentOffset

        if selectionAnchorItemID == nil {
            if let primarySelectedItemID, visibleItemIndexLookup[primarySelectedItemID.standardizedFileURL] != nil {
                selectionAnchorItemID = primarySelectedItemID
            } else if items.indices.contains(fallbackItemIndex) {
                selectionAnchorItemID = items[fallbackItemIndex].id
            } else if items.indices.contains(targetItemIndex) {
                selectionAnchorItemID = items[targetItemIndex].id
            } else {
                selectionAnchorItemID = items.first?.id
            }
        }

        guard
            let anchorID = selectionAnchorItemID,
            let anchorIndex = visibleItemIndexLookup[anchorID.standardizedFileURL]
        else {
            return
        }

        let clampedTargetIndex = clampIndex(targetItemIndex, count: items.count)
        let range = min(anchorIndex, clampedTargetIndex)...max(anchorIndex, clampedTargetIndex)
        selectedItemIDs = Set(items[range].map(\.id))
        primarySelectedItemID = items[clampedTargetIndex].id
        isParentDirectorySelected = false
    }

    func activateFileSelection() {
        if isParentDirectorySelected {
            goUp()
            return
        }

        if let primarySelectedItem {
            open(primarySelectedItem)
        } else if let firstItem = items.first {
            select(firstItem)
            open(firstItem)
        }
    }

    func selectForContextMenu(_ item: FileItem) {
        isParentDirectorySelected = false
        selectionAnchorItemID = item.id
        if !selectedItemIDs.contains(item.id) {
            select(item)
        } else {
            primarySelectedItemID = item.id
        }
    }

    func selectAllVisibleItems() {
        isParentDirectorySelected = false
        selectedItemIDs = Set(items.map(\.id))
        primarySelectedItemID = items.last?.id
        selectionAnchorItemID = items.first?.id
    }

    func isFolderExpanded(_ url: URL) -> Bool {
        expandedFolders.contains(url.standardizedFileURL)
    }

    func hasFolderChildren(_ url: URL) -> Bool {
        childrenForFolder(url).isEmpty == false
    }

    func isFolderTreeSelected(_ url: URL, in section: FolderTreeSelectionSection) -> Bool {
        folderTreeSelectionSection == section && selectedFolderTreeURL.standardizedFileURL == url.standardizedFileURL
    }

    func selectFolderTree(_ url: URL, in section: FolderTreeSelectionSection) {
        folderTreeSelection = url.standardizedFileURL
        folderTreeSelectionSection = section
        clearDropTargetDirectory(nil)
    }

    func ensureFolderTreeSelection() {
        if visibleFolderTreeFolders(in: folderTreeSelectionSection).contains(selectedFolderTreeURL.standardizedFileURL) {
            return
        }

        if folderTreeSelectionSection == .pinned, let firstPinnedFolder = pinnedFolders.first {
            selectFolderTree(firstPinnedFolder, in: .pinned)
            return
        }

        expandAncestors(of: currentDirectory)
        let folders = visibleFolderTreeFolders(in: .tree)
        if folders.contains(currentDirectory.standardizedFileURL) {
            selectFolderTree(currentDirectory, in: .tree)
        } else if let firstFolder = folders.first {
            selectFolderTree(firstFolder, in: .tree)
        }
    }

    func moveFolderTreeSelection(delta: Int) {
        let folders = visibleFolderTreeFolders(in: folderTreeSelectionSection)
        guard !folders.isEmpty else { return }

        let selectedURL = selectedFolderTreeURL.standardizedFileURL
        let currentIndex = folders.firstIndex { $0.standardizedFileURL == selectedURL } ?? (delta >= 0 ? -1 : folders.count)
        let nextIndex = clampIndex(currentIndex + delta, count: folders.count)
        selectFolderTree(folders[nextIndex], in: folderTreeSelectionSection)
    }

    func moveFolderTreeLeft() {
        guard folderTreeSelectionSection == .tree else { return }
        let selectedURL = selectedFolderTreeURL.standardizedFileURL

        if isFolderExpanded(selectedURL) {
            toggleFolderExpansion(selectedURL)
            return
        }

        let parent = selectedURL.deletingLastPathComponent()
        guard parent != selectedURL else { return }
        expandAncestors(of: parent)
        selectFolderTree(parent, in: .tree)
    }

    func moveFolderTreeRight() {
        guard folderTreeSelectionSection == .tree else { return }
        let selectedURL = selectedFolderTreeURL.standardizedFileURL

        if !isFolderExpanded(selectedURL) {
            expandFolder(selectedURL)
            return
        }

        if let firstChild = childrenForFolder(selectedURL).first {
            selectFolderTree(firstChild, in: .tree)
        }
    }

    func activateFolderTreeSelection() {
        let selectedURL = selectedFolderTreeURL.standardizedFileURL
        guard isDirectory(selectedURL) else { return }
        navigate(to: selectedURL)
        if folderTreeSelectionSection == .tree {
            expandFolder(selectedURL)
        }
    }

    func toggleFolderExpansion(_ url: URL) {
        let key = url.standardizedFileURL

        if expandedFolders.contains(key) {
            expandedFolders.remove(key)
        } else {
            expandFolder(url)
        }
    }

    func expandFolder(_ url: URL) {
        let key = url.standardizedFileURL
        expandedFolders.insert(key)
        refreshFolderChildren(url)
    }

    func childrenForFolder(_ url: URL) -> [URL] {
        folderChildrenCache[url.standardizedFileURL] ?? []
    }

    func refreshFolderChildrenIfNeeded(_ url: URL) {
        let key = url.standardizedFileURL
        guard folderChildrenCache[key] == nil, folderChildrenLoadGenerations[key] == nil else {
            return
        }

        refreshFolderChildren(url)
    }

    func visibleFolderTreeFolders(in section: FolderTreeSelectionSection) -> [URL] {
        switch section {
        case .pinned:
            return pinnedFolders
        case .tree:
            return visibleDefaultTreeFolders()
        }
    }

    private func visibleDefaultTreeFolders() -> [URL] {
        var folders: [URL] = []
        var seen = Set<URL>()

        for root in defaultTreeRoots() {
            appendVisibleFolder(root, to: &folders, seen: &seen)
        }

        return folders
    }

    func isFolderPinned(_ url: URL) -> Bool {
        pinnedFolders.contains(url.standardizedFileURL)
    }

    func togglePinnedFolder(_ url: URL) {
        if isFolderPinned(url) {
            unpinFolder(url)
        } else {
            pinFolder(url)
        }
    }

    func pinFolder(_ url: URL) {
        let folderURL = url.standardizedFileURL
        guard isDirectory(folderURL), !isFolderPinned(folderURL) else { return }

        pinnedFolders.append(folderURL)
        savePinnedFolders()
    }

    func unpinFolder(_ url: URL) {
        let folderURL = url.standardizedFileURL
        pinnedFolders.removeAll { $0.standardizedFileURL == folderURL }
        savePinnedFolders()
    }

    func beginPinnedFolderDrag(_ url: URL) {
        let folderURL = url.standardizedFileURL
        if draggedPinnedFolder == folderURL {
            return
        }

        draggedPinnedFolder = folderURL
        draggedPinnedFolderOriginalIndex = pinnedFolders.firstIndex { $0.standardizedFileURL == folderURL }
    }

    var isDraggingPinnedFolder: Bool {
        draggedPinnedFolder != nil
    }

    func isDraggingPinnedFolder(_ url: URL) -> Bool {
        draggedPinnedFolder == url.standardizedFileURL
    }

    func isPinnedFolderInsertionSlotVisible(at index: Int) -> Bool {
        pinnedFolderInsertionIndex == index
    }

    func updateDraggedPinnedFolder(translationY: CGFloat, rowHeight: CGFloat) {
        guard
            let originalIndex = draggedPinnedFolderOriginalIndex,
            rowHeight > 0,
            !pinnedFolders.isEmpty
        else {
            return
        }

        let rowOffset = Int((translationY / rowHeight).rounded())
        let dropDirectionOffset = translationY > 0 ? 1 : 0
        let insertionIndex = min(max(originalIndex + rowOffset + dropDirectionOffset, 0), pinnedFolders.count)
        pinnedFolderInsertionIndex = insertionIndex
    }

    func finishPinnedFolderDrag(applyingMove: Bool = false) {
        if applyingMove, let draggedPinnedFolder, let pinnedFolderInsertionIndex {
            movePinnedFolder(draggedPinnedFolder, toInsertionIndex: pinnedFolderInsertionIndex)
        }

        draggedPinnedFolder = nil
        draggedPinnedFolderOriginalIndex = nil
        pinnedFolderInsertionIndex = nil
    }

    private func movePinnedFolder(_ sourceURL: URL, toInsertionIndex insertionIndex: Int) {
        let source = sourceURL.standardizedFileURL
        guard let sourceIndex = pinnedFolders.firstIndex(where: { $0.standardizedFileURL == source }) else {
            return
        }

        let movedFolder = pinnedFolders.remove(at: sourceIndex)
        let adjustedInsertionIndex = sourceIndex < insertionIndex ? insertionIndex - 1 : insertionIndex
        let clampedInsertionIndex = min(max(adjustedInsertionIndex, 0), pinnedFolders.count)
        guard sourceIndex != clampedInsertionIndex else {
            pinnedFolders.insert(movedFolder, at: sourceIndex)
            return
        }

        pinnedFolders.insert(movedFolder, at: clampedInsertionIndex)
        savePinnedFolders()
    }

    func refreshFolderChildren(_ url: URL) {
        let key = url.standardizedFileURL
        let generation = (folderChildrenLoadGenerations[key] ?? 0) + 1
        folderChildrenLoadGenerations[key] = generation

        enqueueFolderChildrenLoad(for: key)
    }

    private func enqueueFolderChildrenLoad(for key: URL) {
        guard !queuedFolderChildrenLoads.contains(key) else { return }
        queuedFolderChildrenLoads.insert(key)
        folderChildrenLoadQueue.append(key)
        processFolderChildrenLoadQueue()
    }

    private func processFolderChildrenLoadQueue() {
        while activeFolderChildrenLoadCount < maxConcurrentFolderChildrenLoads,
              !folderChildrenLoadQueue.isEmpty {
            let key = folderChildrenLoadQueue.removeFirst()
            queuedFolderChildrenLoads.remove(key)
            activeFolderChildrenLoadCount += 1
            let generation = folderChildrenLoadGenerations[key] ?? 0

            DispatchQueue.global(qos: .utility).async {
                let children = Self.loadFolderChildren(for: key)

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.activeFolderChildrenLoadCount = max(0, self.activeFolderChildrenLoadCount - 1)

                    if self.folderChildrenLoadGenerations[key] == generation {
                        self.folderChildrenCache[key] = children
                    }

                    self.processFolderChildrenLoadQueue()
                }
            }
        }
    }

    nonisolated private static func loadFolderChildren(for url: URL) -> [URL] {
        let loadStart = PerformanceTrace.now()
        do {
            let children = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            var childFolders: [(url: URL, sortName: String)] = []
            childFolders.reserveCapacity(children.count)

            for child in children {
                guard (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                    continue
                }

                childFolders.append((
                    url: child,
                    sortName: folderDisplayName(for: child).localizedLowercase
                ))
            }

            let result = childFolders
                .sorted {
                    $0.sortName < $1.sortName
                }
                .map(\.url)
            PerformanceTrace.log("folder-children", startedAt: loadStart, detail: "\(result.count) folders \(url.path)")
            return result
        } catch {
            PerformanceTrace.log("folder-children", startedAt: loadStart, detail: "failed \(url.path)")
            return []
        }
    }

    nonisolated private static func folderDisplayName(for url: URL) -> String {
        FolderDisplayNameCache.shared.displayName(for: url)
    }

    private func expandAncestors(of url: URL) {
        var ancestor = url.deletingLastPathComponent()
        var seen = Set<URL>()

        while ancestor != url, seen.insert(ancestor.standardizedFileURL).inserted {
            expandFolder(ancestor)

            let parent = ancestor.deletingLastPathComponent()
            if parent == ancestor {
                break
            }
            ancestor = parent
        }
    }

    private func clearSelection() {
        isParentDirectorySelected = false
        selectedItemIDs.removeAll()
        primarySelectedItemID = nil
        selectionAnchorItemID = nil
    }

    private func pruneSelection() {
        selectedItemIDs = Set(
            selectedItemIDs.filter { visibleItemIndexLookup[$0.standardizedFileURL] != nil }
        )

        if isParentDirectorySelected, !canGoUp {
            isParentDirectorySelected = false
        }

        if let primarySelectedItemID, !selectedItemIDs.contains(primarySelectedItemID) {
            self.primarySelectedItemID = selectedItemIDs.first
        }

        if let selectionAnchorItemID, visibleItemIndexLookup[selectionAnchorItemID.standardizedFileURL] == nil {
            self.selectionAnchorItemID = primarySelectedItemID
        }

        if selectedItemIDs.isEmpty {
            primarySelectedItemID = nil
            selectionAnchorItemID = nil
        }
    }

    private func scheduleFilterAndSort(pruneAfterUpdate: Bool = true) {
        filterWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.applyFiltersAndSortAsync(pruneAfterUpdate: pruneAfterUpdate)
        }
        filterWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func applyFiltersAndSortImmediately() {
        filterWorkItem?.cancel()
        filterWorkItem = nil
        applyFiltersAndSortAsync(pruneAfterUpdate: true)
    }

    private func applyFiltersAndSortAsync(pruneAfterUpdate: Bool) {
        filterGeneration += 1
        let generation = filterGeneration
        filterSortCancellation?.cancel()
        let cancellation = FilterSortCancellation()
        filterSortCancellation = cancellation
        let sourceItems = allItems
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        let showsHiddenFiles = showHiddenFiles
        let key = sortKey
        let ascending = sortAscending

        DispatchQueue.global(qos: .userInitiated).async {
            let filteredItems = Self.filteredAndSortedItems(
                sourceItems,
                query: query,
                showsHiddenFiles: showsHiddenFiles,
                sortKey: key,
                sortAscending: ascending,
                cancellation: cancellation
            )

            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    self.filterGeneration == generation,
                    !cancellation.isCancelled,
                    let filteredItems
                else {
                    return
                }

                self.items = filteredItems
                if pruneAfterUpdate {
                    self.pruneSelection()
                }
            }
        }
    }

    nonisolated private static func filteredAndSortedItems(
        _ sourceItems: [FileItem],
        query: String,
        showsHiddenFiles: Bool,
        sortKey: FileSortKey,
        sortAscending: Bool,
        cancellation: FilterSortCancellation
    ) -> [FileItem]? {
        let filterStart = PerformanceTrace.now()
        var filteredItems: [FileItem] = []
        filteredItems.reserveCapacity(sourceItems.count)

        for (index, item) in sourceItems.enumerated() {
            if index.isMultiple(of: 256), cancellation.isCancelled {
                return nil
            }

            if (showsHiddenFiles || !item.isHidden)
                && (query.isEmpty || item.searchName.contains(query)) {
                filteredItems.append(item)
            }
        }

        guard !cancellation.isCancelled else { return nil }
        guard filteredItems.count > 1 else {
            PerformanceTrace.log("filter-sort", startedAt: filterStart, detail: "\(sourceItems.count)->\(filteredItems.count) items \(sortKey.rawValue)")
            return filteredItems
        }

        let sortedItems = filteredItems.sorted { lhs, rhs in
                compareForSort(lhs, rhs, sortKey: sortKey, sortAscending: sortAscending)
        }

        guard !cancellation.isCancelled else { return nil }
        PerformanceTrace.log("filter-sort", startedAt: filterStart, detail: "\(sourceItems.count)->\(sortedItems.count) items \(sortKey.rawValue)")
        return sortedItems
    }

    nonisolated private static func compareForSort(
        _ lhs: FileItem,
        _ rhs: FileItem,
        sortKey: FileSortKey,
        sortAscending: Bool
    ) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }

        let result: ComparisonResult

        switch sortKey {
        case .name:
            result = lhs.name.localizedStandardCompare(rhs.name)
        case .fastName:
            result = comparePlainStrings(lhs.searchName, rhs.searchName)
        case .size:
            result = lhs.size == rhs.size ? .orderedSame : (lhs.size < rhs.size ? .orderedAscending : .orderedDescending)
        case .kind:
            result = comparePlainStrings(lhs.kindSortKey, rhs.kindSortKey)
        case .modified:
            result = compareDates(lhs.modified, rhs.modified)
        case .created:
            result = compareDates(lhs.created, rhs.created)
        }

        if result == .orderedSame, sortKey != .name {
            return comparePlainStrings(lhs.searchName, rhs.searchName) == .orderedAscending
        }

        return sortAscending ? result == .orderedAscending : result == .orderedDescending
    }

    nonisolated private static func comparePlainStrings(_ lhs: String, _ rhs: String) -> ComparisonResult {
        if lhs == rhs {
            return .orderedSame
        }

        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    nonisolated private static func compareDates(_ lhs: Date?, _ rhs: Date?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            if lhs == rhs {
                return .orderedSame
            }
            return lhs < rhs ? .orderedAscending : .orderedDescending
        case (nil, nil):
            return .orderedSame
        case (nil, _):
            return .orderedAscending
        case (_, nil):
            return .orderedDescending
        }
    }

    private func clampIndex(_ index: Int, count: Int) -> Int {
        min(max(index, 0), count - 1)
    }

    private func defaultTreeRoots() -> [URL] {
        [URL(fileURLWithPath: "/").standardizedFileURL]
    }

    private func appendVisibleFolder(_ url: URL, to folders: inout [URL], seen: inout Set<URL>) {
        let key = url.standardizedFileURL
        guard seen.insert(key).inserted else { return }

        folders.append(key)

        if isFolderExpanded(key) {
            for child in childrenForFolder(key) {
                appendVisibleFolder(child, to: &folders, seen: &seen)
            }
        }
    }

    private func displayName(for url: URL) -> String {
        if url.path == "/" {
            return "/"
        }

        return FileManager.default.displayName(atPath: url.path)
    }

    private func loadPinnedFolders() {
        let paths = UserDefaults.standard.stringArray(forKey: pinnedFoldersKey) ?? []
        var seen = Set<URL>()

        pinnedFolders = paths
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
            .filter { isDirectory($0) }
            .filter { seen.insert($0).inserted }
    }

    private func savePinnedFolders() {
        UserDefaults.standard.set(pinnedFolders.map(\.path), forKey: pinnedFoldersKey)
        NotificationCenter.default.post(name: .pinnedFoldersDidChange, object: nil)
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func open(_ item: FileItem) {
        if item.isDirectory {
            navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func navigate(to directory: URL, recordsHistory: Bool = true) {
        let target = directory.standardizedFileURL
        guard target != currentDirectory.standardizedFileURL else { return }

        if recordsHistory {
            backStack.append(currentDirectory)
            forwardStack.removeAll()
        }

        currentDirectory = target
        folderTreeSelection = target
        folderTreeSelectionSection = .tree
        clearDropTargetDirectory(nil)
        clearSelection()
        expandAncestors(of: target)
        expandFolder(target)
        reload()
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentDirectory)
        navigate(to: previous, recordsHistory: false)
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentDirectory)
        navigate(to: next, recordsHistory: false)
    }

    func goUp() {
        let parent = currentDirectory.deletingLastPathComponent()
        guard parent != currentDirectory else { return }
        navigate(to: parent)
    }

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = currentDirectory

        if panel.runModal() == .OK, let url = panel.url {
            navigate(to: url)
        }
    }

    func openTerminal() {
        openTerminal(at: currentDirectory)
    }

    func openTerminal(at directory: URL) {
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open(
            [directory],
            withApplicationAt: terminalURL,
            configuration: configuration
        ) { [weak self] _, error in
            if let error {
                DispatchQueue.main.async {
                    self?.show(error)
                }
            }
        }
    }

    func createFolder() {
        guard let name = promptForText(title: "New Folder", message: "Enter a folder name.", defaultValue: "Untitled Folder") else {
            return
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let folderURL = uniqueDestination(for: trimmed, in: currentDirectory)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
            refreshFolderChildren(currentDirectory)
            updateCurrentDirectoryItems(adding: [folderURL], selecting: [folderURL])
            notifyDirectoriesChanged([currentDirectory])
        } catch {
            show(error)
        }
    }

    func renameSelectedItem() {
        guard selectedItemIDs.count == 1, let selectedItem = primarySelectedItem else { return }
        guard let name = promptForText(title: "Rename", message: "Enter a new name.", defaultValue: selectedItem.name) else {
            return
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != selectedItem.name else { return }

        let destination = uniqueDestination(for: trimmed, in: selectedItem.url.deletingLastPathComponent())

        do {
            try FileManager.default.moveItem(at: selectedItem.url, to: destination)
            refreshFolderChildren(selectedItem.url.deletingLastPathComponent())
            updateCurrentDirectoryItems(
                adding: [destination],
                removing: [selectedItem.url],
                selecting: [destination]
            )
            notifyDirectoriesChanged([selectedItem.url.deletingLastPathComponent()])
        } catch {
            show(error)
        }
    }

    func moveSelectedItemsToTrash() {
        let itemsToTrash = selectedItems
        guard !itemsToTrash.isEmpty else { return }

        do {
            for item in itemsToTrash {
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultingURL)
                refreshFolderChildren(item.url.deletingLastPathComponent())
            }
            clearSelection()
            updateCurrentDirectoryItems(removing: itemsToTrash.map(\.url))
            notifyDirectoriesChanged(itemsToTrash.map { $0.url.deletingLastPathComponent() })
        } catch {
            show(error)
        }
    }

    func revealSelectedItemsInFinder() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path(percentEncoded: false), forType: .string)
    }

    func copySelectedItems() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        clipboard = FileClipboard(urls: urls, operation: .copy)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSURL])
    }

    func cutSelectedItems() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        clipboard = FileClipboard(urls: urls, operation: .move)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSURL])
    }

    func pasteItems() {
        pasteItems(into: currentDirectory)
    }

    func pasteItems(into targetDirectory: URL) {
        guard let clipboard, !clipboard.urls.isEmpty else { return }
        var pastedURLs: [URL] = []
        var removedURLs: [URL] = []
        var affectedDirectories = Set<URL>()

        do {
            for sourceURL in clipboard.urls {
                let decision = destinationDecision(
                    for: sourceURL,
                    in: targetDirectory,
                    operation: clipboard.operation
                )

                switch decision {
                case .cancel:
                    return
                case .skip:
                    continue
                case let .use(destinationURL, shouldReplace):
                    if shouldReplace {
                        try FileManager.default.removeItem(at: destinationURL)
                    }

                    switch clipboard.operation {
                    case .copy:
                        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                    case .move:
                        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                        removedURLs.append(sourceURL)
                        affectedDirectories.insert(sourceURL.deletingLastPathComponent().standardizedFileURL)
                    }

                    pastedURLs.append(destinationURL)
                    affectedDirectories.insert(destinationURL.deletingLastPathComponent().standardizedFileURL)
                }
            }

            if clipboard.operation == .move {
                self.clipboard = nil
            }

            refreshFolderChildren(targetDirectory)
            updateCurrentDirectoryItems(
                adding: pastedURLs,
                removing: removedURLs,
                selecting: pastedURLs
            )
            notifyDirectoriesChanged(Array(affectedDirectories))
        } catch {
            show(error)
            reload()
        }
    }

    func moveDroppedFiles(
        _ providers: [NSItemProvider],
        to targetDirectory: URL,
        completion: (() -> Void)? = nil
    ) -> Bool {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
                DispatchQueue.main.async {
                    if let error {
                        self?.show(error)
                        return
                    }
                    self?.handleDroppedItem(item, targetDirectory: targetDirectory, completion: completion)
                }
            }
        }
        return true
    }

    private func handleDroppedItem(_ item: NSSecureCoding?, targetDirectory: URL, completion: (() -> Void)?) {
        let url: URL?

        if let droppedURL = item as? URL {
            url = droppedURL
        } else if let data = item as? Data {
            url = URL(dataRepresentation: data, relativeTo: nil)
        } else if let string = item as? String {
            url = URL(string: string)
        } else {
            url = nil
        }

        guard let sourceURL = url else { return }
        move(sourceURL, to: targetDirectory, completion: completion)
    }

    private func move(_ sourceURL: URL, to targetDirectory: URL, completion: (() -> Void)? = nil) {
        let decision = destinationDecision(for: sourceURL, in: targetDirectory, operation: .move)

        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let destinationURL: URL

            switch decision {
            case .cancel, .skip:
                return
            case let .use(resolvedDestinationURL, shouldReplace):
                if shouldReplace {
                    try FileManager.default.removeItem(at: resolvedDestinationURL)
                }
                destinationURL = resolvedDestinationURL
            }

            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            refreshFolderChildren(sourceURL.deletingLastPathComponent())
            refreshFolderChildren(targetDirectory)
            updateCurrentDirectoryItems(
                adding: [destinationURL],
                removing: [sourceURL],
                selecting: [destinationURL]
            )
            notifyDirectoriesChanged([
                sourceURL.deletingLastPathComponent(),
                targetDirectory
            ])
            completion?()
        } catch {
            show(error)
        }
    }

    private func destinationDecision(
        for sourceURL: URL,
        in directory: URL,
        operation: FileClipboard.Operation
    ) -> FileConflictDecision {
        let destinationURL = directory.appendingPathComponent(sourceURL.lastPathComponent)

        if operation == .move && sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            return .skip
        }

        if operation == .copy && sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            return .use(uniqueDestination(for: sourceURL.lastPathComponent, in: directory), shouldReplace: false)
        }

        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            return .use(destinationURL, shouldReplace: false)
        }

        switch promptForConflict(fileName: destinationURL.lastPathComponent) {
        case .replace:
            return .use(destinationURL, shouldReplace: true)
        case .keepBoth:
            return .use(uniqueDestination(for: sourceURL.lastPathComponent, in: directory), shouldReplace: false)
        case .skip:
            return .skip
        case .cancel:
            return .cancel
        }
    }

    private func uniqueDestination(for fileName: String, in directory: URL) -> URL {
        var candidate = directory.appendingPathComponent(fileName)
        let ext = candidate.pathExtension
        let stem = candidate.deletingPathExtension().lastPathComponent
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            let renamed = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
            candidate = directory.appendingPathComponent(renamed)
            index += 1
        }

        return candidate
    }

    private func updateAvailableCapacity() {
        let values = try? currentDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey])

        if let availableCapacity = values?.volumeAvailableCapacity {
            availableCapacityText = FileDisplayTextCache.shared.sizeText(byteCount: Int64(availableCapacity))
        } else {
            availableCapacityText = "-"
        }
    }

    nonisolated private static func loadDirectoryHeader(for directory: URL) -> Result<DirectoryHeader, Error> {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .isHiddenKey],
                options: [.skipsPackageDescendants]
            )
            let values = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            let availableCapacityText: String
            if let availableCapacity = values?.volumeAvailableCapacity {
                availableCapacityText = FileDisplayTextCache.shared.sizeText(byteCount: Int64(availableCapacity))
            } else {
                availableCapacityText = "-"
            }
            return .success(DirectoryHeader(urls: urls, availableCapacityText: availableCapacityText))
        } catch {
            return .failure(error)
        }
    }

    private func promptForConflict(fileName: String) -> ConflictResolution {
        let alert = NSAlert()
        alert.messageText = "Item Already Exists"
        alert.informativeText = "\"\(fileName)\" already exists in the destination."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Keep Both")
        alert.addButton(withTitle: "Skip")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .replace
        case .alertSecondButtonReturn:
            return .keepBoth
        case .alertThirdButtonReturn:
            return .skip
        default:
            return .cancel
        }
    }

    private func promptForText(title: String, message: String, defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        textField.stringValue = defaultValue
        alert.accessoryView = textField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return textField.stringValue
    }

    private func show(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }
}

private struct FileDropDelegate: DropDelegate {
    let model: FileBrowserModel
    let targetDirectory: URL
    var highlightedDirectory: URL?
    var isEnabled = true
    var reloadRelatedPanes: (() -> Void)?

    func validateDrop(info: DropInfo) -> Bool {
        isEnabled && info.hasItemsConforming(to: [UTType.fileURL.identifier])
    }

    func dropEntered(info: DropInfo) {
        guard isEnabled, info.hasItemsConforming(to: [UTType.fileURL.identifier]) else { return }
        model.setDropTargetDirectory(highlightedDirectory)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard isEnabled, info.hasItemsConforming(to: [UTType.fileURL.identifier]) else {
            return DropProposal(operation: .forbidden)
        }

        model.setDropTargetDirectory(highlightedDirectory)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        model.clearDropTargetDirectory(highlightedDirectory)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            model.clearDropTargetDirectory(highlightedDirectory)
        }

        guard isEnabled else { return false }
        return model.moveDroppedFiles(
            info.itemProviders(for: [UTType.fileURL.identifier]),
            to: targetDirectory,
            completion: reloadRelatedPanes
        )
    }
}

private enum BrowserPaneID: String {
    case left
    case right

    var title: String {
        switch self {
        case .left:
            return "LEFT"
        case .right:
            return "RIGHT"
        }
    }
}

private enum ActiveArea: String {
    case files
    case folderTree
}

private enum FolderTreeSelectionSection: Hashable {
    case pinned
    case tree
}

private struct FolderTreeRowID: Hashable {
    let url: URL
    let section: FolderTreeSelectionSection
}

private enum FileListRowID: Hashable {
    case parentDirectory
    case item(URL)
}

private enum PerformanceTrace {
    nonisolated static func now() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    nonisolated static func log(_ label: String, startedAt start: UInt64, detail: String = "") {
        guard ProcessInfo.processInfo.environment["TFX_PERFORMANCE_LOGS"] == "1" else { return }

        let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        let suffix = detail.isEmpty ? "" : " \(detail)"
        print(String(format: "[tfx perf] %@ %.1fms%@", label, elapsedMilliseconds, suffix))
    }
}

private final class DirectoryLoadCancellation {
    private let lock = NSLock()
    private var isCancelledStorage = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelledStorage
    }

    func cancel() {
        lock.lock()
        isCancelledStorage = true
        lock.unlock()
    }
}

private final class PreviewLoadCancellation {
    private let lock = NSLock()
    private var isCancelledStorage = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelledStorage
    }

    func cancel() {
        lock.lock()
        isCancelledStorage = true
        lock.unlock()
    }
}

private final class FilterSortCancellation: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var isCancelledStorage = false

    nonisolated var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelledStorage
    }

    nonisolated func cancel() {
        lock.lock()
        isCancelledStorage = true
        lock.unlock()
    }
}

private final class MetadataPrefetchCancellation: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var isCancelledStorage = false

    nonisolated var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelledStorage
    }

    nonisolated func cancel() {
        lock.lock()
        isCancelledStorage = true
        lock.unlock()
    }
}

private struct DirectoryHeader {
    let urls: [URL]
    let availableCapacityText: String
}

private struct FileOperationChange {
    let originModelID: UUID
    let affectedDirectories: Set<URL>
}

private struct FileDragItem {
    let url: URL
    let iconCacheKey: String
}

private struct FileItem: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let isHidden: Bool
    let size: Int64
    let modified: Date?
    let created: Date?
    let nameValue: String
    let searchNameValue: String
    let iconCacheKeyValue: String
    let modeValue: String
    let kindSortKeyValue: String
    let sizeTextValue: String
    let modifiedTextValue: String
    let createdTextValue: String

    nonisolated var id: URL { url }
    nonisolated var name: String { nameValue }
    nonisolated var searchName: String { searchNameValue }
    nonisolated var iconCacheKey: String { iconCacheKeyValue }
    nonisolated var mode: String { modeValue }
    nonisolated var sizeText: String { sizeTextValue }
    nonisolated var kindSortKey: String { kindSortKeyValue }
    var kindText: String {
        let kind = FileKindCache.shared.kind(for: url, isDirectory: isDirectory)
        return kind.isEmpty ? "-" : kind
    }
    nonisolated var modifiedText: String { modifiedTextValue }
    nonisolated var createdText: String { createdTextValue }
    var permissionsText: String {
        guard let permissions = FilePermissionCache.shared.permissions(for: url) else { return "-" }
        return String(format: "%03o", permissions)
    }

    nonisolated init(url: URL) {
        self.url = url

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey])
        isDirectory = values?.isDirectory == true
        isHidden = values?.isHidden == true || url.lastPathComponent.hasPrefix(".")
        size = Int64(values?.fileSize ?? 0)
        modified = values?.contentModificationDate
        created = values?.creationDate
        nameValue = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        searchNameValue = nameValue.localizedLowercase
        let extensionName = url.pathExtension.lowercased()
        iconCacheKeyValue = isDirectory ? "directory" : (extensionName.isEmpty ? "file" : "file.\(extensionName)")
        modeValue = isDirectory ? "drwx" : "-rw-"
        kindSortKeyValue = isDirectory ? "Folder" : extensionName
        sizeTextValue = isDirectory ? "-" : FileDisplayTextCache.shared.sizeText(byteCount: size)
        modifiedTextValue = FileDisplayTextCache.shared.dateText(for: modified)
        createdTextValue = FileDisplayTextCache.shared.dateText(for: created)
    }
}

private enum FileSortKey: String, CaseIterable, Identifiable {
    case fastName
    case name
    case size
    case kind
    case modified
    case created

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .fastName:
            return "Name"
        case .name:
            return "Name (Natural)"
        case .size:
            return "Size"
        case .kind:
            return "Kind"
        case .modified:
            return "Modified"
        case .created:
            return "Created"
        }
    }
}

private struct FileClipboard {
    enum Operation: Equatable {
        case copy
        case move
    }

    let urls: [URL]
    let operation: Operation
}

private enum FileConflictDecision {
    case use(URL, shouldReplace: Bool)
    case skip
    case cancel
}

private enum ConflictResolution {
    case replace
    case keepBoth
    case skip
    case cancel
}

private extension Notification.Name {
    static let pinnedFoldersDidChange = Notification.Name("TerminalFileManager.pinnedFoldersDidChange")
    static let fileManagerDirectoriesDidChange = Notification.Name("TerminalFileManager.directoriesDidChange")
}
#endif
