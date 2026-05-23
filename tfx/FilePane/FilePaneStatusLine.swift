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

    var body: some View {
        HStack {
            statusText
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text("| Free \(model.availableCapacityText)")
                .fixedSize(horizontal: true, vertical: false)
            if let gitStatus = model.gitRepositoryStatus {
                // The branch indicator only renders for directories
                // inside a Git work tree. Detached HEAD falls back to a
                // short SHA via `GitRepositoryStatus.branchDisplayText`.
                Text("| \(gitStatus.branchDisplayText)")
                    .fixedSize(horizontal: true, vertical: false)
            }
            if model.selectionCount > 0 {
                Text("| \(model.selectionCount) selected")
                    .fixedSize(horizontal: true, vertical: false)
            }
            primarySelectionText
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
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
