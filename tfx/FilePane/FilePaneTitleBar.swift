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
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        // CRITICAL: SwiftUI's `TextField` (plain style) ignores
        // `.lineLimit(1)` for sizing — it claims an intrinsic width
        // equal to the displayed text and refuses to be narrower than
        // that, even with `.frame(minWidth: 0, maxWidth: .infinity)`.
        // That intrinsic min bubbles up through every parent and
        // makes the whole file pane refuse to honor its allotted
        // `.frame(width: paneWidth)`, leading to the persistent
        // overlap symptom. So show a (shrinkable) `Text` for display
        // and only swap to `TextField` while the user is editing.
        HStack(spacing: 8) {
            if isPathFieldFocused {
                TextField("", text: $pathInput)
                    .textFieldStyle(.plain)
                    .font(design.fonts.swiftUIFont(for: .paneTitle))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(isActivePane ? theme.statusLineForegroundActive : theme.secondaryForeground)
                    .focused($isPathFieldFocused)
                    .onSubmit {
                        commitPathInput()
                    }
                    .onExitCommand {
                        pathInput = currentPathString
                        isPathFieldFocused = false
                    }
            } else {
                Text(pathInput)
                    .font(design.fonts.swiftUIFont(for: .paneTitle))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(isActivePane ? theme.statusLineForegroundActive : theme.secondaryForeground)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPathFieldFocused = true
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(titleBackground.opacity(design.opacity.background))
        .onChange(of: isPathFieldFocused) {
            if isPathFieldFocused {
                activate()
            } else {
                pathInput = currentPathString
            }
        }
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

    private var titleBackground: Color {
        if isKeyboardTarget {
            return theme.titleBarBackgroundActive
        }

        if isActivePane {
            return theme.titleBarBackgroundActive.opacity(design.opacity.inactivePane)
        }

        return theme.titleBarBackgroundInactive
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
