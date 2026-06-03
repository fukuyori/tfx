#if os(macOS)
import SwiftUI

struct FilePaneStatusLine: View {
    @ObservedObject var model: FileBrowserModel
    let isKeyboardTarget: Bool
    let activate: () -> Void
    /// True after the model has been loading long enough that a hint is
    /// worth showing. Driven by a `Task`-based delay below so a snappy
    /// local load does not flicker the indicator.
    @State private var showsLoadingHint = false
    @State private var loadingHintTask: Task<Void, Never>?
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        // EVERY child of FilePane (including this status line) must
        // be shrinkable, because SwiftUI's `.frame(width: paneWidth)`
        // is only a *proposal*: if any descendant's intrinsic minimum
        // is larger than the proposed width, the pane overflows the
        // proposal and draws on top of adjacent panes (erasing their
        // active borders). The previous `.fixedSize(horizontal: true)`
        // on the middle status texts made this status line claim a
        // ~200pt minimum, which forced the whole file pane wider than
        // the layout allowed at the window's minimum width.
        //
        // Now every Text uses `.lineLimit(1).truncationMode(.tail)`
        // and the side texts keep their flexible `maxWidth: .infinity`
        // wrappers, so the row gracefully truncates from the right
        // when the pane is narrow.
        HStack(spacing: 6) {
            statusText
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text("| Free \(model.availableCapacityText)")
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            if let gitStatus = model.gitRepositoryStatus {
                Text("| \(gitStatus.branchDisplayText)")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }
            if model.selectionCount > 0 {
                Text("| \(model.selectionCount) selected")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }
            primarySelectionText
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
        }
        .font(design.fonts.swiftUIFont(for: .statusLine))
        .foregroundStyle(isKeyboardTarget ? theme.statusLineForegroundActive : theme.statusLineForegroundInactive)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(theme.statusLineBackground.opacity(design.opacity.background))
        .contentShape(Rectangle())
        .onTapGesture {
            activate()
        }
        .onChange(of: model.isLoadingDirectory, initial: true) { _, isLoading in
            loadingHintTask?.cancel()
            if isLoading {
                let task = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    if !Task.isCancelled {
                        showsLoadingHint = true
                    }
                }
                loadingHintTask = task
            } else {
                showsLoadingHint = false
            }
        }
    }

    private var statusText: Text {
        if showsLoadingHint && model.isLoadingDirectory {
            Text("Loading…")
        } else if let subfolderSearchStatusText = model.subfolderSearchStatusText {
            Text(subfolderSearchStatusText)
        } else {
            Text("\(model.items.count) of \(model.allItemCount) items")
        }
    }

    private var primarySelectionText: Text {
        if let path = model.primarySelectedItem?.url.path(percentEncoded: false) {
            Text(path)
        } else {
            Text("No selection")
        }
    }
}
#endif
