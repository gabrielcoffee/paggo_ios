import Foundation

// Protocol-based repositories so the mock layer can be swapped for the backend client without
// touching the views/store. Payout is async (network-ready); Bank is still sync (mock-only) and
// will follow the same migration.

/// Entrada de aprovação (id + data de pagamento) — domínio puro, sem acoplar o DTO de request.
struct ApprovalInput: Sendable {
    let id: String
    let paymentDate: String
}

protocol PayoutRepository: Sendable {
    func packages(for tab: PackageTab, filters: PayoutFilters, page: Int,
                  orderBy: String, sort: String) async throws -> [Package]
    func totals(filters: PayoutFilters) async throws -> PackageTotals
    /// Opções de UMA categoria dinâmica (lazy, ao abrir o drawer). Mock deriva dos pacotes;
    /// live usa GET /package-filters com `active_filter=<key>` (cache curto via QueryClient).
    func filterOptions(key: String, for tab: PackageTab, filters: PayoutFilters) async throws -> [FilterOption]
    func approve(_ items: [ApprovalInput]) async throws -> BatchActionResponse
    /// Retornar para validação — a resposta é passthrough sem shape estável; 2xx = sucesso.
    func returnToValidation(ids: [String]) async throws
    func sendToApproval(ids: [String]) async throws -> SendToApprovalResponse
    /// Limpa caches (usado no pull-to-refresh). No-op no mock.
    func invalidate() async
}

protocol BankAccountRepository: Sendable {
    func accounts() async throws -> BankAccountListResponse
    func balanceHistory(range: BalanceHistoryRange) async throws -> [BalanceHistoryPoint]
    /// Transações recentes consolidadas (todas as contas), mais recentes primeiro.
    func recentTransactions() async throws -> [BankTransaction]
    /// Transações recentes de UMA conta (via `bankingAccountId`), mais recentes primeiro.
    func recentTransactions(for accountId: String) async throws -> [BankTransaction]
    /// Próximos pagamentos agendados (ordenados ascendente pela data).
    func upcomingPayments() async throws -> [UpcomingPayment]
    func invalidate() async
}

// MARK: - Mock (offline-dev / previews / tests)

/// Mock backed by `MockData`. Mirrors the existing paggo-mobile-app mocks.
struct MockPayoutRepository: PayoutRepository {
    func packages(for tab: PackageTab, filters: PayoutFilters, page: Int,
                  orderBy: String, sort: String) async throws -> [Package] {
        page == 0 ? (MockData.packagesByTab[tab] ?? []) : []   // mock tem só uma página
    }
    func totals(filters: PayoutFilters) async throws -> PackageTotals { MockData.totals }
    func filterOptions(key: String, for tab: PackageTab, filters: PayoutFilters) async throws -> [FilterOption] {
        PayoutFiltering.clientOptions(MockData.packagesByTab[tab] ?? [])
            .categories.first { $0.key == key }?.options ?? []
    }
    func approve(_ items: [ApprovalInput]) async throws -> BatchActionResponse {
        BatchActionResponse(status: 200, message: "OK", total: items.count, errors: nil)
    }
    func returnToValidation(ids: [String]) async throws {}
    func sendToApproval(ids: [String]) async throws -> SendToApprovalResponse {
        SendToApprovalResponse(statusCode: 200, errors: [], success: [])
    }
    func invalidate() async {}
}

struct MockBankAccountRepository: BankAccountRepository {
    func accounts() async throws -> BankAccountListResponse { MockData.accountListResponse }
    func balanceHistory(range: BalanceHistoryRange) async throws -> [BalanceHistoryPoint] {
        MockData.balanceHistory(range: range)
    }
    func recentTransactions() async throws -> [BankTransaction] { MockData.consolidatedRecentTransactions }
    func recentTransactions(for accountId: String) async throws -> [BankTransaction] {
        MockData.consolidatedRecentTransactions.filter { $0.accountId == accountId }
    }
    func upcomingPayments() async throws -> [UpcomingPayment] { MockData.upcomingPayments }
    func invalidate() async {}
}

/// Live banking: `BankingAPI` (mobile-api treasury endpoints) + `QueryClient` (cache + offline).
/// Saldos + histórico consolidado + transações recentes + próximos pagamentos são dados reais;
/// see docs/BACKEND-INTEGRATION.md.
struct LiveBankAccountRepository: BankAccountRepository {
    let api: BankingAPI
    let query: QueryClient

    func accounts() async throws -> BankAccountListResponse {
        try await query.fetch("treasury.accounts", staleTime: 60) {
            let accounts = try await api.accounts()
            let total = accounts.reduce(0) { $0 + $1.balance }
            return BankAccountListResponse(
                data: accounts, total: accounts.count, totalBalance: total,
                movements: .zero
            )
        }
    }

    func balanceHistory(range: BalanceHistoryRange) async throws -> [BalanceHistoryPoint] {
        let dates = range.dates()
        return try await query.fetch("treasury.balanceHistory.\(range.rawValue)", staleTime: 60) {
            try await api.consolidatedBalanceHistory(startDate: dates.start, endDate: dates.end)
        }
    }

    /// Consolida todas as contas numa única chamada (sem `bankingAccountId`), janela de 60 dias.
    func recentTransactions() async throws -> [BankTransaction] {
        try await query.fetch("treasury.transactions.recent", staleTime: 60) {
            let dates = BalanceHistoryRange.last60.dates()
            let transactions = try await api.transactions(
                startDate: dates.start, endDate: dates.end, page: 1)
            return transactions.sorted { $0.date > $1.date }
        }
    }

    /// Movimentações recentes de UMA conta (via `bankingAccountId`), janela de 60 dias.
    func recentTransactions(for accountId: String) async throws -> [BankTransaction] {
        try await query.fetch("treasury.transactions.account.\(accountId)", staleTime: 60) {
            let dates = BalanceHistoryRange.last60.dates()
            let transactions = try await api.transactions(
                startDate: dates.start, endDate: dates.end, bankingAccountId: accountId, page: 1)
            return transactions.sorted { $0.date > $1.date }
        }
    }

    func upcomingPayments() async throws -> [UpcomingPayment] {
        // Chave sob o prefixo `treasury.` para ser invalidada no pull-to-refresh das contas.
        try await query.fetch("treasury.upcomingPayments", staleTime: 60) {
            try await api.upcomingPayments(limit: 7)
        }
    }

    func invalidate() async {
        await query.invalidate(prefix: "treasury.")
    }
}

// MARK: - Live (backend via PayoutAPI + QueryClient)

/// Implementação real do Payout: rede via `PayoutAPI`, cache + leitura offline via `QueryClient`.
/// Mutações invalidam o cache para que o próximo carregamento venha fresco.
struct LivePayoutRepository: PayoutRepository {
    let api: PayoutAPI
    let query: QueryClient

    func packages(for tab: PackageTab, filters: PayoutFilters, page: Int,
                  orderBy: String, sort: String) async throws -> [Package] {
        let sig = filters.serverSignature
        let key = "\(PaymentKeys.packages(tab.rawValue)).\(sig).\(orderBy).\(sort).p\(page)"
        return try await query.fetch(key, staleTime: 60) {
            try await api.packages(status: tab.statuses, filters: filters, page: page,
                                   orderBy: orderBy, sort: sort)
        }
    }

    func totals(filters: PayoutFilters) async throws -> PackageTotals {
        let sig = filters.serverSignature
        let key = sig.isEmpty ? PaymentKeys.totals : "\(PaymentKeys.totals).\(sig)"
        return try await query.fetch(key, staleTime: 60) {
            try await api.totals(filters: filters)
        }
    }

    /// Cache curto por (tab, categoria, filtros). Em falha de refetch o `QueryClient` devolve o
    /// último valor bom persistido para a MESMA chave; sob a mesma chave também deduplica em voo.
    func filterOptions(key: String, for tab: PackageTab, filters: PayoutFilters) async throws -> [FilterOption] {
        let sig = filters.serverSignature
        let cacheKey = "\(PaymentKeys.all).filter-options.\(tab.rawValue).\(key).\(sig)"
        return try await query.fetch(cacheKey, staleTime: 60) {
            try await api.filterOptions(key: key, status: tab.statuses, filters: filters)
        }
    }

    func approve(_ items: [ApprovalInput]) async throws -> BatchActionResponse {
        let response = try await api.approve(items.map { .init(id: $0.id, paymentDate: $0.paymentDate) })
        await query.invalidate(prefix: PaymentKeys.all)
        return response
    }

    func returnToValidation(ids: [String]) async throws {
        try await api.cancelApproval(ids: ids)
        await query.invalidate(prefix: PaymentKeys.all)
    }

    func sendToApproval(ids: [String]) async throws -> SendToApprovalResponse {
        let response = try await api.sendToApproval(ids: ids)
        await query.invalidate(prefix: PaymentKeys.all)
        return response
    }

    func invalidate() async {
        await query.invalidate(prefix: PaymentKeys.all)
    }
}
