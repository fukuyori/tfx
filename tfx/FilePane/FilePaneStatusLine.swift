#if os(macOS)
import SwiftUI

struct FilePaneStatusLine: View {
    @ObservedObject var model: FileBrowserModel
    let isKeyboardTarget: Bool
    let activate: () -> Void

    var body: some View {
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
#endif
