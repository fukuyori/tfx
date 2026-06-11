#if os(macOS)
import Combine
import Foundation

/// Observable wrapper around Foundation's `Progress` so SwiftUI
/// views can bind to its key properties directly. `Progress` is
/// the OS-standard reporter — it integrates with the Dock badge,
/// shares cancellation through the responder chain, and emits a
/// localized "X of Y, about N seconds remaining" string — but
/// SwiftUI cannot observe it natively because it predates
/// `ObservableObject`. We mirror its observable properties into
/// `@Published` ones here via KVO.
final class FileOperationProgressViewModel: ObservableObject {
    enum Kind {
        case copying
        case moving

        /// Title used in the in-pane progress card.
        var title: String {
            switch self {
            case .copying: return String(localized: "Copying…")
            case .moving:  return String(localized: "Moving…")
            }
        }
    }

    let kind: Kind
    let progress: Progress

    /// Whatever Foundation's localizer hands back —
    /// e.g. "Copying 12 of 38 items, about 6 seconds remaining".
    @Published private(set) var localizedDescription: String = ""
    @Published private(set) var fractionCompleted: Double = 0
    /// Name of the file currently being copied, taken from
    /// `Progress.fileURL`. We surface only the last path
    /// component to keep the status line short.
    @Published private(set) var currentFileName: String = ""

    private var observers: [NSKeyValueObservation] = []

    init(kind: Kind, progress: Progress) {
        self.kind = kind
        self.progress = progress
        localizedDescription = progress.localizedDescription ?? ""
        fractionCompleted = progress.fractionCompleted
        currentFileName = progress.fileURL?.lastPathComponent ?? ""

        observers.append(progress.observe(\.localizedDescription) { [weak self] p, _ in
            let value = p.localizedDescription ?? ""
            DispatchQueue.main.async { self?.localizedDescription = value }
        })
        observers.append(progress.observe(\.fractionCompleted) { [weak self] p, _ in
            let value = p.fractionCompleted
            DispatchQueue.main.async { self?.fractionCompleted = value }
        })
        observers.append(progress.observe(\.fileURL) { [weak self] p, _ in
            let value = p.fileURL?.lastPathComponent ?? ""
            DispatchQueue.main.async { self?.currentFileName = value }
        })
    }

    deinit {
        observers.forEach { $0.invalidate() }
    }

    func cancel() {
        progress.cancel()
    }
}

#endif
