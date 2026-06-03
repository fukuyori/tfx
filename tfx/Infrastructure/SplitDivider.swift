#if os(macOS)
import SwiftUI

/// A static 1pt-wide vertical divider that matches `SplitDragHandle`'s
/// idle appearance but carries no gesture. Used between the split-view
/// left/right file panes, where the user is intentionally not allowed
/// to adjust the inner ratio — both halves stay equal width.
struct SplitDivider: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.splitHandleIdle)
    }
}
#endif
