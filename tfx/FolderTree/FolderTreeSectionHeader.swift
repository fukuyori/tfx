#if os(macOS)
import SwiftUI

struct FolderTreeSectionHeader: View {
    let title: LocalizedStringResource

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.green.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.top, 9)
            .padding(.bottom, 4)
            .background(Color.black)
    }
}
#endif
