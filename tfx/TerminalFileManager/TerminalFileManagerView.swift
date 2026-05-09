#if os(macOS)
import AppKit
import Foundation
import SwiftUI

struct TerminalFileManagerView: View {
    @StateObject var leftModel: FileBrowserModel
    @StateObject var rightModel: FileBrowserModel
    @AppStorage("TerminalFileManager.isPreviewVisible") var isPreviewVisible = true
    @AppStorage("TerminalFileManager.isSplitViewVisible") var isSplitViewVisible = true
    @AppStorage("TerminalFileManager.activePane") var activePaneRawValue = BrowserPaneID.left.rawValue
    @AppStorage("TerminalFileManager.activeArea") var activeAreaRawValue = ActiveArea.files.rawValue
    @AppStorage("TerminalFileManager.folderTreeWidth") private var folderTreeWidth = 250.0
    @AppStorage("TerminalFileManager.previewWidth") private var previewWidth = 320.0
    @AppStorage("TerminalFileManager.fileSplitRatio") var fileSplitRatio = 0.5
    @AppStorage("TerminalFileManager.fileNameColumnWidth") var fileNameColumnWidth = 320.0
    @AppStorage("TerminalFileManager.fileColumnConfiguration") var fileColumnConfigurationRaw = FileListColumnConfiguration.defaultRawValue
    @StateObject private var openDirectoryRouter = AppOpenDirectoryRouter.shared
    @State private var folderDragStartWidth: Double?
    @State private var previewDragStartWidth: Double?
    @State var fileSplitDragStartRatio: Double?
    @State var isFileListSettingsPresented = false
    @State var hoverHelpText = ""
    @FocusState var isSearchFocused: Bool

    init(initialDirectory: URL? = AppLaunchArguments.initialDirectory()) {
        let defaults = UserDefaults.standard
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let leftURL = initialDirectory ?? Self.restoredDirectory(forKey: "TerminalFileManager.leftDirectory", fallback: homeURL)
        let rightURL = Self.restoredDirectory(forKey: "TerminalFileManager.rightDirectory", fallback: homeURL)

        _leftModel = StateObject(wrappedValue: FileBrowserModel(initialDirectory: leftURL))
        _rightModel = StateObject(wrappedValue: FileBrowserModel(initialDirectory: rightURL))

        if initialDirectory != nil {
            defaults.set(BrowserPaneID.left.rawValue, forKey: "TerminalFileManager.activePane")
            defaults.set(ActiveArea.files.rawValue, forKey: "TerminalFileManager.activeArea")
        }

        let activePane = defaults.string(forKey: "TerminalFileManager.activePane") ?? BrowserPaneID.left.rawValue
        if BrowserPaneID(rawValue: activePane) == nil {
            defaults.set(BrowserPaneID.left.rawValue, forKey: "TerminalFileManager.activePane")
        }
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
                        .frame(width: folderWidth, height: geometry.size.height)

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
                            .frame(width: previewPaneWidth, height: geometry.size.height)
                    }
                }
            }
        }
        .background(WindowFrameAutosaver(name: "TerminalFileManagerWindow"))
        .background(KeyboardEventHandler(isEnabled: !isSearchFocused) { event in
            handleKeyEvent(event)
        })
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            openRequestedDirectoryIfNeeded()
        }
        .onChange(of: openDirectoryRouter.request) {
            openRequestedDirectoryIfNeeded()
        }
        .onChange(of: leftModel.currentDirectory) {
            UserDefaults.standard.set(leftModel.currentDirectory.path, forKey: "TerminalFileManager.leftDirectory")
            isSearchFocused = false
        }
        .onChange(of: rightModel.currentDirectory) {
            UserDefaults.standard.set(rightModel.currentDirectory.path, forKey: "TerminalFileManager.rightDirectory")
            isSearchFocused = false
        }
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

}

#endif
