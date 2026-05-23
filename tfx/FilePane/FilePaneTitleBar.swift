#if os(macOS)
import SwiftUI

struct FilePaneTitleBar: View {
    @ObservedObject var model: FileBrowserModel
    let paneID: BrowserPaneID
    let isActivePane: Bool
    let isKeyboardTarget: Bool
    let activate: () -> Void

    @State private var pathInput: String = ""
    @FocusState private var isPathFieldFocused: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $pathInput)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .foregroundStyle(isActivePane ? theme.statusLineForegroundActive : theme.secondaryForeground)
                .focused($isPathFieldFocused)
                .onSubmit {
                    commitPathInput()
                }
                .onExitCommand {
                    pathInput = currentPathString
                    isPathFieldFocused = false
                }
                .onChange(of: isPathFieldFocused) {
                    if isPathFieldFocused {
                        activate()
                    } else {
                        pathInput = currentPathString
                    }
                }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isKeyboardTarget ? theme.titleBarBackgroundActive : (isActivePane ? theme.titleBarBackgroundActive.opacity(0.5) : theme.titleBarBackgroundInactive))
        .onAppear {
            pathInput = currentPathString
        }
        .onChange(of: model.currentDirectory) {
            if !isPathFieldFocused {
                pathInput = currentPathString
            }
        }
    }

    private var currentPathString: String {
        model.currentDirectory.path(percentEncoded: false)
    }

    private func commitPathInput() {
        let trimmed = pathInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = (trimmed as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardizedFileURL

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            pathInput = currentPathString
            isPathFieldFocused = false
            return
        }

        activate()
        model.navigate(to: url)
        isPathFieldFocused = false
    }
}
#endif
