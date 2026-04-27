#if os(macOS)
import SwiftUI

extension TerminalFileManagerView {
    @ViewBuilder
    var hoverHelpOverlay: some View {
        if !hoverHelpText.isEmpty {
            Text(hoverHelpText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .padding(.trailing, 10)
                .padding(.bottom, 2)
                .allowsHitTesting(false)
        }
    }
}
#endif
