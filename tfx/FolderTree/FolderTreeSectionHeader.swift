#if os(macOS)
import SwiftUI

/// Sidebar section header (PINNED / DISKS / FOLDERS). When `isCollapsed`
/// is provided the header shows a state chevron and toggles the binding
/// on click; collapse state is persisted by the caller (`@AppStorage`).
/// `accessory` renders trailing controls (e.g. the FOLDERS section's
/// collapse-all button) without the tap-to-collapse gesture swallowing
/// their clicks — the toggle gesture sits on the chevron + title only.
struct FolderTreeSectionHeader<Accessory: View>: View {
    let title: LocalizedStringResource
    var isCollapsed: Binding<Bool>?
    @ViewBuilder var accessory: () -> Accessory

    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    init(
        title: LocalizedStringResource,
        isCollapsed: Binding<Bool>? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.isCollapsed = isCollapsed
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                if let isCollapsed {
                    Image(systemName: isCollapsed.wrappedValue ? "chevron.right" : "chevron.down")
                        .font(design.fonts.swiftUIFont(for: .caption, weight: .semibold))
                        .frame(width: 10)
                }
                Text(title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                isCollapsed?.wrappedValue.toggle()
            }

            accessory()
        }
        .font(design.fonts.swiftUIFont(for: .caption, weight: .semibold))
        .foregroundStyle(theme.folderTreeSectionHeader)
        .padding(.horizontal, 10)
        .padding(.top, 9)
        .padding(.bottom, 4)
    }
}
#endif
