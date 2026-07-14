#if os(macOS)
import Foundation

struct FileListColumnConfiguration {
    private(set) var orderedColumns: [FileListColumn]
    private(set) var visibleColumns: Set<FileListColumn>

    static let defaultColumns: [FileListColumn] = [.gitStatus, .icon, .name, .size, .kind, .tags, .modified, .mode, .created, .permissions]
    static let defaultRawValue = defaultColumns.map { "\($0.rawValue):1" }.joined(separator: ",")

    init(rawValue: String) {
        var orderedColumns: [FileListColumn] = []
        var visibleColumns = Set<FileListColumn>()

        for component in rawValue.split(separator: ",") {
            let parts = component.split(separator: ":", maxSplits: 1).map(String.init)
            guard let rawColumn = parts.first, let column = FileListColumn(rawValue: rawColumn) else {
                continue
            }

            if !orderedColumns.contains(column) {
                orderedColumns.append(column)
            }

            let isVisible = parts.count < 2 || parts[1] != "0"
            if isVisible || column == .name {
                visibleColumns.insert(column)
            }
        }

        for column in Self.defaultColumns where !orderedColumns.contains(column) {
            orderedColumns.append(column)
            visibleColumns.insert(column)
        }

        visibleColumns.insert(.name)
        self.orderedColumns = orderedColumns
        self.visibleColumns = visibleColumns
    }

    var rawValue: String {
        orderedColumns
            .map { column in
                "\(column.rawValue):\(visibleColumns.contains(column) ? "1" : "0")"
            }
            .joined(separator: ",")
    }

    var visibleOrderedColumns: [FileListColumn] {
        orderedColumns.filter { visibleColumns.contains($0) }
    }

    func isVisible(_ column: FileListColumn) -> Bool {
        visibleColumns.contains(column)
    }

    mutating func setVisible(_ isVisible: Bool, for column: FileListColumn) {
        guard column.canHide else {
            visibleColumns.insert(column)
            return
        }

        if isVisible {
            visibleColumns.insert(column)
        } else {
            visibleColumns.remove(column)
        }
    }

    /// Move `column` to position `targetIndex`, where
    /// `targetIndex` is the insertion index in the BEFORE-removal
    /// list (matches SwiftUI / drag-and-drop semantics: drop at
    /// the index immediately above the highlighted row). If
    /// `column` is currently at or before `targetIndex`, the
    /// final position becomes `targetIndex - 1` after the remove
    /// step, which is the standard list-reorder behavior.
    mutating func move(_ column: FileListColumn, to targetIndex: Int) {
        guard let currentIndex = orderedColumns.firstIndex(of: column) else { return }
        var insertionIndex = max(0, min(targetIndex, orderedColumns.count))
        if currentIndex == insertionIndex || currentIndex + 1 == insertionIndex { return }
        orderedColumns.remove(at: currentIndex)
        if currentIndex < insertionIndex { insertionIndex -= 1 }
        orderedColumns.insert(column, at: insertionIndex)
    }

    mutating func reset() {
        orderedColumns = Self.defaultColumns
        visibleColumns = Set(Self.defaultColumns)
    }
}

#endif
