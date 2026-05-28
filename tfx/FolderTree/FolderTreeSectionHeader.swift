#if os(macOS)
import SwiftUI

struct FolderTreeSectionHeader: View {
    let title: LocalizedStringResource
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        Text(title)
            .font(design.fonts.swiftUIFont(for: .caption, weight: .semibold))
            .foregroundStyle(theme.folderTreeSectionHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.top, 9)
            .padding(.bottom, 4)
    }
}
#endif
