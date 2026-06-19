#if os(macOS)
import AppKit
import Foundation

enum FileOperationPrompt {
    static func conflictResolution(fileName: String) -> ConflictResolution {
        conflictResolutionChoice(fileName: fileName).resolution
    }

    static func conflictResolutionChoice(fileName: String) -> FileConflictResolutionChoice {
        let alert = NSAlert()
        alert.messageText = String(localized: "Item Already Exists")
        alert.informativeText = String(localized: "\"\(fileName)\" already exists in the destination.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Replace"))
        alert.addButton(withTitle: String(localized: "Keep Both"))
        alert.addButton(withTitle: String(localized: "Skip"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        let applyToAll = NSButton(checkboxWithTitle: String(localized: "Apply to all conflicts"), target: nil, action: nil)
        applyToAll.state = .off
        alert.accessoryView = applyToAll

        let resolution: ConflictResolution
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            resolution = .replace
        case .alertSecondButtonReturn:
            resolution = .keepBoth
        case .alertThirdButtonReturn:
            resolution = .skip
        default:
            resolution = .cancel
        }

        return FileConflictResolutionChoice(
            resolution: resolution,
            appliesToAll: applyToAll.state == .on && resolution != .cancel
        )
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
        // Make the text field the first responder once the alert
        // panel is up, and pre-select the entire default value
        // (matching Finder's "New Folder" sheet) so the user can
        // start typing a replacement name immediately. `selectText`
        // installs the field editor and selects all text; we dispatch
        // to the next runloop tick because `runModal` spins its own
        // nested loop and the async block fires after the window is
        // on screen.
        alert.window.initialFirstResponder = textField
        DispatchQueue.main.async {
            textField.selectText(nil)
        }

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return textField.stringValue
    }
}

#endif
