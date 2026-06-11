#if os(macOS)
import Foundation

/// One row in the file list.
///
/// Equality and hashing are explicit (rather than synthesized) so SwiftUI's
/// `ForEach(model.items)` diff only inspects fields that affect the visible
/// row. The synthesized comparison would walk all 13+ String properties on
/// every row on every diff pass; URL + size + modified + isHidden +
/// isDirectory is enough to catch external mutations while keeping the
/// per-row comparison cheap.
struct FileItem: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let isHidden: Bool
    let size: Int64
    let modified: Date?
    let created: Date?
    let nameValue: String
    let searchNameValue: String
    let iconCacheKeyValue: String
    let modeValue: String
    let kindSortKeyValue: String
    let sizeTextValue: String
    let modifiedTextValue: String
    let createdTextValue: String
    let tagsValue: [FileTag]

    nonisolated var id: URL { url }
    nonisolated var name: String { nameValue }
    nonisolated var isApplicationBundle: Bool {
        isDirectory && url.pathExtension.caseInsensitiveCompare("app") == .orderedSame
    }
    /// True when this row is a sensible "open-with-files" drop
    /// target. Restricted to `.app` bundles only — even a
    /// non-directory file with a +x mode bit is NOT treated as
    /// an execute-on-drop target, because doing so would
    /// surprise users who expect a plain file drop to land in
    /// the current folder. Plain executables fall through to
    /// the pane's current-directory drop just like any other
    /// non-folder file.
    var isExecutableTarget: Bool {
        isApplicationBundle
    }
    nonisolated var searchName: String { searchNameValue }
    nonisolated var iconCacheKey: String { iconCacheKeyValue }
    nonisolated var mode: String { modeValue }
    nonisolated var sizeText: String { sizeTextValue }
    nonisolated var kindSortKey: String { kindSortKeyValue }
    var kindText: String {
        let kind = FileKindCache.shared.kind(for: url, isDirectory: isDirectory)
        return kind.isEmpty ? "-" : kind
    }
    nonisolated var modifiedText: String { modifiedTextValue }
    nonisolated var createdText: String { createdTextValue }
    nonisolated var tags: [FileTag] { tagsValue }
    var permissionsText: String {
        guard let permissions = FilePermissionCache.shared.permissions(for: url) else { return "-" }
        return String(format: "%03o", permissions)
    }

    nonisolated private static func isDirectoryOrDirectorySymlink(_ url: URL, values: URLResourceValues?) -> Bool {
        // URLResourceValues.isDirectory follows POSIX symlinks, so plain
        // symlink-to-directory entries are already reported as directories.
        if values?.isDirectory == true {
            return true
        }

        // Finder aliases ("bookmark"-style aliases) are *not* POSIX symlinks
        // and need an explicit resolve. The `.isAliasFileKey` value is
        // pre-fetched in `FileItem.init`, so this branch only runs for actual
        // aliases and avoids the cost of re-reading resource values.
        if values?.isAliasFile == true,
           let aliasTarget = try? URL(resolvingAliasFileAt: url, options: []) {
            var targetIsDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: aliasTarget.path, isDirectory: &targetIsDirectory)
                && targetIsDirectory.boolValue
        }

        // When `values` is nil the upstream resource-values fetch failed
        // (typically a permission error). Fall back to a single stat as a
        // defensive default so we still classify the entry correctly when we
        // can read it via FileManager.
        if values == nil {
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }

        return false
    }

    nonisolated static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
            && lhs.size == rhs.size
            && lhs.modified == rhs.modified
            && lhs.isHidden == rhs.isHidden
            && lhs.isDirectory == rhs.isDirectory
            && lhs.tagsValue == rhs.tagsValue
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    nonisolated init(url: URL) {
        self.url = url

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey, .isAliasFileKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .tagNamesKey])
        isDirectory = Self.isDirectoryOrDirectorySymlink(url, values: values)
        isHidden = values?.isHidden == true || url.lastPathComponent.hasPrefix(".")
        size = Int64(values?.fileSize ?? 0)
        modified = values?.contentModificationDate
        created = values?.creationDate
        // `FileManager.displayName(atPath:)` is only meaningfully different
        // from `lastPathComponent` for system / localized directories
        // (e.g. Documents → 「書類」). For plain files it returns the same
        // string after a relatively expensive locale-aware lookup — skip it
        // entirely there. Especially impactful on network volumes where
        // each `displayName` call costs a round trip.
        let fallbackName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        if isDirectory {
            let localizedName = FolderDisplayNameCache.shared.displayName(for: url)
            nameValue = localizedName.isEmpty ? fallbackName : localizedName
        } else {
            nameValue = fallbackName
        }
        searchNameValue = nameValue.localizedLowercase
        let extensionName = url.pathExtension.lowercased()
        iconCacheKeyValue = isDirectory ? "directory" : (extensionName.isEmpty ? "file" : "file.\(extensionName)")
        modeValue = isDirectory ? "drwx" : "-rw-"
        kindSortKeyValue = isDirectory ? "Folder" : extensionName
        sizeTextValue = isDirectory ? "-" : FileDisplayTextCache.shared.sizeText(byteCount: size)
        modifiedTextValue = FileDisplayTextCache.shared.dateText(for: modified)
        createdTextValue = FileDisplayTextCache.shared.dateText(for: created)
        tagsValue = values?.tagNames?.map(FileTag.init(rawTagName:)) ?? []
    }

    nonisolated init(zipEntry: ZipArchiveEntry, archiveURL: URL) {
        let virtualURL = ZipArchiveBrowser.virtualURL(archiveURL: archiveURL, innerPath: zipEntry.path)
        self.url = virtualURL

        isDirectory = zipEntry.isDirectory
        isHidden = virtualURL.lastPathComponent.hasPrefix(".")
        size = zipEntry.size
        modified = zipEntry.modified
        created = nil
        nameValue = virtualURL.lastPathComponent
        searchNameValue = nameValue.localizedLowercase
        let extensionName = virtualURL.pathExtension.lowercased()
        iconCacheKeyValue = isDirectory ? "directory" : (extensionName.isEmpty ? "file" : "file.\(extensionName)")
        modeValue = isDirectory ? "drwx" : "-rw-"
        kindSortKeyValue = isDirectory ? "Folder" : extensionName
        sizeTextValue = isDirectory ? "-" : FileDisplayTextCache.shared.sizeText(byteCount: size)
        modifiedTextValue = FileDisplayTextCache.shared.dateText(for: modified)
        createdTextValue = "-"
        // Zip-archive entries do not carry macOS Finder tags.
        tagsValue = []
    }
}
#endif
