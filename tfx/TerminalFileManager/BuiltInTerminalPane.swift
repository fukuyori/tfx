#if os(macOS)
import SwiftUI

struct BuiltInTerminalPane: View {
    @ObservedObject var model: BuiltInTerminalModel
    @Binding var followsActiveFolder: Bool
    @FocusState.Binding var isInputFocused: Bool
    let activate: () -> Void

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

                Toggle("Follow", isOn: $followsActiveFolder)
                    .toggleStyle(.checkbox)
                    .font(design.fonts.swiftUIFont(for: .caption))
                    .foregroundStyle(theme.secondaryForeground)
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
        .overlay(
            Rectangle()
                .stroke(theme.paneBorderActive, lineWidth: 1)
        )
    }
}
#endif
