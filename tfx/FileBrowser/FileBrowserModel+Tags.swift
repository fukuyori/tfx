#if os(macOS)
import AppKit
import Foundation

extension FileBrowserModel {
    /// Ask for a new custom tag name and add it to every selected item.
    /// Existing tags are left untouched; duplicate names are ignored per item.
    func addCustomTagFromPrompt() {
        let targets = selectedItems
        guard !targets.isEmpty else { return }
        guard !targets.contains(where: { ZipArchiveBrowser.canCopyFromArchive($0.url) }) else {
            show(ZipArchiveBrowserError.unsupportedWrite)
            return
        }

        guard let rawName = FileOperationPrompt.text(
            title: String(localized: "Add Custom Tag"),
            message: String(localized: "Enter a tag name to add to the selected items."),
            defaultValue: ""
        ) else {
            return
        }

        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        addCustomTag(FileTag(name: name), to: targets)
    }

    /// Toggle one of the seven standard system tags on the current
    /// selection.
    ///
    /// Mirrors Finder's behavior:
    /// - If **all** selected items already carry the tag, it is removed
    ///   from each.
    /// - Otherwise the tag is added to every selected item that does not
    ///   already have it (other-colored tags are left untouched).
    func toggleSystemTag(colorID: Int) {
        let targets = selectedItems
        guard !targets.isEmpty, colorID > 0 else { return }
        guard !targets.contains(where: { ZipArchiveBrowser.canCopyFromArchive($0.url) }) else {
            show(ZipArchiveBrowserError.unsupportedWrite)
            return
        }

        let allHaveIt = targets.allSatisfy { item in
            item.tags.contains(where: { $0.colorID == colorID })
        }
        let shouldRemove = allHaveIt

        var affectedDirectories: Set<URL> = []
        for target in targets {
            do {
                try applyTagToggle(url: target.url, colorID: colorID, remove: shouldRemove)
                affectedDirectories.insert(target.url.deletingLastPathComponent().standardizedFileURL)
            } catch {
                show(error)
            }
        }

        if !affectedDirectories.isEmpty {
            notifyDirectoriesChanged(Array(affectedDirectories))
            // Re-read the current pane so the tag column and any
            // colored folder icons reflect the new state immediately.
            reload()
        }
    }

    /// Custom (non-standard / renamed / uncolored) tags collected from the
    /// items currently loaded in this pane. Used by the Tags submenu to
    /// list the user's own tags below the seven system colors so they can
    /// be toggled on other files without a Finder roundtrip.
    ///
    /// This is intentionally limited to the current directory — enumerating
    /// the user's full tag library requires Spotlight or Finder's private
    /// preferences plist, both of which would be heavier than the "show
    /// what's already in front of me" goal.
    var customTagsInCurrentDirectory: [FileTag] {
        var seen: Set<String> = []
        var result: [FileTag] = []
        for item in items {
            for tag in item.tags where !tag.isStandardSystemTag {
                if seen.insert(tag.name).inserted {
                    result.append(tag)
                }
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Toggle a custom tag (by name) on the current selection. Mirrors the
    /// system-tag toggle behavior: all-have → remove from each; otherwise
    /// add to those missing it.
    func toggleCustomTag(_ tag: FileTag) {
        let targets = selectedItems
        guard !targets.isEmpty else { return }
        guard !targets.contains(where: { ZipArchiveBrowser.canCopyFromArchive($0.url) }) else {
            show(ZipArchiveBrowserError.unsupportedWrite)
            return
        }

        let allHaveIt = targets.allSatisfy { item in
            item.tags.contains(where: { $0.name == tag.name })
        }
        let shouldRemove = allHaveIt

        var affectedDirectories: Set<URL> = []
        for target in targets {
            do {
                try applyCustomTagToggle(url: target.url, tag: tag, remove: shouldRemove)
                affectedDirectories.insert(target.url.deletingLastPathComponent().standardizedFileURL)
            } catch {
                show(error)
            }
        }

        if !affectedDirectories.isEmpty {
            notifyDirectoriesChanged(Array(affectedDirectories))
            reload()
        }
    }

    private func addCustomTag(_ tag: FileTag, to targets: [FileItem]) {
        var affectedDirectories: Set<URL> = []
        for target in targets {
            do {
                try addCustomTagIfNeeded(url: target.url, tag: tag)
                affectedDirectories.insert(target.url.deletingLastPathComponent().standardizedFileURL)
            } catch {
                show(error)
            }
        }

        if !affectedDirectories.isEmpty {
            notifyDirectoriesChanged(Array(affectedDirectories))
            reload()
        }
    }

    private func addCustomTagIfNeeded(url: URL, tag: FileTag) throws {
        let current = (try url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
        let alreadyTagged = current.contains { rawTag in
            FileTag(rawTagName: rawTag).name == tag.name
        }
        guard !alreadyTagged else { return }

        var values = URLResourceValues()
        values.tagNames = current + [tag.rawTagString]
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    /// Write the tag list for `url` with one custom tag either added or
    /// removed. Matches the raw `tagNames` string (`name` or
    /// `name\ncolorID`) so the toggle is idempotent across reads.
    private func applyCustomTagToggle(url: URL, tag: FileTag, remove: Bool) throws {
        let current = (try url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []

        // Drop any existing entry that resolves to the same tag name so the
        // add path can write a canonical form and the remove path strips
        // duplicates introduced elsewhere.
        let withoutTarget = current.filter { rawTag in
            FileTag(rawTagName: rawTag).name != tag.name
        }

        var nextTags = withoutTarget
        if !remove {
            nextTags.append(tag.rawTagString)
        }

        var mutableURL = url
        var values = URLResourceValues()
        values.tagNames = nextTags
        try mutableURL.setResourceValues(values)
    }

    /// Write the tag list for `url` with one system color either added
    /// or removed. Existing tags of other colors and custom-named tags
    /// are preserved.
    private func applyTagToggle(url: URL, colorID: Int, remove: Bool) throws {
        let current = (try url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []

        // Drop any existing entry for the targeted color so we can write
        // a canonical `<name>\n<colorID>` form back when adding, and so
        // remove-mode strips renamed variants of the same color too.
        let withoutTargetColor = current.filter { rawTag in
            FileTag(rawTagName: rawTag).colorID != colorID
        }

        var nextTags = withoutTargetColor
        if !remove {
            let name = FileTag.systemTagName(forColorID: colorID)
            nextTags.append("\(name)\n\(colorID)")
        }

        var mutableURL = url
        var values = URLResourceValues()
        values.tagNames = nextTags
        try mutableURL.setResourceValues(values)
    }
}

#endif
