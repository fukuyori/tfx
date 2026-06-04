#if os(macOS)
import SwiftUI

struct FilePaneTitleBar: View {
    @ObservedObject var model: FileBrowserModel
    let paneID: BrowserPaneID
    let isActivePane: Bool
    let isKeyboardTarget: Bool
    let activate: () -> Void

    @State private var pathInput: String = ""
    /// Drives which subview is shown (display `Text` vs editable
    /// `TextField`). Kept separate from `isPathFieldFocused` so that
    /// the field is mounted *before* we ask for focus — setting focus
    /// in the same render pass that inserts the field is unreliable and
    /// was why clicking the address bar appeared to do nothing.
    @State private var isEditing = false
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
            if isEditing {
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
                        endEditing()
                    }
                    .onAppear {
                        // Defer to the next runloop tick: the field has
                        // to exist (and be first-responder eligible)
                        // before the `.focused` binding can take, or the
                        // focus request is silently dropped.
                        DispatchQueue.main.async {
                            isPathFieldFocused = true
                        }
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
                        beginEditing()
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(titleBackground.opacity(design.opacity.background))
        .onChange(of: isPathFieldFocused) {
            // Focus lost while still editing (the user clicked away
            // without pressing Return) — leave edit mode and restore
            // the displayed path.
            if !isPathFieldFocused, isEditing {
                endEditing()
            }
        }
        .onAppear {
            pathInput = currentPathString
        }
        .onChange(of: model.currentDirectory) {
            if !isEditing {
                pathInput = currentPathString
            }
        }
    }

    private func beginEditing() {
        activate()
        pathInput = currentPathString
        isEditing = true
        // Focus is requested from the field's `.onAppear`.
    }

    /// Leave edit mode and discard any uncommitted text.
    private func endEditing() {
        pathInput = currentPathString
        isEditing = false
        isPathFieldFocused = false
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
            endEditing()
            return
        }

        activate()
        model.navigate(to: url)
        isEditing = false
        isPathFieldFocused = false
    }
}
#endif
