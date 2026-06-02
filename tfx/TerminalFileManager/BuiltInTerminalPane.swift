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

                HStack(spacing: 2) {
                    tabButton("Shell", tab: .shell)
                    if !model.commandOutputTranscript.isEmpty {
                        tabButton("Output", tab: .output)
                    }
                }

                HStack(spacing: 4) {
                    controlButton(label: "⌃C", help: "Send Ctrl+C") {
                        model.sendInterrupt()
                    }

                    controlButton(label: "⌃\\", help: "Send Ctrl+\\") {
                        model.sendQuit()
                    }

                    controlButton(label: "⌃Z", help: "Send Ctrl+Z") {
                        model.sendSuspend()
                    }
                }

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

            if model.activeTab == .output {
                outputView
                    .background(theme.fileListBackground.opacity(design.opacity.background))
            } else {
                XtermTerminalWebView(
                    model: model,
                    isActive: isActive,
                    theme: theme,
                    design: design,
                    isInputFocused: $isInputFocused,
                    isPathDropTarget: $isPathDropTarget,
                    activate: activate
                )
                .background(theme.fileListBackground.opacity(design.opacity.background))
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            if model.activeTab == .shell {
                activate()
            }
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

    private var outputView: some View {
        ScrollView {
            Text(model.commandOutputTranscript.isEmpty ? "No command output" : model.commandOutputTranscript)
                .font(design.fonts.swiftUIFont(for: .previewCode).monospaced())
                .foregroundStyle(theme.fileForeground)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(10)
                .textSelection(.enabled)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.showOutput()
        }
    }

    private func tabButton(_ title: LocalizedStringKey, tab: BuiltInTerminalModel.Tab) -> some View {
        Button {
            if tab == .shell {
                activate()
                model.open()
            } else {
                model.showOutput()
            }
        } label: {
            Text(title)
                .font(design.fonts.swiftUIFont(for: .caption))
                .foregroundStyle(model.activeTab == tab ? theme.folderTreeSelectedForeground : theme.secondaryForeground)
                .frame(minWidth: 46, minHeight: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            model.activeTab == tab ? theme.fileListRowSelected.opacity(0.55) : theme.headerBackground.opacity(0.45),
            in: RoundedRectangle(cornerRadius: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(model.activeTab == tab ? theme.paneBorderActive : theme.paneBorderInactive, lineWidth: 1)
        )
    }

    private func controlButton(
        label: LocalizedStringKey,
        help: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            activate()
            action()
        } label: {
            Text(label)
                .font(design.fonts.swiftUIFont(for: .caption).monospaced())
                .foregroundStyle(theme.headerForeground)
                .frame(minWidth: 30, minHeight: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(theme.fileListRowSelected.opacity(0.45), in: RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(theme.paneBorderInactive, lineWidth: 1)
        )
        .help(help)
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
