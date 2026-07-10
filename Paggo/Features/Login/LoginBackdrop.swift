import SwiftUI

/// Fundo da tela de login: imagem em tela cheia (sorteada a cada acesso), com scrims para
/// legibilidade, e a marca Paggo (logo oficial) centralizada no topo.
struct LoginBackdrop: View {
    /// Imagens disponíveis no catálogo (LoginBackground1…N).
    private static let imageNames = ["LoginBackground1", "LoginBackground2",
                                     "LoginBackground3", "LoginBackground4",
                                     "LoginBackground5", "LoginBackground6",
                                     "LoginBackground7", "LoginBackground8"]

    /// Sorteada uma vez por criação da view (i.e. a cada vez que a tela de login aparece).
    @State private var imageName = LoginBackdrop.imageNames.randomElement() ?? "LoginBackground1"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(imageName)
                .resizable()
                .scaledToFill()
                .saturation(1.18)
                .ignoresSafeArea()
                .transition(.opacity)

            // Scrim no topo (status bar + logo) e na base (cartão de vidro).
            LinearGradient(
                colors: [.black.opacity(0.45), .clear, .clear, .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            logo
        }
    }

    private var logo: some View {
        Image("PaggoLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 150)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 64)
    }
}
