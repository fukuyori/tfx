#if os(macOS)
import Foundation

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

    nonisolated var id: URL { url }
    nonisolated var name: String { nameValue }
    nonisolated var isApplicationBundle: Bool {
        isDirectory && url.pathExtension.caseInsensitiveCompare("app") == .orderedSame
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

    nonisolated init(url: URL) {
        self.url = url

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey, .isAliasFileKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey])
        isDirectory = Self.isDirectoryOrDirectorySymlink(url, values: values)
        isHidden = values?.isHidden == true || url.lastPathComponent.hasPrefix(".")
        size = Int64(values?.fileSize ?? 0)
        modified = values?.contentModificationDate
        created = values?.creationDate
        let localizedName = FolderDisplayNameCache.shared.displayName(for: url)
        nameValue = localizedName.isEmpty ? (url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent) : localizedName
        searchNameValue = nameValue.localizedLowercase
        let extensionName = url.pathExtension.lowercased()
        iconCacheKeyValue = isDirectory ? "directory" : (extensionName.isEmpty ? "file" : "file.\(extensionName)")
        modeValue = isDirectory ? "drwx" : "-rw-"
        kindSortKeyValue = isDirectory ? "Folder" : extensionName
        sizeTextValue = isDirectory ? "-" : FileDisplayTextCache.shared.sizeText(byteCount: size)
        modifiedTextValue = FileDisplayTextCache.shared.dateText(for: modified)
        createdTextValue = FileDisplayTextCache.shared.dateText(for: created)
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
    }
}
#endif
