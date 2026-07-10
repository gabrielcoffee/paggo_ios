import Foundation
import Observation

/// Enriquecimento pós-pagamento de uma transação da carteira (espelha o módulo payment-info do
/// wallet-pwa): descrição, anexos e alocações de custo. Resolve as pendências do extrato (RN-21).
@MainActor
@Observable
final class WalletPaymentDetailStore {
    private let repo: WalletRepository
    let walletId: String
    private(set) var payment: WalletPayment

    var descriptionDraft: String = ""
    private(set) var attachments: [WalletPaymentAttachment] = []
    var allocationDrafts: [WalletPaymentAllocation] = []
    private(set) var projects: [AllocationOption] = []
    private(set) var managerials: [AllocationOption] = []

    private(set) var isLoading = false
    private(set) var isSaving = false

    init(payment: WalletPayment, walletId: String,
         repo: WalletRepository = ServiceContainer.shared.walletRepository) {
        self.payment = payment
        self.walletId = walletId
        self.repo = repo
        self.descriptionDraft = payment.description ?? ""
    }

    /// Soma dos percentuais — salvar exige exatamente 100 e toda linha com destino (RN-20).
    var allocationTotal: Int { allocationDrafts.reduce(0) { $0 + $1.percentage } }
    var allocationsValid: Bool {
        !allocationDrafts.isEmpty && allocationTotal == 100 &&
        allocationDrafts.allSatisfy { $0.projectId != nil || $0.managerialId != nil }
    }

    var hasPendencies: Bool { payment.hasPendencies }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let attachmentsTask = repo.attachments(walletId: walletId, paymentId: payment.id)
        async let allocationsTask = repo.allocations(walletId: walletId, paymentId: payment.id)
        async let projectsTask = repo.projects()
        async let managerialsTask = repo.managerials()
        attachments = (try? await attachmentsTask) ?? []
        allocationDrafts = (try? await allocationsTask) ?? []
        projects = (try? await projectsTask) ?? []
        managerials = (try? await managerialsTask) ?? []
        if allocationDrafts.isEmpty {
            allocationDrafts = [WalletPaymentAllocation(percentage: 100)]
        }
    }

    func saveDescription() async {
        isSaving = true
        defer { isSaving = false }
        let text = descriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await repo.updateDescription(walletId: walletId, paymentId: payment.id, description: text)
            payment.description = text
            ToastCenter.shared.show("Descrição salva.")
        } catch {
            ToastCenter.shared.show("Não foi possível salvar a descrição.", style: .error)
        }
    }

    func addAttachment(fileName: String, data: Data) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let attachment = try await repo.addAttachment(walletId: walletId, paymentId: payment.id,
                                                          fileName: fileName, data: data)
            attachments.append(attachment)
            payment.hasAttachments = true
            ToastCenter.shared.show("Anexo adicionado.")
        } catch {
            ToastCenter.shared.show("Não foi possível anexar o arquivo.", style: .error)
        }
    }

    func saveAllocations() async {
        guard allocationsValid else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await repo.setAllocations(walletId: walletId, paymentId: payment.id, allocationDrafts)
            payment.allocationPending = false
            ToastCenter.shared.show("Alocações salvas.")
        } catch {
            ToastCenter.shared.show("Não foi possível salvar as alocações.", style: .error)
        }
    }

    func addAllocationRow() {
        let remaining = max(0, 100 - allocationTotal)
        allocationDrafts.append(WalletPaymentAllocation(percentage: remaining))
    }

    func removeAllocation(_ id: String) {
        allocationDrafts.removeAll { $0.id == id }
    }
}
