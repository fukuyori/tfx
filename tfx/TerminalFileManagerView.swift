#if os(macOS)
import AppKit
import AVKit
import Combine
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

                        PreviewPane(url: activeModel.primarySelectedItem?.url)
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
            .help("Back")

            Button {
                model.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(!model.canGoForward)
            .keyboardShortcut("]", modifiers: .command)
            .help("Forward")

            Button {
                model.goUp()
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.upArrow, modifiers: .command)
            .help("Parent folder")

            Button {
                model.pickFolder()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Open folder")

            Button {
                model.togglePinnedFolder(model.currentDirectory)
            } label: {
                Image(systemName: model.isFolderPinned(model.currentDirectory) ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .help(model.isFolderPinned(model.currentDirectory) ? "Unpin current folder" : "Pin current folder")

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
            .help("Focus search")

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
            .help("Sort")

            Toggle(isOn: Binding(
                get: { model.showHiddenFiles },
                set: { model.showHiddenFiles = $0 }
            )) {
                Image(systemName: "eye")
            }
            .toggleStyle(.button)
            .keyboardShortcut(".", modifiers: [.command, .shift])
            .help("Show hidden files")

            Button {
                model.createFolder()
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("n", modifiers: .command)
            .help("New folder")

            Button {
                model.renameSelectedItem()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .disabled(model.selectionCount != 1)
            .keyboardShortcut(.return, modifiers: [])
            .help("Rename")

            Button {
                model.moveSelectedItemsToTrash()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(!model.hasSelection)
            .keyboardShortcut(.delete, modifiers: [])
            .help("Move to Trash")

            Button {
                model.copySelectedItems()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .disabled(!model.hasSelection)
            .keyboardShortcut("c", modifiers: .command)
            .help("Copy selected items")

            Button {
                model.cutSelectedItems()
            } label: {
                Image(systemName: "scissors")
            }
            .buttonStyle(.borderless)
            .disabled(!model.hasSelection)
            .keyboardShortcut("x", modifiers: .command)
            .help("Cut selected items")

            Button {
                model.pasteItems()
            } label: {
                Image(systemName: "clipboard")
            }
            .buttonStyle(.borderless)
            .disabled(!model.canPaste)
            .keyboardShortcut("v", modifiers: .command)
            .help("Paste into current folder")

            Button {
                model.revealSelectedItemsInFinder()
            } label: {
                Image(systemName: "finder")
            }
            .buttonStyle(.borderless)
            .disabled(!model.hasSelection)
            .help("Reveal in Finder")

            Button {
                model.selectAllVisibleItems()
            } label: {
                Image(systemName: "checklist")
            }
            .buttonStyle(.borderless)
            .disabled(model.items.isEmpty)
            .keyboardShortcut("a", modifiers: .command)
            .help("Select all")

            Button {
                model.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("r", modifiers: .command)
            .help("Reload")

            Button {
                model.openTerminal()
            } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .help("Open Terminal here")

            Toggle(isOn: $isPreviewVisible) {
                Image(systemName: "sidebar.right")
            }
            .toggleStyle(.button)
            .keyboardShortcut("p", modifiers: [.command, .option])
            .help(isPreviewVisible ? "Hide preview" : "Show preview")

            Toggle(isOn: $isSplitViewVisible) {
                Image(systemName: "rectangle.split.2x1")
            }
            .toggleStyle(.button)
            .keyboardShortcut("s", modifiers: [.command, .option])
            .help(isSplitViewVisible ? "Use single pane" : "Use split panes")

            Button {
                isFileListSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("File list settings")

            Button {
                model.copyPath(model.currentDirectory)
            } label: {
                Image(systemName: "link")
            }
            .buttonStyle(.borderless)
            .help("Copy current path")
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isFileListSettingsPresented) {
            FileListSettingsView(
                configurationRaw: $fileColumnConfigurationRaw
            )
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

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ParentDirectoryRow(
                                isEnabled: model.canGoUp,
                                isSelected: model.isParentDirectorySelected,
                                columns: visibleColumns,
                                fileNameColumnWidth: fileNameColumnWidth
                            )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    activate()
                                    model.selectParentDirectory()
                                    model.goUp()
                                }
                                .onTapGesture(count: 2) {
                                    activate()
                                    model.selectParentDirectory()
                                    model.goUp()
                                }

                            ForEach(model.items) { item in
                                FileRow(
                                    item: item,
                                    isSelected: model.isSelected(item),
                                    columns: visibleColumns,
                                    fileNameColumnWidth: fileNameColumnWidth
                                )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        activate()
                                        if NSEvent.modifierFlags.contains(.shift) {
                                            model.selectRange(to: item)
                                        } else {
                                            model.select(item, extending: NSEvent.modifierFlags.contains(.command))
                                        }
                                    }
                                    .onTapGesture(count: 2) {
                                        activate()
                                        model.open(item)
                                    }
                                    .draggable(item.url)
                                    .onDrop(
                                        of: [UTType.fileURL.identifier],
                                        delegate: FileDropDelegate(
                                            model: model,
                                            targetDirectory: item.isDirectory ? item.url : model.currentDirectory,
                                            reloadRelatedPanes: {
                                                activate()
                                                reloadRelatedPanes()
                                            }
                                        )
                                    )
                                    .contextMenu {
                                        fileContextMenu(for: item)
                                    }
                            }
                        }
                    }
                    .background(Color.black)
                }
                .frame(minWidth: rowMinWidth)
            }
            .onTapGesture {
                activate()
            }
            .onDrop(
                of: [UTType.fileURL.identifier],
                delegate: FileDropDelegate(
                    model: model,
                    targetDirectory: model.currentDirectory,
                    reloadRelatedPanes: {
                        activate()
                        reloadRelatedPanes()
                    }
                )
            )

            statusLine
        }
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isKeyboardTarget ? Color.green : (isActivePane ? Color.green.opacity(0.45) : Color.gray.opacity(0.35)), lineWidth: isKeyboardTarget ? 2 : 1)
        )
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
            reloadRelatedPanes()
        }

        Button("Move to Trash") {
            activate()
            model.selectForContextMenu(item)
            model.moveSelectedItemsToTrash()
            reloadRelatedPanes()
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
            reloadRelatedPanes()
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

            ScrollView {
                LazyVStack(spacing: 0) {
                    if !model.pinnedFolders.isEmpty {
                        FolderTreeSectionHeader(title: "PINNED")

                        ForEach(model.pinnedFolders, id: \.self) { pinnedFolder in
                            FolderTreeRow(model: model, url: pinnedFolder, depth: 0, isTreeActive: isActive, activateTree: activate)
                        }

                        FolderTreeSectionHeader(title: "FOLDERS")
                    }

                    ForEach(roots, id: \.self) { root in
                        FolderTreeRow(model: model, url: root, depth: 0, isTreeActive: isActive, activateTree: activate)
                    }
                }
            }
            .background(Color.black)
            .contentShape(Rectangle())
            .onTapGesture {
                activate()
                model.ensureFolderTreeSelection()
            }
            .onDrop(
                of: [UTType.fileURL.identifier],
                delegate: FileDropDelegate(model: model, targetDirectory: model.currentDirectory)
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isActive ? Color.green : Color.gray.opacity(0.35), lineWidth: isActive ? 2 : 1)
        )
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
    let activateTree: () -> Void

    private var isCurrent: Bool {
        model.currentDirectory.standardizedFileURL == url.standardizedFileURL
    }

    private var isSelected: Bool {
        model.isFolderTreeSelected(url)
    }

    private var isExpanded: Bool {
        model.isFolderExpanded(url)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    activateTree()
                    model.selectFolderTree(url)
                    model.toggleFolderExpansion(url)
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .frame(width: 14)
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
            .contentShape(Rectangle())
            .onTapGesture {
                activateTree()
                model.selectFolderTree(url)
                model.navigate(to: url)
                model.expandFolder(url)
            }
            .onDrop(
                of: [UTType.fileURL.identifier],
                delegate: FileDropDelegate(model: model, targetDirectory: url)
            )
            .contextMenu {
                Button("Open") {
                    activateTree()
                    model.selectFolderTree(url)
                    model.navigate(to: url)
                    model.expandFolder(url)
                }

                Button("Reveal in Finder") {
                    model.revealInFinder(url)
                }

                Button("Copy Path") {
                    model.copyPath(url)
                }

                Button(model.isFolderPinned(url) ? "Unpin Folder" : "Pin Folder") {
                    activateTree()
                    model.selectFolderTree(url)
                    model.togglePinnedFolder(url)
                }

                Button("Paste Here") {
                    model.pasteItems(into: url)
                }
                .disabled(!model.canPaste)

                Button("Open Terminal Here") {
                    model.openTerminal(at: url)
                }
            }

            if isExpanded {
                ForEach(model.childrenForFolder(url), id: \.self) { child in
                    FolderTreeRow(model: model, url: child, depth: depth + 1, isTreeActive: isTreeActive, activateTree: activateTree)
                }
            }
        }
        .onChange(of: model.items) {
            if isExpanded {
                model.refreshFolderChildren(url)
            }
        }
    }

    private func displayName(for url: URL) -> String {
        if url.path == "/" {
            return "/"
        }

        return FileManager.default.displayName(atPath: url.path)
    }

    private var rowBackground: Color {
        if isTreeActive && isSelected {
            return Color.green.opacity(0.45)
        }

        if isSelected {
            return Color.gray.opacity(0.35)
        }

        if isCurrent {
            return Color.accentColor.opacity(0.65)
        }

        return Color.black
    }
}

private struct FileRow: View {
    let item: FileItem
    let isSelected: Bool
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
        .background(isSelected ? Color.accentColor.opacity(0.55) : Color.black)
    }

    @ViewBuilder
    private func fileCell(for column: FileListColumn) -> some View {
        switch column {
        case .icon:
            FileIcon(url: item.url)
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
}

private struct FileIcon: View {
    let url: URL

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .frame(width: 18, height: 18)
            .accessibilityHidden(true)
    }

    private var icon: NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }
}

private struct PreviewPane: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                switch PreviewKind(url: url) {
                case .pdf:
                    PDFPreview(url: url)
                case .video:
                    VideoPreview(url: url)
                case .markdown:
                    MarkdownPreview(url: url)
                case .quickLook:
                    QuickLookPreview(url: url)
                }
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
    }
}

private struct PDFPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
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
}

private struct MarkdownPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let markdown = (try? String(contentsOf: url, encoding: .utf8))
            ?? String(decoding: ((try? Data(contentsOf: url)) ?? Data()), as: UTF8.self)
        nsView.loadHTMLString(Self.htmlDocument(for: markdown), baseURL: url.deletingLastPathComponent())
    }

    private static func htmlDocument(for markdown: String) -> String {
        """
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
        \(markdownToHTML(markdown))
        </body>
        </html>
        """
    }

    private static func markdownToHTML(_ markdown: String) -> String {
        var html: [String] = []
        var paragraph: [String] = []
        var listItems: [String] = []
        var codeBlock: [String] = []
        var isInCodeBlock = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            html.append("<p>\(inlineHTML(paragraph.joined(separator: " ")))</p>")
            paragraph.removeAll()
        }

        func flushList() {
            guard !listItems.isEmpty else { return }
            html.append("<ul>\(listItems.joined())</ul>")
            listItems.removeAll()
        }

        func flushCodeBlock() {
            guard !codeBlock.isEmpty else { return }
            html.append("<pre><code>\(escapeHTML(codeBlock.joined(separator: "\n")))</code></pre>")
            codeBlock.removeAll()
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
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

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = true
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as NSURL
    }
}

private enum PreviewKind {
    case pdf
    case video
    case markdown
    case quickLook

    init(url: URL) {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: url.pathExtension)
        let extensionName = url.pathExtension.lowercased()

        if type?.conforms(to: .pdf) == true {
            self = .pdf
        } else if type?.conforms(to: .movie) == true {
            self = .video
        } else if ["md", "markdown", "mdown", "mkd"].contains(extensionName) {
            self = .markdown
        } else {
            self = .quickLook
        }
    }
}

private final class FileBrowserModel: ObservableObject {
    @Published var currentDirectory = URL(fileURLWithPath: NSHomeDirectory())
    @Published var items: [FileItem] = []
    @Published var selectedItemIDs: Set<FileItem.ID> = []
    @Published var primarySelectedItemID: FileItem.ID?
    @Published var isParentDirectorySelected = false
    @Published var folderTreeSelection: URL?
    @Published var isShowingError = false
    @Published var errorMessage = ""
    @Published var searchText = "" {
        didSet {
            applyFiltersAndSort()
        }
    }
    @Published var showHiddenFiles = false {
        didSet {
            applyFiltersAndSort()
        }
    }
    @Published var sortKey = FileSortKey.name {
        didSet {
            applyFiltersAndSort()
        }
    }
    @Published var sortAscending = true {
        didSet {
            applyFiltersAndSort()
        }
    }
    @Published private var expandedFolders: Set<URL> = []
    @Published private var folderChildrenCache: [URL: [URL]] = [:]
    @Published private(set) var availableCapacityText = "-"
    @Published private(set) var pinnedFolders: [URL] = []

    private var allItems: [FileItem] = []
    private var backStack: [URL] = []
    private var forwardStack: [URL] = []
    private var selectionAnchorItemID: FileItem.ID?
    private var clipboard: FileClipboard?
    private var pinnedFoldersObserver: AnyCancellable?
    private let pinnedFoldersKey = "TerminalFileManager.pinnedFolders"

    init(initialDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        currentDirectory = initialDirectory.standardizedFileURL
        folderTreeSelection = currentDirectory
        pinnedFoldersObserver = NotificationCenter.default
            .publisher(for: .pinnedFoldersDidChange)
            .sink { [weak self] _ in
                self?.loadPinnedFolders()
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
        return allItems.first { $0.id == primarySelectedItemID }
    }

    var selectedItems: [FileItem] {
        allItems.filter { selectedItemIDs.contains($0.id) }
    }

    var selectedFolderTreeURL: URL {
        folderTreeSelection ?? currentDirectory
    }

    func reload() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: currentDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .isHiddenKey, .localizedTypeDescriptionKey],
                options: [.skipsPackageDescendants]
            )

            allItems = urls.map(FileItem.init)
            updateAvailableCapacity()
            applyFiltersAndSort()

            pruneSelection()
        } catch {
            show(error)
        }
    }

    func isSelected(_ item: FileItem) -> Bool {
        selectedItemIDs.contains(item.id)
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
        } else if let primarySelectedItemID, let itemIndex = items.firstIndex(where: { $0.id == primarySelectedItemID }) {
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
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else {
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
            if let primarySelectedItemID, items.contains(where: { $0.id == primarySelectedItemID }) {
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
            let anchorIndex = items.firstIndex(where: { $0.id == anchorID })
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

    func isFolderTreeSelected(_ url: URL) -> Bool {
        selectedFolderTreeURL.standardizedFileURL == url.standardizedFileURL
    }

    func selectFolderTree(_ url: URL) {
        folderTreeSelection = url.standardizedFileURL
    }

    func ensureFolderTreeSelection() {
        if visibleTreeFolders().contains(selectedFolderTreeURL.standardizedFileURL) {
            return
        }

        folderTreeSelection = currentDirectory.standardizedFileURL
    }

    func moveFolderTreeSelection(delta: Int) {
        let folders = visibleTreeFolders()
        guard !folders.isEmpty else { return }

        let selectedURL = selectedFolderTreeURL.standardizedFileURL
        let currentIndex = folders.firstIndex { $0.standardizedFileURL == selectedURL } ?? (delta >= 0 ? -1 : folders.count)
        let nextIndex = clampIndex(currentIndex + delta, count: folders.count)
        selectFolderTree(folders[nextIndex])
    }

    func moveFolderTreeLeft() {
        let selectedURL = selectedFolderTreeURL.standardizedFileURL

        if isFolderExpanded(selectedURL) {
            toggleFolderExpansion(selectedURL)
            return
        }

        let parent = selectedURL.deletingLastPathComponent()
        guard parent != selectedURL else { return }
        expandAncestors(of: parent)
        selectFolderTree(parent)
    }

    func moveFolderTreeRight() {
        let selectedURL = selectedFolderTreeURL.standardizedFileURL

        if !isFolderExpanded(selectedURL) {
            expandFolder(selectedURL)
            return
        }

        if let firstChild = childrenForFolder(selectedURL).first {
            selectFolderTree(firstChild)
        }
    }

    func activateFolderTreeSelection() {
        let selectedURL = selectedFolderTreeURL.standardizedFileURL
        guard isDirectory(selectedURL) else { return }
        navigate(to: selectedURL)
        expandFolder(selectedURL)
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

    func visibleTreeFolders() -> [URL] {
        var folders: [URL] = []
        var seen = Set<URL>()

        for pinnedFolder in pinnedFolders {
            appendVisibleFolder(pinnedFolder, to: &folders, seen: &seen)
        }

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
        pinnedFolders.sort {
            displayName(for: $0).localizedStandardCompare(displayName(for: $1)) == .orderedAscending
        }
        savePinnedFolders()
    }

    func unpinFolder(_ url: URL) {
        let folderURL = url.standardizedFileURL
        pinnedFolders.removeAll { $0.standardizedFileURL == folderURL }
        savePinnedFolders()
    }

    func refreshFolderChildren(_ url: URL) {
        let key = url.standardizedFileURL

        do {
            folderChildrenCache[key] = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            .filter { child in
                (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted {
                displayName(for: $0).localizedStandardCompare(displayName(for: $1)) == .orderedAscending
            }
        } catch {
            folderChildrenCache[key] = []
        }
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
        let availableIDs = Set(items.map(\.id))
        selectedItemIDs = selectedItemIDs.intersection(availableIDs)

        if isParentDirectorySelected, !canGoUp {
            isParentDirectorySelected = false
        }

        if let primarySelectedItemID, !selectedItemIDs.contains(primarySelectedItemID) {
            self.primarySelectedItemID = selectedItemIDs.first
        }

        if let selectionAnchorItemID, !availableIDs.contains(selectionAnchorItemID) {
            self.selectionAnchorItemID = primarySelectedItemID
        }

        if selectedItemIDs.isEmpty {
            primarySelectedItemID = nil
            selectionAnchorItemID = nil
        }
    }

    private func applyFiltersAndSort() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        items = allItems
            .filter { item in
                (showHiddenFiles || !item.isHidden)
                    && (query.isEmpty || item.name.localizedCaseInsensitiveContains(query))
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }

                let result: ComparisonResult

                switch sortKey {
                case .name:
                    result = lhs.name.localizedStandardCompare(rhs.name)
                case .size:
                    result = lhs.size == rhs.size ? .orderedSame : (lhs.size < rhs.size ? .orderedAscending : .orderedDescending)
                case .kind:
                    result = lhs.kind.localizedStandardCompare(rhs.kind)
                case .modified:
                    result = compare(lhs.modified, rhs.modified)
                case .created:
                    result = compare(lhs.created, rhs.created)
                }

                if result == .orderedSame {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }

                return sortAscending ? result == .orderedAscending : result == .orderedDescending
            }
    }

    private func compare(_ lhs: Date?, _ rhs: Date?) -> ComparisonResult {
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
            .sorted {
                displayName(for: $0).localizedStandardCompare(displayName(for: $1)) == .orderedAscending
            }
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
            reload()
            if let item = items.first(where: { $0.url.standardizedFileURL == folderURL.standardizedFileURL }) {
                select(item)
            }
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
            reload()
            if let item = items.first(where: { $0.url.standardizedFileURL == destination.standardizedFileURL }) {
                select(item)
            }
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
            reload()
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
                    }

                    pastedURLs.append(destinationURL)
                }
            }

            if clipboard.operation == .move {
                self.clipboard = nil
            }

            refreshFolderChildren(targetDirectory)
            reload()
            selectedItemIDs = Set(pastedURLs)
            primarySelectedItemID = pastedURLs.last
            selectionAnchorItemID = pastedURLs.first
            pruneSelection()
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
            reload()
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
            availableCapacityText = ByteCountFormatter.string(fromByteCount: Int64(availableCapacity), countStyle: .file)
        } else {
            availableCapacityText = "-"
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
    var reloadRelatedPanes: (() -> Void)?

    func performDrop(info: DropInfo) -> Bool {
        model.moveDroppedFiles(
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

private struct FileItem: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let isHidden: Bool
    let size: Int64
    let modified: Date?
    let created: Date?
    let kind: String
    let permissions: Int?

    var id: URL { url }
    var name: String { url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent }
    var mode: String { isDirectory ? "drwx" : "-rw-" }
    var sizeText: String { isDirectory ? "-" : ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
    var kindText: String { kind.isEmpty ? "-" : kind }
    var modifiedText: String {
        guard let modified else { return "-" }
        return Self.dateFormatter.string(from: modified)
    }
    var createdText: String {
        guard let created else { return "-" }
        return Self.dateFormatter.string(from: created)
    }
    var permissionsText: String {
        guard let permissions else { return "-" }
        return String(format: "%03o", permissions)
    }

    nonisolated init(url: URL) {
        self.url = url

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .localizedTypeDescriptionKey])
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        isDirectory = values?.isDirectory == true
        isHidden = values?.isHidden == true || url.lastPathComponent.hasPrefix(".")
        size = Int64(values?.fileSize ?? 0)
        modified = values?.contentModificationDate
        created = values?.creationDate
        kind = values?.localizedTypeDescription ?? (isDirectory ? "Folder" : url.pathExtension.uppercased())
        permissions = (attributes?[.posixPermissions] as? NSNumber)?.intValue
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

private enum FileSortKey: String, CaseIterable, Identifiable {
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
}
#endif
