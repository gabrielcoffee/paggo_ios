import SwiftUI
import Lottie

/// Wrapper genérico de animação Lottie (arquivo JSON no bundle).
/// Com Reduce Motion ativo, renderiza o fallback estático (`TintedIcon`) no lugar da animação —
/// use `reducedMotionFallback` sempre que a animação comunicar estado (sucesso/falha/etc).
struct BrandLottieView: View {
    let name: String
    var loopMode: LottieLoopMode = .playOnce
    var reducedMotionFallback: (symbol: String, tint: Color)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion, let fallback = reducedMotionFallback {
            TintedIcon(symbol: fallback.symbol, tint: fallback.tint, size: 84, symbolSize: 38)
        } else {
            LottieRepresentable(name: name, loopMode: loopMode)
                .clipped()
        }
    }
}

private struct LottieRepresentable: UIViewRepresentable {
    let name: String
    let loopMode: LottieLoopMode

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView()
        view.animation = LottieAnimation.named(name)
        view.contentMode = .scaleAspectFit
        view.loopMode = loopMode
        view.backgroundBehavior = .pauseAndRestore
        view.clipsToBounds = true
        // Sem prioridade de compressão o intrinsic size do composition estoura o frame proposto.
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.play()
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if !uiView.isAnimationPlaying, loopMode == .loop { uiView.play() }
    }
}
