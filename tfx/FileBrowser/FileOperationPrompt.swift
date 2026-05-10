#if os(macOS)
import AppKit
import Foundation

enum FileOperationPrompt {
    static func conflictResolution(fileName: String) -> ConflictResolution {
        let alert = NSAlert()
        alert.messageText = String(localized: "Item Already Exists")
        alert.informativeText = String(localized: "\"\(fileName)\" already exists in the destination.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Replace"))
        alert.addButton(withTitle: String(localized: "Keep Both"))
        alert.addButton(withTitle: String(localized: "Skip"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .replace
        case .alertSecondButtonReturn:
            return .keepBoth
        case .alertThirdButtonReturn:
            return .skip
        default:
            return .cancel
        }
    }

    static func text(title: String, message: String, defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        textField.stringValue = defaultValue
        alert.accessoryView = textField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return textField.stringValue
    }
}

#endif
