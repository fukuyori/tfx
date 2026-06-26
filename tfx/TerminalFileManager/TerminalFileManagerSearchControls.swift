#if os(macOS)
import SwiftUI

extension TerminalFileManagerView {
    var pathAndSearchControls: some View {
        Group {
            // Path breadcrumb removed from the toolbar — each file
            // pane shows its own path in `FilePaneTitleBar`. The
            // empty space pushes the search field to the right.
            Spacer(minLength: 0)

            TextField("Search", text: Binding(
                get: { model.searchText },
                set: { model.searchText = $0 }
            ))
                .textFieldStyle(.roundedBorder)
                .font(design.fonts.swiftUIFont(for: .fileList))
                .frame(width: 180)
                .focused($isSearchFocused)
                .onTapGesture {
                    isSearchFocused = true
                }
                .onSubmit {
                    if model.trimmedSearchQuery.isEmpty {
                        cancelSearch()
                    } else {
                        model.submitSubfolderSearch()
                    }
                }

            if model.isSubfolderSearchRunning {
                Button {
                    cancelSearch()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
                .quickHelp("Stop search", text: $hoverHelpText)
            }

            Button {
                isSearchFocused = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(shortcutStore.info(.focusSearch))
            .quickHelp("Focus search", shortcut: shortcutStore.info(.focusSearch), text: $hoverHelpText)
        }
    }

    private func cancelSearch() {
        model.stopSubfolderSearch()
        isSearchFocused = false
    }

    var sortAndVisibilityControls: some View {
        Group {
            Toggle(isOn: Binding(
                get: { model.showHiddenFiles },
                set: { model.showHiddenFiles = $0 }
            )) {
                Image(systemName: "eye")
            }
            .toggleStyle(.button)
            .keyboardShortcut(shortcutStore.info(.toggleHidden))
            .quickHelp("Show hidden files", shortcut: shortcutStore.info(.toggleHidden), text: $hoverHelpText)
        }
    }
}

private struct PathBreadcrumbBar: View {
    let directory: URL
    let navigate: (URL) -> Void
    @Environment(\.design) private var design

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
                .font(design.fonts.swiftUIFont(for: .fileList))
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
        .background(.black.opacity(design.opacity.subtleBackground), in: RoundedRectangle(cornerRadius: 6))
    }

    private func scrollToEnd(with proxy: ScrollViewProxy) {
        // `ScrollViewProxy.scrollTo` traps with "may not be
        // accessed during view updates" if it lands inside
        // SwiftUI's current update transaction; `Task.yield()`
        // doesn't guarantee that. `DispatchQueue.main.async`
        // always reaches the next runloop tick, after the
        // current update completes.
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
