#if os(macOS)
import Foundation

struct FileListColumnConfiguration {
    private(set) var orderedColumns: [FileListColumn]
    private(set) var visibleColumns: Set<FileListColumn>

    static let defaultColumns: [FileListColumn] = [.mode, .icon, .name, .size, .kind, .tags, .gitStatus, .modified, .created, .permissions]
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

    mutating func move(_ column: FileListColumn, direction: Int) {
        guard let currentIndex = orderedColumns.firstIndex(of: column) else {
            return
        }

        let nextIndex = min(max(currentIndex + direction, 0), orderedColumns.count - 1)
        guard nextIndex != currentIndex else { return }

        orderedColumns.remove(at: currentIndex)
        orderedColumns.insert(column, at: nextIndex)
    }

    mutating func reset() {
        orderedColumns = Self.defaultColumns
        visibleColumns = Set(Self.defaultColumns)
    }
}

#endif
