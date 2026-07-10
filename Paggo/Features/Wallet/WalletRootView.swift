import SwiftUI
import Observation

/// Aba ativa do modo Carteira — compartilhada via environment para permitir atalhos de navegação
/// (ex.: "Ver no extrato" na tela de sucesso do pagamento).
@MainActor
@Observable
final class WalletTabRouter {
    enum WalletTab: String { case inicio, extrato, avisos, perfil }
    var selection: WalletTab = .inicio
}

/// Raiz do modo Carteira — tab bar Liquid Glass com Início / Extrato / Avisos / Perfil.
/// Abas são lugares; ações (Pagar, Reembolso…) são fluxos abertos pelo hub do Início.
struct WalletRootView: View {
    @Environment(WalletStore.self) private var wallet
    @Environment(NoticeStore.self) private var notices

    @State private var router: WalletTabRouter = {
        let router = WalletTabRouter()
        // Debug: PAGGO_WALLET_TAB=inicio|extrato|avisos|perfil abre direto numa aba
        // ("transacoes" legado ainda aceito).
        if let raw = ProcessInfo.processInfo.environment["PAGGO_WALLET_TAB"] {
            if let tab = WalletTabRouter.WalletTab(rawValue: raw) {
                router.selection = tab
            } else if raw == "transacoes" {
                router.selection = .extrato
            }
        }
        return router
    }()

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selection) {
            Tab("Início", systemImage: "house.fill", value: WalletTabRouter.WalletTab.inicio) {
                WalletHomeView()
            }
            Tab("Extrato", systemImage: "list.bullet.rectangle.portrait",
                value: WalletTabRouter.WalletTab.extrato) {
                WalletTransactionsView()
            }
            Tab("Avisos", systemImage: "bell.fill", value: WalletTabRouter.WalletTab.avisos) {
                NoticesView()
            }
            .badge(notices.unreadCount)
            Tab("Perfil", systemImage: "person.crop.circle", value: WalletTabRouter.WalletTab.perfil) {
                WalletProfileView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task {
            await wallet.load()
            await notices.load()
        }
        .environment(router)
    }
}
