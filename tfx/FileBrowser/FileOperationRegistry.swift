#if os(macOS)
import AppKit
import Foundation

/// Process-wide registry of in-flight file operations. The
/// app-delegate consults it on terminate so a quit during a
/// long copy / move surfaces a confirmation alert instead of
/// silently killing the operation and leaving partial files
/// behind. Each `FileBrowserModel` registers / un-registers its
/// `activeOperation` here as it starts / completes.
@MainActor
final class FileOperationRegistry {
    static let shared = FileOperationRegistry()

    private var operations: [ObjectIdentifier: FileOperationProgressViewModel] = [:]

    var hasActiveOperation: Bool { !operations.isEmpty }

    func register(_ operation: FileOperationProgressViewModel) {
        operations[ObjectIdentifier(operation)] = operation
    }

    func unregister(_ operation: FileOperationProgressViewModel) {
        operations.removeValue(forKey: ObjectIdentifier(operation))
    }

    /// Cancel every running operation. Returns immediately; the
    /// underlying copy threads stop at their next chunk
    /// boundary and remove any partial destination file before
    /// the progress view model deregisters itself.
    func cancelAll() {
        for op in operations.values {
            op.cancel()
        }
    }

    /// Quit-blocker invoked from `applicationShouldTerminate`.
    /// Shows a confirmation alert when a file operation is in
    /// flight and lets the user either quit immediately —
    /// accepting that the destination may end up with partial
    /// files — or stay in the app to wait it out.
    ///
    /// The "Quit Anyway" path requests cancellation as a courtesy
    /// (so the background thread stops issuing further writes
    /// once it notices the flag) but does NOT wait for the
    /// cleanup loop to finish. Waiting would risk wedging the
    /// quit if the in-progress chunk is stuck on a coordinator
    /// block or a slow filesystem syscall.
    func handleApplicationTerminate(_ application: NSApplication) -> NSApplication.TerminateReply {
        guard hasActiveOperation else { return .terminateNow }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "A file operation is in progress")
        alert.informativeText = String(localized: "Quitting now will leave partially copied files behind at the destination.")
        alert.addButton(withTitle: String(localized: "Quit Anyway"))
        alert.addButton(withTitle: String(localized: "Keep Running"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            cancelAll()
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
}

#endif
