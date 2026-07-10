import SwiftUI
import Observation

/// Estado da Carteira Digital: carteiras do usuário, carteira selecionada, extrato por carteira.
/// Frontend-first: usa sempre o mock até a mobile-api expor endpoints de wallet.
@MainActor
@Observable
final class WalletStore: SessionResettable {
    private let repo: WalletRepository

    private(set) var wallets: [Wallet] = []
    private(set) var paymentsByWallet: [String: [WalletPayment]] = [:]

    var currentWalletID: String?
    var balanceHidden = false

    /// Escopo do extrato: segue a carteira da home (`.current`), uma carteira fixa ou todas.
    enum TransactionsScope: Hashable {
        case current
        case wallet(String)
        case all
    }
    var transactionsScope: TransactionsScope = .current

    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var hasLoaded = false
    private var isFetching = false      // evita carga dupla concorrente (ex.: dois .task no 1º appear)

    /// Carteira selecionada (fallback para a primeira).
    var currentWallet: Wallet? {
        wallets.first { $0.id == currentWalletID } ?? wallets.first
    }

    /// Extrato da carteira atual.
    var currentPayments: [WalletPayment] {
        guard let id = currentWallet?.id else { return [] }
        return paymentsByWallet[id] ?? []
    }

    /// Extrato conforme o escopo escolhido na tela de Transações.
    var scopedPayments: [WalletPayment] {
        switch transactionsScope {
        case .current: return currentPayments
        case .wallet(let id): return paymentsByWallet[id] ?? []
        case .all: return wallets.flatMap { paymentsByWallet[$0.id] ?? [] }
        }
    }

    /// Carteira dona de um pagamento (identidade visual no extrato).
    func wallet(for payment: WalletPayment) -> Wallet? {
        for (walletId, payments) in paymentsByWallet where payments.contains(where: { $0.id == payment.id }) {
            return wallets.first { $0.id == walletId }
        }
        return nil
    }

    /// Índice da carteira na lista (define a cor do cartão — `WalletCardStyle.at`).
    func styleIndex(for wallet: Wallet?) -> Int {
        guard let wallet else { return 0 }
        return wallets.firstIndex(where: { $0.id == wallet.id }) ?? 0
    }

    /// Garante o extrato de todas as carteiras em memória (escopo "Todas").
    /// Mock agrega por carteira; o live pode usar `GET /wallets/payments` direto.
    func ensureAllPaymentsLoaded() async {
        for wallet in wallets where paymentsByWallet[wallet.id] == nil {
            paymentsByWallet[wallet.id] = (try? await repo.payments(walletId: wallet.id)) ?? []
        }
    }

    // Repository compartilhado (o mock é stateful — pagamentos novos entram no extrato).
    init(repo: WalletRepository = ServiceContainer.shared.walletRepository) {
        self.repo = repo
        SessionResetRegistry.shared.register(self)
    }

    /// Limpa a carteira do usuário atual no signOut para não vazar dados no próximo login.
    func reset() {
        wallets = []
        paymentsByWallet = [:]
        currentWalletID = nil
        balanceHidden = false
        transactionsScope = .current
        isLoading = false
        loadError = nil
        hasLoaded = false
        isFetching = false
    }

    func load(force: Bool = false) async {
        if hasLoaded && !force { return }
        if isFetching { return }
        isFetching = true
        defer { isFetching = false }
        if force { await repo.invalidate() }
        isLoading = !hasLoaded
        loadError = nil
        do {
            var loaded = try await repo.wallets()
            // `balance` vem de endpoint separado (GET …/baas/account/balance) — mescla por carteira.
            for i in loaded.indices {
                loaded[i].balance = (try? await repo.balance(walletId: loaded[i].id)) ?? 0
            }
            wallets = loaded
            if currentWalletID == nil || !loaded.contains(where: { $0.id == currentWalletID }) {
                currentWalletID = loaded.first(where: \.active)?.id ?? loaded.first?.id
            }
            if let id = currentWallet?.id {
                paymentsByWallet[id] = (try? await repo.payments(walletId: id)) ?? []
            }
            hasLoaded = true
        } catch {
            loadError = (error as? APIError)?.userMessage ?? "Não foi possível carregar os cartões."
        }
        isLoading = false
    }

    /// Detalhe (comprovante) de um pagamento.
    func detail(for payment: WalletPayment) async throws -> WalletPaymentDetail {
        guard let walletId = currentWallet?.id else {
            throw WalletError.generic("Nenhum cartão selecionado.")
        }
        return try await repo.paymentDetail(walletId: walletId, paymentId: payment.id)
    }

    /// Recarrega o extrato da carteira atual (após um pagamento).
    func refreshCurrentPayments() async {
        guard let id = currentWallet?.id else { return }
        paymentsByWallet[id] = (try? await repo.payments(walletId: id)) ?? []
        // Limite/saldo também mudam após pagar.
        if var updated = try? await repo.wallets() {
            for i in updated.indices {
                updated[i].balance = (try? await repo.balance(walletId: updated[i].id)) ?? 0
            }
            wallets = updated
        }
    }

    /// Troca a carteira atual e carrega o extrato dela sob demanda.
    /// O extrato volta a seguir a carteira da home (escolha manual no dropdown é sobrescrita).
    func selectWallet(_ id: String) {
        currentWalletID = id
        transactionsScope = .current
        guard paymentsByWallet[id] == nil else { return }
        Task { paymentsByWallet[id] = (try? await repo.payments(walletId: id)) ?? [] }
    }
}
