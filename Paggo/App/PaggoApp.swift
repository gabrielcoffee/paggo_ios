import SwiftUI
import FirebaseAuth
import GoogleSignIn

/// Configura o Firebase no launch (se houver GoogleService-Info.plist).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseBootstrap.configure()
        DevSession.seedIfNeeded(into: ServiceContainer.shared.tokenStore)
        configureNavigationBarAppearance()
        return true
    }

    /// Títulos da navigation bar (Visão Geral, Pagamentos…) em serifa, mantendo o fundo transparente.
    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [.font: titleFont(size: 32), .foregroundColor: UIColor.label]
        appearance.titleTextAttributes = [.font: titleFont(size: 17), .foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    /// Fonte de título em serifa. Placeholder: serifa do sistema (New York), até os arquivos de
    /// `herbikSerif` (.ttf/.otf) serem adicionados a Resources/Fonts + Info.plist (UIAppFonts) —
    /// então basta descomentar a linha abaixo. Ver native/ios/docs/FONTS.md.
    private func titleFont(size: CGFloat) -> UIFont {
        // if let herbik = UIFont(name: "herbikSerif", size: size) { return herbik }
        let base = UIFont.systemFont(ofSize: size, weight: .regular)
        if let descriptor = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }
}

@main
struct PaggoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var appearance = AppearanceStore()
    @State private var appMode = AppModeStore()
    @State private var authStore = AuthStore()
    @State private var payoutStore = PayoutStore()
    @State private var bankStore = BankStore()
    @State private var purchaseRequestsStore = PurchaseRequestsStore()
    @State private var walletStore = WalletStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appearance.mode.colorScheme)
                .tint(Theme.accent)
                .environment(\.locale, Locale(identifier: "pt_BR"))
                .environment(appearance)
                .environment(appMode)
                .environment(authStore)
                .environment(payoutStore)
                .environment(bankStore)
                .environment(purchaseRequestsStore)
                .environment(walletStore)
                .onOpenURL { url in
                    // Callback do OAuth genérico do Firebase (Microsoft) tem prioridade;
                    // o que sobrar segue para o Google Sign-In.
                    if Auth.auth().canHandle(url) { return }
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    // Janela dedicada de toasts — renderiza acima de sheets/alerts. Reinstala a
                    // cada ativação: segue a cena em primeiro plano e sobrevive a reconexões.
                    if phase == .active {
                        ToastWindowManager.shared.install(appearance: appearance)
                    }
                }
        }
    }
}
