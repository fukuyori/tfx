#if os(macOS)
import Foundation
import UniformTypeIdentifiers

enum FileBrowserDropProviderLoader {
    static func loadFileURLs(
        from providers: [NSItemProvider],
        onError: @escaping (Error) -> Void,
        onURL: @escaping (URL) -> Void
    ) -> Bool {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                DispatchQueue.main.async {
                    if let error {
                        onError(error)
                        return
                    }

                    if let sourceURL = FileBrowserDropItemDecoder.url(from: item) {
                        onURL(sourceURL)
                    }
                }
            }
        }

        return true
    }
}

enum FileBrowserDropItemDecoder {
    static func url(from item: NSSecureCoding?) -> URL? {
        if let droppedURL = item as? URL {
            return droppedURL
        } else if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        } else if let string = item as? String {
            return URL(string: string)
        } else {
            return nil
        }
    }
}

#endif
