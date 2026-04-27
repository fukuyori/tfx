#if os(macOS)
import SwiftUI

struct FilePaneTitleBar: View {
    @ObservedObject var model: FileBrowserModel
    let paneID: BrowserPaneID
    let isActivePane: Bool
    let isKeyboardTarget: Bool
    let activate: () -> Void

    var body: some View {
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
}
#endif
