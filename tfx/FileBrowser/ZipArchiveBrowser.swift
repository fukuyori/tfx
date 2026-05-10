#if os(macOS)
import Foundation

struct ZipArchiveLocation: Hashable {
    let archiveURL: URL
    let innerPath: String

    var isRoot: Bool {
        innerPath.isEmpty
    }
}

struct ZipArchiveEntry {
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modified: Date?
}

enum ZipArchiveBrowserError: LocalizedError {
    case invalidArchive(URL)
    case unsupportedWrite
    case commandFailed(String)
    case invalidEntry(String)

    var errorDescription: String? {
        switch self {
        case let .invalidArchive(url):
            return String(localized: "Cannot read zip archive: \(url.path)")
        case .unsupportedWrite:
            return String(localized: "Writing into zip archives is not supported.")
        case let .commandFailed(message):
            return message.isEmpty ? String(localized: "Zip command failed.") : message
        case let .invalidEntry(path):
            return String(localized: "Cannot copy unsafe zip entry: \(path)")
        }
    }
}

enum ZipArchiveBrowser {
    nonisolated static func location(for url: URL) -> ZipArchiveLocation? {
        let standardizedURL = url.standardizedFileURL
        let pathComponents = standardizedURL.pathComponents
        guard !pathComponents.isEmpty else { return nil }

        for index in pathComponents.indices {
            let component = pathComponents[index]
            guard component.lowercased().hasSuffix(".zip") else { continue }

            let archivePath = NSString.path(withComponents: Array(pathComponents[...index]))
            let archiveURL = URL(fileURLWithPath: archivePath).standardizedFileURL
            guard isZipArchive(archiveURL) else { continue }

            let innerComponents = pathComponents.dropFirst(index + 1)
            let innerPath = innerComponents.joined(separator: "/")
            return ZipArchiveLocation(archiveURL: archiveURL, innerPath: innerPath)
        }

        return nil
    }

    nonisolated static func isZipArchive(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "zip" else { return false }

        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && !isDirectory.boolValue
    }

    nonisolated static func virtualURL(archiveURL: URL, innerPath: String) -> URL {
        let trimmedInnerPath = normalizedInnerPath(innerPath)
        guard !trimmedInnerPath.isEmpty else {
            return archiveURL.standardizedFileURL
        }
        return archiveURL.standardizedFileURL.appendingPathComponent(trimmedInnerPath)
    }

    nonisolated static func entries(in directory: URL) throws -> [ZipArchiveEntry] {
        guard let location = location(for: directory) else { return [] }

        let allPaths = try listEntryPaths(in: location.archiveURL)
        let prefix = location.innerPath.isEmpty ? "" : location.innerPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/"
        var entriesByName: [String: ZipArchiveEntry] = [:]

        for rawPath in allPaths {
            let path = normalizedInnerPath(rawPath)
            guard !path.isEmpty, path.hasPrefix(prefix), path != location.innerPath else { continue }

            let remaining = String(path.dropFirst(prefix.count))
            guard !remaining.isEmpty else { continue }

            let components = remaining.split(separator: "/", omittingEmptySubsequences: true)
            guard let firstComponent = components.first else { continue }

            let childPath = prefix + String(firstComponent)
            let isDirectory = components.count > 1 || rawPath.hasSuffix("/")
            let key = childPath
            let previous = entriesByName[key]
            entriesByName[key] = ZipArchiveEntry(
                path: childPath,
                isDirectory: previous?.isDirectory == true || isDirectory,
                size: isDirectory ? 0 : 0,
                modified: nil
            )
        }

        return entriesByName.values.sorted {
            if $0.isDirectory != $1.isDirectory {
                return $0.isDirectory
            }
            return $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }

    nonisolated static func materializedURL(for virtualURL: URL) throws -> URL {
        guard let location = location(for: virtualURL), !location.innerPath.isEmpty else {
            return virtualURL
        }

        let destination = temporaryRoot(for: location.archiveURL)
            .appendingPathComponent(location.innerPath)
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        let data = try entryData(archiveURL: location.archiveURL, entryPath: location.innerPath)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    nonisolated static func copyVirtualItem(_ virtualURL: URL, into targetDirectory: URL) throws -> [URL] {
        guard let archiveLocation = location(for: virtualURL), !archiveLocation.innerPath.isEmpty else {
            return []
        }
        if location(for: targetDirectory) != nil {
            throw ZipArchiveBrowserError.unsupportedWrite
        }

        let selectedName = URL(fileURLWithPath: archiveLocation.innerPath).lastPathComponent
        guard !selectedName.isEmpty, !selectedName.contains("/") else {
            throw ZipArchiveBrowserError.invalidEntry(archiveLocation.innerPath)
        }

        let entries = try listEntryPaths(in: archiveLocation.archiveURL)
        let selectedPrefix = archiveLocation.innerPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/"
        let selectedIsDirectory = entries.contains { $0.hasPrefix(selectedPrefix) }
        let pathsToCopy: [String]

        if selectedIsDirectory {
            pathsToCopy = entries
                .map { normalizedInnerPath($0) }
                .filter { $0.hasPrefix(selectedPrefix) && !$0.hasSuffix("/") }
        } else {
            pathsToCopy = [archiveLocation.innerPath]
        }

        let rootDestination = selectedIsDirectory
            ? uniqueDestination(for: selectedName, in: targetDirectory)
            : nil
        var copiedURLs: [URL] = []
        for entryPath in pathsToCopy {
            let destination: URL
            if selectedIsDirectory {
                destination = rootDestination!
                    .appendingPathComponent(String(entryPath.dropFirst(selectedPrefix.count)))
            } else {
                destination = targetDirectory.appendingPathComponent(selectedName)
            }

            try validateDestination(destination, inside: targetDirectory, entryPath: entryPath)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

            let finalDestination = selectedIsDirectory
                ? destination
                : uniqueDestination(for: destination.lastPathComponent, in: destination.deletingLastPathComponent())
            let data = try entryData(archiveURL: archiveLocation.archiveURL, entryPath: entryPath)
            try data.write(to: finalDestination, options: .atomic)
            copiedURLs.append(finalDestination)
        }

        if selectedIsDirectory, copiedURLs.isEmpty {
            let destination = rootDestination ?? uniqueDestination(for: selectedName, in: targetDirectory)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            copiedURLs.append(destination)
        }

        return copiedURLs
    }

    nonisolated static func canCopyFromArchive(_ url: URL) -> Bool {
        location(for: url)?.innerPath.isEmpty == false
    }

    nonisolated private static func listEntryPaths(in archiveURL: URL) throws -> [String] {
        let output = try runUnzip(arguments: ["-Z", "-1", archiveURL.path])
        return output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty && !$0.hasPrefix("__MACOSX/") }
    }

    nonisolated private static func entryData(archiveURL: URL, entryPath: String) throws -> Data {
        try runUnzipData(arguments: ["-p", archiveURL.path, entryPath])
    }

    nonisolated private static func runUnzip(arguments: [String]) throws -> String {
        let data = try runUnzipData(arguments: arguments)
        return String(data: data, encoding: .utf8) ?? ""
    }

    nonisolated private static func runUnzipData(arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw ZipArchiveBrowserError.invalidArchive(URL(fileURLWithPath: arguments.dropFirst().first ?? ""))
        }

        process.waitUntilExit()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? ""
            throw ZipArchiveBrowserError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return outputData
    }

    nonisolated private static func temporaryRoot(for archiveURL: URL) -> URL {
        let archiveKey = archiveURL.path
            .data(using: .utf8)?
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            ?? UUID().uuidString

        return FileManager.default.temporaryDirectory
            .appendingPathComponent("tfx-zip-preview", isDirectory: true)
            .appendingPathComponent(archiveKey, isDirectory: true)
    }

    nonisolated private static func normalizedInnerPath(_ path: String) -> String {
        path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
            .joined(separator: "/")
    }

    nonisolated private static func validateDestination(_ destination: URL, inside targetDirectory: URL, entryPath: String) throws {
        let targetPath = targetDirectory.standardizedFileURL.path
        let destinationPath = destination.standardizedFileURL.path
        guard destinationPath == targetPath || destinationPath.hasPrefix(targetPath + "/") else {
            throw ZipArchiveBrowserError.invalidEntry(entryPath)
        }
    }

    nonisolated private static func uniqueDestination(for fileName: String, in directory: URL) -> URL {
        let baseURL = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: baseURL.path) else {
            return baseURL
        }

        let name = (fileName as NSString).deletingPathExtension
        let pathExtension = (fileName as NSString).pathExtension

        var index = 2
        while true {
            let candidateName: String
            if pathExtension.isEmpty {
                candidateName = "\(name) \(index)"
            } else {
                candidateName = "\(name) \(index).\(pathExtension)"
            }

            let candidateURL = directory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            index += 1
        }
    }
}
#endif
