#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct BuiltInTerminalPane: View {
    @ObservedObject var model: BuiltInTerminalModel
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
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(theme.headerBackground.opacity(design.opacity.background))

            ScrollViewReader { proxy in
                ScrollView {
                    Text(model.transcript)
                        .font(design.fonts.swiftUIFont(for: .previewCode))
                        .foregroundStyle(theme.fileForeground)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .id("terminal-bottom")
                }
                .background(theme.fileListBackground.opacity(design.opacity.background))
                .onChange(of: model.transcript) {
                    proxy.scrollTo("terminal-bottom", anchor: .bottom)
                }
            }

            HStack(spacing: 8) {
                Text("$")
                    .font(design.fonts.swiftUIFont(for: .previewCode))
                    .foregroundStyle(theme.directoryForeground)

                TextField("Command", text: $model.commandText)
                    .textFieldStyle(.plain)
                    .font(design.fonts.swiftUIFont(for: .previewCode))
                    .foregroundStyle(theme.fileForeground)
                    .focused($isInputFocused)
                    .disabled(model.isRunning)
                    .onSubmit {
                        model.submitCommand()
                        activate()
                    }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(theme.statusLineBackground.opacity(design.opacity.background))
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
