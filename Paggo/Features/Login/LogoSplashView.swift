import SwiftUI
import Lottie

/// Splash de marca em 4 atos, exibido após o login enquanto o home carrega atrás:
///  1. o ícone gira (Lottie oficial) por ~1,5 s, escuro sobre branco;
///  2. o ícone desliza para a esquerda enquanto o wordmark "paggo" surge (wipe L→R), formando o
///     logo completo centralizado;
///  3. uma faixa escura reta desce de cima para baixo e, ao passar pelo logo, ele vira de preto
///     para branco (fundo na cor do app);
///  4. o splash some por opacidade, revelando o home atrás (`onFinish`).
struct LogoSplashView: View {
    var onFinish: () -> Void

    // Geometria do logo — mesma proporção do asset `PaggoLogo` (viewBox 266×32; ícone em x[0,48]).
    private static let logoHeight: CGFloat = 15
    private static let logoWidth: CGFloat = logoHeight * 266 / 32
    private static let iconRevealFraction: CGFloat = 49.0 / 266.0                 // revela só o ícone
    private static let iconCenterOffset: CGFloat = (0.5 - 24.0 / 266.0) * logoWidth // ícone no centro
    private static let iconFrameSize: CGFloat = 75

    /// Mesma cor escura do Lottie (#18181B) para um crossfade contínuo.
    private let ink = Color(hex: "#18181B")

    @State private var lottieOpacity = 1.0
    @State private var staticLogoOpacity = 0.0
    @State private var revealFraction = LogoSplashView.iconRevealFraction
    @State private var logoOffset = LogoSplashView.iconCenterOffset
    @State private var overlayProgress: CGFloat = 0
    @State private var splashOpacity = 1.0

    var body: some View {
        ZStack {
            // Mundo "antes": fundo branco + logo escuro.
            Color.white.ignoresSafeArea()

            logo(tint: ink, reveal: revealFraction, offsetX: logoOffset)
                .opacity(staticLogoOpacity)

            PaggoLoadingAnimation()
                .frame(width: Self.iconFrameSize, height: Self.iconFrameSize)
                .opacity(lottieOpacity)

            // Mundo "depois": MESMO fundo do home (`ScreenBackground`) + logo branco, revelado por
            // uma faixa reta que desce de cima para baixo. Usar o mesmo fundo garante que, ao fazer
            // o fade-out, não haja mudança de cor — só o logo some e o home aparece.
            ZStack {
                ScreenBackground()
                logo(tint: .white, reveal: 1, offsetX: 0)
            }
            .mask {
                CoverShape(progress: overlayProgress).fill(.black).ignoresSafeArea()
            }
        }
        .opacity(splashOpacity)
        .statusBarHidden(true)
        .task { await runSequence() }
    }

    /// Logo completo (ícone + "paggo") com revelação L→R (`reveal`) e deslocamento horizontal.
    private func logo(tint: Color, reveal: CGFloat, offsetX: CGFloat) -> some View {
        Image("PaggoLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.logoWidth, height: Self.logoHeight)
            .foregroundStyle(tint)
            .mask(alignment: .leading) {
                Rectangle().frame(width: max(0, reveal) * Self.logoWidth)
            }
            .offset(x: offsetX)
    }

    private func runSequence() async {
        // 1) Ícone girando (~1,5 s).
        try? await Task.sleep(for: .milliseconds(1500))

        // 1→2) Crossfade do Lottie para o logo estático (ícone ainda centralizado).
        withAnimation(.easeInOut(duration: 0.25)) {
            lottieOpacity = 0
            staticLogoOpacity = 1
        }
        try? await Task.sleep(for: .milliseconds(250))

        // 2) O ícone desliza para a esquerda enquanto "paggo" surge.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            logoOffset = 0
            revealFraction = 1
        }
        try? await Task.sleep(for: .milliseconds(600))

        // 3) Faixa escura reta desce de cima para baixo; o logo vira de preto para branco.
        withAnimation(.easeInOut(duration: 0.6)) {
            overlayProgress = 1
        }
        try? await Task.sleep(for: .milliseconds(500))

        // 4) Fade-out lento (~1,8 s) revelando o home (renderizado atrás). Como o fundo é idêntico
        //    (mesmo `ScreenBackground`), só o logo some e o conteúdo do home aparece.
        withAnimation(.easeInOut(duration: 1.8)) {
            splashOpacity = 0
        }
        try? await Task.sleep(for: .milliseconds(1800))
        onFinish()
    }
}

/// Faixa retangular reta (borda horizontal) que cobre a tela de cima para baixo conforme
/// `progress` vai de 0 (nada coberto) a 1 (tela inteira).
private struct CoverShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let covered = rect.height * max(0, min(1, progress))
        return Path(CGRect(x: 0, y: 0, width: rect.width, height: covered))
    }
}

/// Wrapper do `LottieAnimationView` para o arquivo oficial de carregamento, em loop.
private struct PaggoLoadingAnimation: UIViewRepresentable {
    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView()
        view.animation = LottieAnimation.named("PaggoLoading")
        view.contentMode = .scaleAspectFit
        view.loopMode = .loop
        view.backgroundBehavior = .pauseAndRestore
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.play()
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if !uiView.isAnimationPlaying { uiView.play() }
    }
}

#Preview("Splash") {
    LogoSplashView(onFinish: {})
}
