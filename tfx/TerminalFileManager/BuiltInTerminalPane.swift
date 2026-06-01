#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BuiltInTerminalPane: View {
    @ObservedObject var model: BuiltInTerminalModel
    let isActive: Bool
    @FocusState.Binding var isInputFocused: Bool
    let activate: () -> Void

    @State private var isPathDropTarget = false
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundStyle(theme.headerForeground)

                Text(model.currentDirectory.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(design.fonts.swiftUIFont(for: .caption))
                    .foregroundStyle(theme.headerForeground)

                Spacer(minLength: 8)

                Button {
                    activate()
                    model.sendInterrupt()
                } label: {
                    Image(systemName: "stop.circle")
                        .foregroundStyle(theme.headerForeground)
                }
                .buttonStyle(.plain)
                .help("Send Ctrl+C")
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(theme.headerBackground.opacity(design.opacity.background))

            XtermTerminalWebView(
                model: model,
                isActive: isActive,
                theme: theme,
                design: design,
                isInputFocused: $isInputFocused,
                activate: activate
            )
            .background(theme.fileListBackground.opacity(design.opacity.background))
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            activate()
        })
        .onDrop(
            of: [UTType.fileURL.identifier],
            delegate: BuiltInTerminalPathDropDelegate(
                model: model,
                isDropTarget: $isPathDropTarget,
                activate: activate
            )
        )
        .overlay(
            Rectangle()
                .stroke(isPathDropTarget ? theme.paneBorderKeyboardTarget : theme.paneBorderActive, lineWidth: isPathDropTarget ? 2 : 1)
        )
    }
}

private struct BuiltInTerminalPathDropDelegate: DropDelegate {
    let model: BuiltInTerminalModel
    @Binding var isDropTarget: Bool
    let activate: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.fileURL.identifier])
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }
        isDropTarget = true
        activate()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        validateDrop(info: info) ? DropProposal(operation: .copy) : DropProposal(operation: .forbidden)
    }

    func dropExited(info: DropInfo) {
        isDropTarget = false
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { isDropTarget = false }
        guard validateDrop(info: info) else { return false }

        activate()
        return FileBrowserDropProviderLoader.loadFileURLs(
            from: info.itemProviders(for: [UTType.fileURL.identifier]),
            onError: { _ in },
            onURL: { url in
                model.insertPaths([url])
                activate()
            }
        )
    }
}
#endif
