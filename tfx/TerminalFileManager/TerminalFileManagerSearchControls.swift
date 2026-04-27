#if os(macOS)
import SwiftUI

extension TerminalFileManagerView {
    var pathAndSearchControls: some View {
        Group {
            Text(model.currentDirectory.path(percentEncoded: false))
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))

            TextField("Search", text: Binding(
                get: { model.searchText },
                set: { model.searchText = $0 }
            ))
                .textFieldStyle(.roundedBorder)
                .font(.system(.callout, design: .monospaced))
                .frame(width: 180)
                .focused($isSearchFocused)

            Button {
                isSearchFocused = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("f", modifiers: .command)
            .quickHelp("Focus search", text: $hoverHelpText)
        }
    }

    var sortAndVisibilityControls: some View {
        Group {
            Menu {
                Picker("Sort", selection: Binding(
                    get: { model.sortKey },
                    set: { model.sortKey = $0 }
                )) {
                    ForEach(FileSortKey.allCases) { key in
                        Text(key.title).tag(key)
                    }
                }

                Divider()

                Button(model.sortAscending ? "Descending" : "Ascending") {
                    model.sortAscending.toggle()
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .quickHelp("Sort", text: $hoverHelpText)

            Toggle(isOn: Binding(
                get: { model.showHiddenFiles },
                set: { model.showHiddenFiles = $0 }
            )) {
                Image(systemName: "eye")
            }
            .toggleStyle(.button)
            .keyboardShortcut(".", modifiers: [.command, .shift])
            .quickHelp("Show hidden files", text: $hoverHelpText)
        }
    }
}
#endif
