import Foundation
import Observation

/// Estado de orçamentos do funcionário: budgets + memberships + pedidos de aumento.
/// Consumo vive no servidor (repo); mutações recarregam — a store nunca ajusta cópias locais.
@MainActor
@Observable
final class BudgetStore: SessionResettable {
    private let repo: BudgetRepository

    private(set) var budgets: [Budget] = []
    private(set) var memberships: [BudgetMembership] = []
    private(set) var limitRequests: [LimitRequest] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var hasLoaded = false

    init(repo: BudgetRepository = ServiceContainer.shared.budgetRepository) {
        self.repo = repo
        SessionResetRegistry.shared.register(self)
    }

    func reset() {
        budgets = []
        memberships = []
        limitRequests = []
        isLoading = false
        loadError = nil
        hasLoaded = false
    }

    /// Par (budget, membership) do usuário — a unidade exibida em listas e no hub.
    var overviews: [(budget: Budget, membership: BudgetMembership)] {
        memberships.compactMap { membership in
            budgets.first { $0.id == membership.budgetId }.map { ($0, membership) }
        }
    }

    func membership(id: String) -> BudgetMembership? { memberships.first { $0.id == id } }
    func budget(id: String) -> Budget? { budgets.first { $0.id == id } }

    /// Pedido pendente do membership, se houver (máx. 1 — regra do servidor).
    func pendingRequest(membershipId: String) -> LimitRequest? {
        limitRequests.first { $0.membershipId == membershipId && $0.isPending }
    }

    func load(force: Bool = false) async {
        if hasLoaded && !force { return }
        if force { await repo.invalidate() }
        isLoading = !hasLoaded
        loadError = nil
        do {
            async let budgets = repo.budgets()
            async let memberships = repo.memberships()
            async let requests = repo.limitRequests()
            self.budgets = try await budgets
            self.memberships = try await memberships
            self.limitRequests = try await requests
            hasLoaded = true
        } catch {
            loadError = (error as? SpendError)?.userMessage ?? "Não foi possível carregar os orçamentos."
        }
        isLoading = false
    }

    @discardableResult
    func submitLimitRequest(_ draft: LimitRequestDraft) async throws -> LimitRequest {
        let request = try await repo.submitLimitRequest(draft)
        await load(force: true)
        return request
    }
}
