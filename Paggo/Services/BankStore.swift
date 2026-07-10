import SwiftUI
import Observation

/// Estado das contas bancárias para o Dashboard: saldo de todas as contas + histórico de saldo
/// consolidado do grupo. Reads async (mock instantâneo; live via BankingAPI + QueryClient com
/// fallback offline).
@MainActor
@Observable
final class BankStore: SessionResettable {
    private let repo: BankAccountRepository

    private(set) var response: BankAccountListResponse = .empty
    private(set) var history: [BalanceHistoryPoint] = []
    private(set) var recentTransactionsList: [BankTransaction] = []
    private(set) var upcomingPayments: [UpcomingPayment] = []

    /// Movimentações recentes buscadas por conta (via `bankingAccountId`), para o detalhe da conta.
    private(set) var accountTransactions: [String: [BankTransaction]] = [:]
    private(set) var loadingAccountTransactions: Set<String> = []
    private(set) var accountTransactionsError: [String: String] = [:]

    /// Começa `true` para que o skeleton apareça já no primeiro frame (antes de `load()` rodar) —
    /// evita renderizar saldo 0 enquanto os dados reais ainda não chegaram.
    private(set) var isLoading = true
    private(set) var loadError: String?
    private(set) var isOffline = false
    private(set) var hasLoaded = false

    /// Conta selecionada para detalhar (nil = visão consolidada).
    var selectedAccountID: String?
    var balanceHidden = false

    /// Janela do histórico de saldo (default: últimos 30 dias).
    /// Debug: PAGGO_HISTORY_RANGE=last60|thisMonth|thisYear força a janela inicial.
    private(set) var historyRange: BalanceHistoryRange =
        ProcessInfo.processInfo.environment["PAGGO_HISTORY_RANGE"]
            .flatMap(BalanceHistoryRange.init) ?? .last30
    private(set) var isLoadingHistory = false

    init(repo: BankAccountRepository? = nil) {
        if let repo {
            self.repo = repo
        } else if AppConfig.current.dataSource == .live {
            self.repo = LiveBankAccountRepository(
                api: BankingAPI(client: ServiceContainer.shared.apiClient), query: QueryClient.shared)
        } else {
            self.repo = MockBankAccountRepository()
        }
        SessionResetRegistry.shared.register(self)
    }

    /// Limpa os dados do usuário atual no signOut. Volta ao estado de skeleton (`isLoading = true`,
    /// `hasLoaded = false`) para que o próximo login recarregue do zero e mostre skeleton em vez do
    /// saldo/transações do usuário anterior.
    func reset() {
        response = .empty
        history = []
        recentTransactionsList = []
        upcomingPayments = []
        accountTransactions = [:]
        loadingAccountTransactions = []
        accountTransactionsError = [:]
        isLoading = true
        loadError = nil
        isOffline = false
        hasLoaded = false
        selectedAccountID = nil
        balanceHidden = false
    }

    // MARK: - Carregamento

    func load(force: Bool = false) async {
        if hasLoaded && !force { return }
        if force { await repo.invalidate() }
        isLoading = !hasLoaded
        loadError = nil

        do {
            async let accountsResult = repo.accounts()
            async let historyResult = repo.balanceHistory(range: historyRange)
            async let transactionsResult = repo.recentTransactions()
            async let upcomingResult = repo.upcomingPayments()

            let loadedResponse = try await accountsResult
            // History/transactions/upcoming are best-effort: balances still render if any is unavailable.
            let loadedHistory = (try? await historyResult) ?? []
            let loadedTransactions = (try? await transactionsResult) ?? []
            let loadedUpcoming = (try? await upcomingResult) ?? []

            response = loadedResponse
            history = loadedHistory
            recentTransactionsList = loadedTransactions
            upcomingPayments = loadedUpcoming
            hasLoaded = true
            isOffline = !Connectivity.shared.isOnline
        } catch {
            let apiError = error as? APIError
            isOffline = apiError?.kind == .offline || !Connectivity.shared.isOnline
            loadError = apiError?.userMessage ?? "Não foi possível carregar as contas."
        }
        isLoading = false
    }

    /// Troca a janela do histórico e recarrega apenas o gráfico.
    func selectRange(_ range: BalanceHistoryRange) async {
        guard range != historyRange else { return }
        historyRange = range
        isLoadingHistory = true
        history = (try? await repo.balanceHistory(range: range)) ?? history
        isLoadingHistory = false
    }

    // MARK: - Leitura

    var accounts: [BankAccount] { response.data }
    var totalBalance: Int { response.totalBalance }
    var movements: MovementsSummary { response.movements }
    var hasMovements: Bool { movements.income.count > 0 || movements.expense.count > 0 }

    /// Carrega (lazy) as movimentações recentes de uma conta — chamado ao abrir o detalhe da conta.
    /// Enquanto a busca por conta não chega, `recentTransactions(for:)` deriva do consolidado (seed).
    func loadTransactions(for accountId: String) async {
        guard !loadingAccountTransactions.contains(accountId) else { return }
        loadingAccountTransactions.insert(accountId)
        accountTransactionsError[accountId] = nil
        defer { loadingAccountTransactions.remove(accountId) }
        do {
            accountTransactions[accountId] = try await repo.recentTransactions(for: accountId)
        } catch {
            accountTransactionsError[accountId] =
                (error as? APIError)?.userMessage ?? "Não foi possível carregar as movimentações."
        }
    }

    /// Transações de uma conta específica: usa as buscadas por conta; enquanto não chegam, deriva do
    /// consolidado para render instantâneo — usado no detalhe da conta.
    func recentTransactions(for accountId: String) -> [BankTransaction] {
        accountTransactions[accountId] ?? recentTransactionsList.filter { $0.accountId == accountId }
    }

    /// `true` enquanto a busca por conta está em voo e ainda não há resultado (nem seed do consolidado).
    func isLoadingTransactions(for accountId: String) -> Bool {
        loadingAccountTransactions.contains(accountId) && accountTransactions[accountId] == nil
    }

    func transactionsError(for accountId: String) -> String? {
        accountTransactionsError[accountId]
    }

    /// Transações consolidadas (todas as contas), mais recentes primeiro.
    var allRecentTransactions: [BankTransaction] { recentTransactionsList }
}
