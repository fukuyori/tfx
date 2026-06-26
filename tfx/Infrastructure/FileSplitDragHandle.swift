#if os(macOS)
import SwiftUI

struct FileSplitDragHandle: View {
    let canResize: Bool
    let onStarted: () -> Void
    let onChanged: (Double) -> Void
    let onEnded: () -> Void

    @State private var isDragging = false
    @Environment(\.theme) private var theme

    var body: some View {
        Rectangle()
            .fill(isDragging ? theme.splitHandleActive : theme.splitHandleIdle)
            .frame(width: TerminalFileManagerLayout.dividerWidth)
            .contentShape(Rectangle().inset(by: -4))
            .cursor(.resizeLeftRight)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard canResize else { return }
                        if !isDragging {
                            isDragging = true
                            onStarted()
                        }
                        onChanged(Double(value.translation.width))
                    }
                    .onEnded { _ in
                        guard isDragging else { return }
                        isDragging = false
                        onEnded()
                    }
            )
    }
}
#endif
