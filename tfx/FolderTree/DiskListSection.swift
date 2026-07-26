#if os(macOS)
import AppKit
import Combine
import SwiftUI

/// One mounted volume as shown in the sidebar's DISKS section.
///
/// The icon is captured once during the (background) volume scan:
/// `NSWorkspace.icon(forFile:)` can hit the disk — or, for a wedged
/// network volume, hang — so it must never run inside a row's `body`.
struct VolumeInfo: Identifiable, Equatable {
    let url: URL
    let name: String
    let totalCapacity: Int64
    let availableCapacity: Int64
    let icon: NSImage

    var id: URL { url }

    static func == (lhs: VolumeInfo, rhs: VolumeInfo) -> Bool {
        lhs.url == rhs.url &&
        lhs.name == rhs.name &&
        lhs.totalCapacity == rhs.totalCapacity &&
        lhs.availableCapacity == rhs.availableCapacity
    }

    var usedFraction: Double {
        guard totalCapacity > 0 else { return 0 }
        let used = Double(totalCapacity - availableCapacity) / Double(totalCapacity)
        return min(max(used, 0), 1)
    }

    var capacityHelp: String {
        let free = ByteCountFormatter.string(fromByteCount: availableCapacity, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalCapacity, countStyle: .file)
        return String(localized: "\(free) free of \(total)")
    }
}

/// Publishes the list of mounted, browsable volumes and refreshes it on
/// mount / unmount / rename events from `NSWorkspace`.
///
/// Enumeration happens off the main queue: `volumeTotalCapacityKey`
/// resolution issues a `statfs`-class call per volume, and a wedged
/// network mount must not be able to stall the UI.
final class VolumeListStore: ObservableObject {
    @Published private(set) var volumes: [VolumeInfo] = []
    private var observers: [NSObjectProtocol] = []
    private var refreshGeneration = 0

    init() {
        refresh()

        let center = NSWorkspace.shared.notificationCenter
        let events: [Notification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification
        ]
        for name in events {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            })
        }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
    }

    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let volumes = Self.loadVolumes()
            DispatchQueue.main.async {
                guard let self, self.refreshGeneration == generation else { return }
                if self.volumes != volumes {
                    self.volumes = volumes
                }
            }
        }
    }

    static func loadVolumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeIsBrowsableKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        return urls.compactMap { url -> VolumeInfo? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.volumeIsBrowsable == true else {
                return nil
            }
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 16, height: 16)
            return VolumeInfo(
                url: url.standardizedFileURL,
                name: values.volumeName ?? url.lastPathComponent,
                totalCapacity: Int64(values.volumeTotalCapacity ?? 0),
                availableCapacity: Int64(values.volumeAvailableCapacity ?? 0),
                icon: icon
            )
        }
    }
}

/// Sidebar DISKS section: every mounted volume with a usage bar.
/// Clicking a row opens the volume root in the active pane; the volume
/// holding the pane's current directory is highlighted.
struct DiskListSection: View {
    @ObservedObject var model: FileBrowserModel
    @ObservedObject var volumeStore: VolumeListStore
    let isTreeActive: Bool
    let activateTree: () -> Void

    @State private var currentVolumeURL: URL?
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(volumeStore.volumes) { volume in
                DiskRow(
                    volume: volume,
                    isCurrent: volume.url == currentVolumeURL,
                    isTreeActive: isTreeActive
                ) {
                    activateTree()
                    model.navigate(to: volume.url)
                }
            }
        }
        .onAppear {
            updateCurrentVolume()
        }
        .onChange(of: model.currentDirectory) {
            updateCurrentVolume()
        }
        .onChange(of: volumeStore.volumes) {
            updateCurrentVolume()
        }
    }

    /// Longest-prefix match against the listed volume paths. Pure string
    /// work — a `volumeURLKey` lookup would be a syscall on the current
    /// directory, and when that directory sits on an unresponsive
    /// network volume the call blocks the main thread indefinitely.
    private func updateCurrentVolume() {
        let path = model.currentDirectory.standardizedFileURL.path
        currentVolumeURL = volumeStore.volumes
            .map(\.url)
            .filter { volumeURL in
                let volumePath = volumeURL.path
                return path == volumePath
                    || volumePath == "/"
                    || path.hasPrefix(volumePath + "/")
            }
            .max { $0.path.count < $1.path.count }
    }
}

private struct DiskRow: View {
    let volume: VolumeInfo
    let isCurrent: Bool
    let isTreeActive: Bool
    let open: () -> Void

    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: volume.icon)
                .resizable()
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(volume.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                usageBar
            }
        }
        .font(design.fonts.swiftUIFont(for: .folderTree))
        .foregroundStyle(isCurrent ? theme.folderTreeSelectedForeground : theme.folderTreeForeground)
        .padding(.leading, 22)
        .padding(.trailing, 8)
        .padding(.vertical, 5)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            open()
        }
        .help(volume.capacityHelp)
    }

    private var usageBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.folderTreeForeground.opacity(0.18))
                Capsule()
                    .fill(theme.folderTreeFolderIcon)
                    .frame(width: max(2, geometry.size.width * volume.usedFraction))
            }
        }
        .frame(height: 3)
    }

    private var rowBackground: Color {
        if isCurrent {
            let color = isTreeActive ? theme.folderTreeSelectedActive : theme.folderTreeSelectedInactive
            return color.opacity(design.opacity.background)
        }
        return .clear
    }
}
#endif
