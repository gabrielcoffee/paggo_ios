import SwiftUI
import Observation

/// Aba ativa do modo Carteira — compartilhada via environment para permitir atalhos de navegação
/// (ex.: "Ver no extrato" na tela de sucesso do pagamento).
@MainActor
@Observable
final class WalletTabRouter {
    enum WalletTab: String { case inicio, pagar, transacoes }
    var selection: WalletTab = .inicio
}

/// Raiz do modo Carteira Digital — tab bar Liquid Glass com Início / Pagar / Transações.
/// Espelha a bottom navigation do apps/wallet-pwa.
struct WalletRootView: View {
    @Environment(WalletStore.self) private var wallet

    @State private var router: WalletTabRouter = {
        let router = WalletTabRouter()
        // Debug: PAGGO_WALLET_TAB=inicio|pagar|transacoes abre direto numa aba (verificação de UI).
        if let raw = ProcessInfo.processInfo.environment["PAGGO_WALLET_TAB"],
           let tab = WalletTabRouter.WalletTab(rawValue: raw) {
            router.selection = tab
        }
        return router
    }()

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selection) {
            Tab("Início", systemImage: "house.fill", value: WalletTabRouter.WalletTab.inicio) {
                WalletHomeView()
            }
            Tab("Pagar", systemImage: "dollarsign.circle.fill", value: WalletTabRouter.WalletTab.pagar) {
                WalletPaymentMenuView()
            }
            Tab("Extrato", systemImage: "list.bullet.rectangle.portrait",
                value: WalletTabRouter.WalletTab.transacoes) {
                WalletTransactionsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task { await wallet.load() }
        .environment(router)
    }
}
