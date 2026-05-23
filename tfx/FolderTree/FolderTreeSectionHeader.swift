#if os(macOS)
import SwiftUI

struct FolderTreeSectionHeader: View {
    let title: LocalizedStringResource
    @Environment(\.theme) private var theme

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(theme.folderTreeSectionHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.top, 9)
            .padding(.bottom, 4)
            .background(theme.folderTreeBackground)
    }
}
#endif
