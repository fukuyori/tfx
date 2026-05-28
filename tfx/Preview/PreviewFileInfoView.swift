#if os(macOS)
import Foundation
import Security
import SwiftUI

struct PreviewFileInfo: Equatable, Sendable {
    let name: String
    let kind: String
    let size: String
    let location: String
    let created: String
    let modified: String
    let accessed: String
    let permissions: String
    let signature: String

    static let loading = PreviewFileInfo(
        name: String(localized: "Loading"),
        kind: "-",
        size: "-",
        location: "-",
        created: "-",
        modified: "-",
        accessed: "-",
        permissions: "-",
        signature: "-"
    )
}

struct PreviewFileInfoView: View {
    let url: URL
    @State private var info = PreviewFileInfo.loading
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                FileIcon(url: url)
                Text(info.name)
                    .font(design.fonts.swiftUIFont(for: .header, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            LazyVGrid(
                columns: [
                    GridItem(.fixed(76), alignment: .trailing),
                    GridItem(.flexible(minimum: 80), alignment: .leading)
                ],
                alignment: .leading,
                spacing: 4
            ) {
                infoRow("Kind", info.kind)
                infoRow("Size", info.size)
                infoRow("Where", info.location)
                infoRow("Created", info.created)
                infoRow("Modified", info.modified)
                infoRow("Accessed", info.accessed)
                infoRow("Permission", info.permissions)
                infoRow("Signature", info.signature)
            }
            .font(design.fonts.swiftUIFont(for: .caption))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .foregroundStyle(theme.fileForeground)
        .background(theme.statusLineBackground.opacity(design.opacity.background))
        .task(id: url.standardizedFileURL) {
            info = await PreviewFileInfoLoader.load(for: url)
        }
    }

    private func infoRow(_ label: LocalizedStringResource, _ value: String) -> some View {
        Group {
            Text(label)
                .foregroundStyle(theme.secondaryForeground)
                .lineLimit(1)
            Text(value)
                .foregroundStyle(theme.fileForeground)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

enum PreviewFileInfoLoader {
    nonisolated static func load(for url: URL) async -> PreviewFileInfo {
        await Task.detached(priority: .utility) {
            loadSynchronously(for: url)
        }.value
    }

    nonisolated private static func loadSynchronously(for inputURL: URL) -> PreviewFileInfo {
        let url = inputURL.standardizedFileURL
        if PrivacyProtectedDirectories.isProtectedDirectory(url) {
            return PreviewFileInfo(
                name: FolderDisplayNameCache.shared.displayName(for: url),
                kind: String(localized: "Folder"),
                size: "-",
                location: url.deletingLastPathComponent().path(percentEncoded: false),
                created: "-",
                modified: "-",
                accessed: "-",
                permissions: "-",
                signature: "-"
            )
        }

        let keys: Set<URLResourceKey> = [
            .contentAccessDateKey,
            .contentModificationDateKey,
            .creationDateKey,
            .fileSizeKey,
            .isDirectoryKey,
            .localizedTypeDescriptionKey,
            .totalFileSizeKey
        ]
        let values = try? url.resourceValues(forKeys: keys)
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let isDirectory = values?.isDirectory == true
        let displayName = FolderDisplayNameCache.shared.displayName(for: url)
        let kind = values?.localizedTypeDescription ?? (isDirectory ? String(localized: "Folder") : String(localized: "File"))
        let byteCount = (values?.totalFileSize ?? values?.fileSize).map(Int64.init)
        let size = sizeText(byteCount: byteCount, isDirectory: isDirectory)
        let location = url.deletingLastPathComponent().path(percentEncoded: false)
        let permissions = permissionsText(from: attributes)
        let signature = signatureText(for: url)

        return PreviewFileInfo(
            name: displayName,
            kind: kind,
            size: size,
            location: location,
            created: FileDisplayTextCache.shared.dateText(for: values?.creationDate),
            modified: FileDisplayTextCache.shared.dateText(for: values?.contentModificationDate),
            accessed: FileDisplayTextCache.shared.dateText(for: values?.contentAccessDate),
            permissions: permissions,
            signature: signature
        )
    }

    nonisolated private static func sizeText(byteCount: Int64?, isDirectory: Bool) -> String {
        guard let byteCount, !isDirectory else {
            return isDirectory ? String(localized: "Folder") : "-"
        }

        return FileDisplayTextCache.shared.sizeText(byteCount: byteCount)
    }

    nonisolated private static func permissionsText(from attributes: [FileAttributeKey: Any]?) -> String {
        guard let permissions = (attributes?[.posixPermissions] as? NSNumber)?.intValue else {
            return "-"
        }

        return "\(modeText(permissions))  \(String(format: "%03o", permissions & 0o777))"
    }

    nonisolated private static func modeText(_ permissions: Int) -> String {
        let triplets = [
            (permissions & 0o400, permissions & 0o200, permissions & 0o100),
            (permissions & 0o040, permissions & 0o020, permissions & 0o010),
            (permissions & 0o004, permissions & 0o002, permissions & 0o001)
        ]

        return triplets.map { read, write, execute in
            "\(read == 0 ? "-" : "r")\(write == 0 ? "-" : "w")\(execute == 0 ? "-" : "x")"
        }.joined()
    }

    nonisolated private static func signatureText(for url: URL) -> String {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCode)
        guard createStatus == errSecSuccess, let staticCode else {
            return "-"
        }

        var error: Unmanaged<CFError>?
        let checkStatus = SecStaticCodeCheckValidityWithErrors(staticCode, SecCSFlags(), nil, &error)
        error?.release()

        switch checkStatus {
        case errSecSuccess:
            return String(localized: "Valid")
        case errSecCSUnsigned:
            return String(localized: "Unsigned")
        default:
            return String(localized: "Invalid")
        }
    }
}
#endif
