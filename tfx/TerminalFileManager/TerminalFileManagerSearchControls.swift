#if os(macOS)
import SwiftUI

extension TerminalFileManagerView {
    var pathAndSearchControls: some View {
        Group {
            PathBreadcrumbBar(directory: model.currentDirectory) { directory in
                model.navigate(to: directory)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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

private struct PathBreadcrumbBar: View {
    let directory: URL
    let navigate: (URL) -> Void

    private var breadcrumbs: [PathBreadcrumb] {
        PathBreadcrumb.breadcrumbs(for: directory)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(breadcrumbs.enumerated()), id: \.element.id) { index, breadcrumb in
                        Button {
                            navigate(breadcrumb.url)
                        } label: {
                            Text(breadcrumb.title)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .help(breadcrumb.url.path(percentEncoded: false))

                        if index > 0 {
                            Text("/")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 2)
                        }
                    }

                    Color.clear
                        .frame(width: 1, height: 1)
                        .id("path-end")
                }
                .font(.system(.callout, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .onAppear {
                scrollToEnd(with: proxy)
            }
            .onChange(of: directory) {
                scrollToEnd(with: proxy)
            }
        }
        .background(.black.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
    }

    private func scrollToEnd(with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo("path-end", anchor: .trailing)
        }
    }
}

private struct PathBreadcrumb: Hashable {
    let id: String
    let title: String
    let url: URL

    static func breadcrumbs(for directory: URL) -> [PathBreadcrumb] {
        let standardizedDirectory = directory.standardizedFileURL
        let components = standardizedDirectory.pathComponents
        guard components.isEmpty == false else {
            return []
        }

        var breadcrumbs: [PathBreadcrumb] = []
        var currentURL = URL(fileURLWithPath: components[0], isDirectory: true).standardizedFileURL
        breadcrumbs.append(PathBreadcrumb(
            id: currentURL.path,
            title: components[0],
            url: currentURL
        ))

        for component in components.dropFirst() {
            currentURL = currentURL.appendingPathComponent(component, isDirectory: true).standardizedFileURL
            breadcrumbs.append(PathBreadcrumb(
                id: currentURL.path,
                title: component,
                url: currentURL
            ))
        }

        return breadcrumbs
    }
}
#endif
