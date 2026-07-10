import SwiftUI

/// Liquid Glass tab bar (automático no iOS 26) unindo as três áreas: Dashboard, Pagamentos, Aprovações.
/// Antes do tab bar, exige autenticação na `LoginView` (gate via `AuthStore`).
struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(PayoutStore.self) private var store
    @Environment(AppModeStore.self) private var appMode

    /// Debug: abre uma tela direto via env (usado para verificação de UI), pulando o login.
    private var debugScreen: String? { ProcessInfo.processInfo.environment["PAGGO_SCREEN"] }

    private var pendingApprovals: Int { store.count(for: .approval) }

    var body: some View {
        Group {
            if let debugScreen {
                switch debugScreen {
                case "dashboard": DashboardView()
                case "payments": PaymentsView()
                case "approvals": ApprovalsView()
                case "detail": PackageDetailDebug()
                case "purchaseRequests": PurchaseRequestsView()
                case "newrequest": NewRequestFlow(type: .purchase) { _ in }
                case "splash": LogoSplashView {}
                case "wallet": WalletRootView()
                default: tabs
                }
            } else {
                authenticatedOrLogin
            }
        }
        .environment(ToastCenter.shared)
        // Toasts renderizam numa janela dedicada (ToastWindowManager, instalada no PaggoApp) —
        // acima de pushes, tabs, sheets, covers e alerts; um overlay aqui perderia para eles.
    }

    /// App em si, conforme o modo escolhido no popover do avatar (plataforma vs carteira).
    @ViewBuilder private var mainScreen: some View {
        Group {
            if appMode.mode == .wallet {
                WalletRootView()
            } else {
                tabs
            }
        }
        // Trocar de empresa (customer) remonta o app → todas as telas recarregam sob a nova empresa
        // (os stores por-empresa já foram limpos por `SessionResetRegistry.resetAll()` no AuthStore).
        .id(auth.activeUser?.currentCustomerId)
    }

    /// Gate de autenticação: login → splash da marca → app. Durante `.launching` o `mainScreen` já
    /// fica renderizado atrás (carregando), e o splash some por opacidade revelando-o.
    @ViewBuilder private var authenticatedOrLogin: some View {
        ZStack {
            if auth.phase != .loggedOut {
                mainScreen
            }
            if auth.phase == .loggedOut {
                LoginView().transition(.opacity)
            }
            if auth.phase == .launching {
                LogoSplashView { auth.finishLaunch() }
                    .transition(.identity)
            }
        }
        .animation(.smooth(duration: 0.4), value: auth.phase)
    }

    private var tabs: some View {
        TabView {
            Tab("Visão geral", systemImage: "square.grid.2x2") {
                DashboardView()
            }
            Tab("Solicitações", systemImage: "tray.full") {
                PurchaseRequestsView()
            }
            Tab("Pagamentos", systemImage: "list.bullet.rectangle.portrait") {
                PaymentsView()
            }
            Tab("Aprovações", systemImage: "checkmark.seal") {
                ApprovalsView()
            }
            .badge(pendingApprovals)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task { await store.load() }
    }
}

/// Debug: abre um pacote de exemplo direto nos detalhes (para verificação de UI).
struct PackageDetailDebug: View {
    private var sample: Package? {
        // Lê direto dos mocks (a tela de detalhes ainda é mock); independe do load assíncrono.
        // Debug: PAGGO_DETAIL_STATUS=PAID|APPROVED|... abre um pacote daquele status (verificação do rodapé).
        let all = MockData.packagesByTab.values.flatMap { $0 }
        if let raw = ProcessInfo.processInfo.environment["PAGGO_DETAIL_STATUS"],
           let status = PackageStatus(rawValue: raw),
           let match = all.first(where: { $0.status == status }) {
            return match
        }
        let approval = MockData.packagesByTab[.approval] ?? []
        return approval.first { MockData.details(for: $0).consumesBudget } ?? approval.first
    }

    var body: some View {
        NavigationStack {
            if let sample {
                PackageDetailView(package: sample)
            } else {
                Text("Sem pacote").foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

/// Shared screen background: near-black base with a soft accent aurora at the top.
/// `tint` troca a cor da aurora (telas da Carteira usam a cor do cartão selecionado).
struct ScreenBackground: View {
    var tint: Color? = nil

    var body: some View {
        ZStack {
            Theme.base.ignoresSafeArea()
            Theme.aurora(tint: tint)
                .ignoresSafeArea()
                .opacity(0.7)
                .blendMode(.plusLighter)
        }
    }
}

extension View {
    /// Applies the standard dark screen background behind a view.
    func screenBackground(tint: Color? = nil) -> some View {
        background(ScreenBackground(tint: tint))
    }
}
