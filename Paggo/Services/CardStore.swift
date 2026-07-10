import Foundation
import Observation

/// Estado do cartão corporativo do funcionário + feed de transações.
@MainActor
@Observable
final class CardStore: SessionResettable {
    private let repo: CardRepository

    private(set) var card: CorporateCard?
    private(set) var transactions: [CardTransaction] = []
    private(set) var isLoading = false
    private(set) var isMutating = false
    private(set) var loadError: String?
    private(set) var hasLoaded = false

    init(repo: CardRepository = ServiceContainer.shared.cardRepository) {
        self.repo = repo
        SessionResetRegistry.shared.register(self)
    }

    func reset() {
        card = nil
        transactions = []
        isLoading = false
        isMutating = false
        loadError = nil
        hasLoaded = false
    }

    /// Transações sem recibo já liquidadas/autorizadas — alimenta pendências.
    var missingReceipts: [CardTransaction] {
        transactions.filter { $0.countsAsSpend && $0.receiptStatus == .missing }
    }

    func load(force: Bool = false) async {
        if hasLoaded && !force { return }
        if force { await repo.invalidate() }
        isLoading = !hasLoaded
        loadError = nil
        do {
            async let card = repo.card()
            async let transactions = repo.transactions()
            self.card = try await card
            self.transactions = try await transactions
            hasLoaded = true
        } catch {
            loadError = (error as? SpendError)?.userMessage ?? "Não foi possível carregar o cartão."
        }
        isLoading = false
    }

    @discardableResult
    func setFrozen(_ frozen: Bool) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        defer { isMutating = false }
        do {
            card = try await repo.setFrozen(frozen)
            return true
        } catch {
            ToastCenter.shared.show((error as? SpendError)?.userMessage ?? "Não foi possível atualizar o cartão.",
                                    style: .error)
            return false
        }
    }

    /// Chamador garante Face ID recente; o dado revelado não é guardado na store.
    func reveal() async throws -> RevealedCardDetails {
        try await repo.reveal()
    }

    func correctCategory(transactionId: String, category: MerchantCategory) async {
        do {
            try await repo.correctCategory(transactionId: transactionId, category: category)
            await load(force: true)
        } catch {
            ToastCenter.shared.show("Não foi possível corrigir a categoria.", style: .error)
        }
    }
}
