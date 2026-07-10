import SwiftUI

/// Pedido de aumento de limite: novo valor (absoluto), tipo (temporário com validade /
/// permanente) e motivo. O servidor snapshota o limite atual e recusa 2º pedido pendente.
struct LimitRequestSheet: View {
    let membership: BudgetMembership
    let budget: Budget

    @Environment(BudgetStore.self) private var budgets
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var kind: LimitRequest.Kind = .temporary
    @State private var validUntil = Date().adding(days: 30)
    @State private var reason = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private var currentLimit: Int { membership.effectiveLimit(budgetTotal: budget.totalLimit) }
    private var requestedCents: Int { WalletPaymentFlowStore.cents(from: amountText) }
    private var canSubmit: Bool {
        requestedCents > currentLimit && !reason.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Limite atual")
                        Spacer()
                        Text(currentLimit.currencyFromCents()).monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack {
                        Text("Novo limite")
                        Spacer()
                        TextField("R$ 0,00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                } footer: {
                    if requestedCents > 0 && requestedCents <= currentLimit {
                        Text("O novo limite precisa ser maior que o atual.")
                            .foregroundStyle(Theme.negative)
                    }
                }

                Section {
                    Picker("Tipo", selection: $kind) {
                        Text("Temporário").tag(LimitRequest.Kind.temporary)
                        Text("Permanente").tag(LimitRequest.Kind.permanent)
                    }
                    .pickerStyle(.segmented)
                    if kind == .temporary {
                        DatePicker("Válido até", selection: $validUntil,
                                   in: Date()..., displayedComponents: .date)
                    }
                } footer: {
                    Text(kind == .temporary
                         ? "No vencimento, seu limite volta ao valor base sozinho."
                         : "O novo valor vira seu limite base neste orçamento.")
                }

                Section("Motivo") {
                    TextField("Ex.: campanha de lançamento do trimestre",
                              text: $reason, axis: .vertical)
                        .lineLimit(3...5)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.brand(.subheadline))
                            .foregroundStyle(Theme.negative)
                    }
                }
            }
            .navigationTitle("Solicitar aumento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Enviando…" : "Enviar") { submit() }
                        .disabled(!canSubmit || isSubmitting)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                let isoDate = kind == .temporary
                    ? String(validUntil.isoString.prefix(10))
                    : nil
                _ = try await budgets.submitLimitRequest(LimitRequestDraft(
                    membershipId: membership.id,
                    requestedLimit: requestedCents,
                    kind: kind,
                    validUntil: isoDate,
                    reason: reason.trimmingCharacters(in: .whitespaces)
                ))
                ToastCenter.shared.show("Pedido enviado ao dono do orçamento")
                dismiss()
            } catch {
                errorMessage = (error as? SpendError)?.userMessage
                    ?? "Não foi possível enviar o pedido. Tente novamente."
            }
            isSubmitting = false
        }
    }
}
