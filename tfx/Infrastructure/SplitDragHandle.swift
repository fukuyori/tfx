#if os(macOS)
import SwiftUI

struct SplitDragHandle: View {
    let onStarted: () -> Void
    let onChanged: (Double) -> Void
    let onEnded: () -> Void

    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.green.opacity(0.8) : Color(nsColor: .separatorColor))
            .frame(width: isDragging ? 3 : 1)
            .contentShape(Rectangle().inset(by: -4))
            .cursor(.resizeLeftRight)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onStarted()
                        }
                        onChanged(Double(value.translation.width))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEnded()
                    }
            )
    }
}
#endif
