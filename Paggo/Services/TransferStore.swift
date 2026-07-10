import SwiftUI
import Observation

/// Estado do fluxo de transferência entre contas (origem → destino, valor). O 2FA (Face ID ou
/// código por e-mail) é aplicado pela `TwoFactorSheet` na `TransferView` antes de chamar `execute()`;
/// executa via `/treasury/v2/execute-transfer`. No mock simula sucesso. As contas vêm do dashboard.
@MainActor
@Observable
final class TransferStore {
    enum Phase: Equatable {
        case editing
        case submitting
        case success(String)
        case failed(String)
    }

    let accounts: [BankAccount]
    private let isLive: Bool
    private let api: TransferAPI

    var originID: String?
    var destinationID: String?
    var amountCents: Int = 0
    var note: String = ""
    private(set) var phase: Phase = .editing

    /// Teto de segurança (R$ 2.000.000 — mesmo limite do app web para PIX).
    static let maxAmountCents = 200_000_000

    init(accounts: [BankAccount]) {
        self.accounts = accounts
        self.isLive = AppConfig.current.dataSource == .live
        self.api = TransferAPI(client: ServiceContainer.shared.apiClient)
        // Pré-seleciona a origem com maior saldo (atalho comum).
        self.originID = accounts.max(by: { $0.balance < $1.balance })?.id
    }

    var origin: BankAccount? { accounts.first { $0.id == originID } }
    var destination: BankAccount? { accounts.first { $0.id == destinationID } }

    var insufficientFunds: Bool { amountCents > (origin?.balance ?? 0) }
    var exceedsMax: Bool { amountCents > Self.maxAmountCents }
    var isSubmitting: Bool { phase == .submitting }

    var canSubmit: Bool {
        guard let o = originID, let d = destinationID, o != d else { return false }
        return amountCents > 0 && !insufficientFunds && !exceedsMax && phase == .editing
    }

    var errorText: String? {
        if insufficientFunds && amountCents > 0 { return "Valor acima do saldo da conta de origem." }
        if exceedsMax { return "Para transferir acima de R$ 2.000.000,00 fale com a Paggo." }
        return nil
    }

    /// Contas disponíveis como destino (todas menos a origem selecionada).
    func destinationOptions() -> [BankAccount] { accounts.filter { $0.id != originID } }
    func originOptions() -> [BankAccount] { accounts.filter { $0.id != destinationID } }

    // MARK: Edição

    func appendDigit(_ d: Int) {
        guard phase == .editing else { return }
        let next = amountCents * 10 + d
        guard next <= Self.maxAmountCents else { return }
        amountCents = next
    }
    func deleteDigit() {
        guard phase == .editing else { return }
        amountCents /= 10
    }
    func swap() {
        let temp = originID
        originID = destinationID
        destinationID = temp
    }

    // MARK: Execução

    /// Executa a transferência. O 2FA (Face ID / código por e-mail) já foi confirmado pela
    /// `TwoFactorSheet` na view antes desta chamada.
    func execute() async {
        guard canSubmit, let o = origin, let d = destination else { return }

        phase = .submitting
        let description = note.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Transferência entre contas" : note

        do {
            if isLive {
                let result = try await api.executeInternalTransfer(
                    originId: o.id, destinationId: d.id, amountCents: amountCents, description: description)
                phase = .success(result.isConfirmed
                    ? "Transferência realizada com sucesso."
                    : (result.message ?? "Transferência em processamento."))
            } else {
                try? await Task.sleep(nanoseconds: 600_000_000)
                phase = .success("Transferência realizada com sucesso.")
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            phase = .failed((error as? APIError)?.userMessage ?? "Não foi possível concluir a transferência.")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    func dismissError() { if case .failed = phase { phase = .editing } }
}
