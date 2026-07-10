import SwiftUI

/// Animated horizontal progress bar. Turns red when over 100%.
struct ProgressBarView: View {
    let fraction: Double          // 0...n (can exceed 1 when over budget)
    var color: Color = Theme.neutralFill
    var height: CGFloat = 8

    @State private var animatedFraction: Double = 0

    private var isOver: Bool { fraction > 1 }
    private var fillColor: Color { isOver ? Theme.negative : color }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceHigh)
                Capsule()
                    .fill(Theme.categoryGradient(fillColor))
                    .frame(width: geo.size.width * min(animatedFraction, 1))
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                animatedFraction = fraction
            }
        }
        .onChange(of: fraction) { _, new in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                animatedFraction = new
            }
        }
    }
}
