#if os(macOS)
import SwiftUI

struct FilePaneStatusLine: View {
    @ObservedObject var model: FileBrowserModel
    let isKeyboardTarget: Bool
    let activate: () -> Void

    var body: some View {
        HStack {
            statusText
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text("| Free \(model.availableCapacityText)")
                .fixedSize(horizontal: true, vertical: false)
            if model.selectionCount > 0 {
                Text("| \(model.selectionCount) selected")
                    .fixedSize(horizontal: true, vertical: false)
            }
            Text(model.primarySelectedItem?.url.path(percentEncoded: false) ?? "No selection")
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
    }

    private var statusText: Text {
        if let subfolderSearchStatusText = model.subfolderSearchStatusText {
            Text(subfolderSearchStatusText)
        } else {
            Text("\(model.items.count) of \(model.allItemCount) items")
        }
    }
}
#endif
