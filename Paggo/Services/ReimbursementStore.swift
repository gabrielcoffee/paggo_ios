import Foundation
import Observation

/// Estado de reembolsos do funcionário. Policy flags e auto-aprovação acontecem no servidor;
/// a store só reflete o resultado e recarrega após mutações.
@MainActor
@Observable
final class ReimbursementStore: SessionResettable {
    private let repo: ReimbursementRepository

    private(set) var items: [Reimbursement] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var hasLoaded = false

    init(repo: ReimbursementRepository = ServiceContainer.shared.reimbursementRepository) {
        self.repo = repo
        SessionResetRegistry.shared.register(self)
    }

    func reset() {
        items = []
        isLoading = false
        loadError = nil
        hasLoaded = false
    }

    var inProgress: [Reimbursement] { items.filter { $0.status == .submitted || $0.status == .approved } }

    func load(force: Bool = false) async {
        if hasLoaded && !force { return }
        if force { await repo.invalidate() }
        isLoading = !hasLoaded
        loadError = nil
        do {
            items = try await repo.reimbursements()
            hasLoaded = true
        } catch {
            loadError = (error as? SpendError)?.userMessage ?? "Não foi possível carregar os reembolsos."
        }
        isLoading = false
    }

    @discardableResult
    func submit(_ draft: ReimbursementDraft) async throws -> Reimbursement {
        let item = try await repo.submit(draft)
        await load(force: true)
        return item
    }

    func cancel(id: String) async {
        do {
            _ = try await repo.cancel(id: id)
            await load(force: true)
            ToastCenter.shared.show("Reembolso cancelado")
        } catch {
            ToastCenter.shared.show((error as? SpendError)?.userMessage ?? "Não foi possível cancelar.",
                                    style: .error)
        }
    }
}
