import SwiftUI

/// Fluxo de transferência entre contas: seleciona origem e destino, define o valor e confirma
/// (Face ID). Espelha o SimpleTransfer "entre contas do Grupo" do web, com estética de teclado
/// numérico grande (referência Revolut).
struct TransferView: View {
    let accounts: [BankAccount]
    var onSuccess: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var auth
    @State private var store: TransferStore
    @State private var picking: PickTarget?
    @State private var showTwoFactor = false

    private enum PickTarget: Identifiable { case origin, destination; var id: Int { hashValue } }

    init(accounts: [BankAccount], onSuccess: @escaping () -> Void = {}) {
        self.accounts = accounts
        self.onSuccess = onSuccess
        _store = State(initialValue: TransferStore(accounts: accounts))
    }

    var body: some View {
        SheetScaffold(title: "Transferir", closePlacement: .topBarLeading) {
            Group {
                if case let .success(message) = store.phase {
                    successState(message)
                } else {
                    editor
                }
            }
            .sheet(item: $picking) { target in
                AccountPickerSheet(
                    title: target == .origin ? "Conta de origem" : "Conta de destino",
                    accounts: target == .origin ? store.originOptions() : store.destinationOptions(),
                    selectedID: target == .origin ? store.originID : store.destinationID,
                    onSelect: { account in
                        if target == .origin { store.originID = account.id } else { store.destinationID = account.id }
                    }
                )
            }
        }
    }

    // MARK: Editor

    private var editor: some View {
        VStack(spacing: Spacing.lg) {
            accountsBlock

            Spacer(minLength: Spacing.md)

            VStack(spacing: Spacing.sm) {
                Text("Valor")
                    .font(.brand(.caption, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                Text(store.amountCents.currencyFromCents())
                    .font(.brand(size: 46, weight: .light))
                    .foregroundStyle(store.amountCents == 0 ? Theme.textTertiary : Theme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: store.amountCents)
                if let error = store.errorText {
                    Text(error)
                        .font(.brand(.caption, weight: .medium))
                        .foregroundStyle(Theme.negative)
                        .multilineTextAlignment(.center)
                } else if let origin = store.origin {
                    Text("Saldo disponível: \(origin.balance.currencyFromCents())")
                        .font(.brand(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer(minLength: Spacing.md)

            Button { if store.canSubmit { showTwoFactor = true } } label: {
                HStack(spacing: Spacing.sm) {
                    if store.isSubmitting { ProgressView().tint(.white) }
                    Text(store.isSubmitting ? "Transferindo…" : "Transferir")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(!store.canSubmit)
            .opacity(store.canSubmit ? 1 : 0.5)

            numpad
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.lg)
        .sheet(isPresented: $showTwoFactor) {
            TwoFactorSheet(
                title: "Confirmar transferência",
                reason: "Confirme a transferência de \(store.amountCents.currencyFromCents())",
                email: auth.activeUser?.email ?? auth.savedUser?.email ?? "",
                onVerified: { Task { await store.execute() } },
                onCancel: {}
            )
            .presentationDetents([.height(480), .large])
            .presentationBackground(.ultraThinMaterial)
        }
        .alert("Transferência não concluída", isPresented: failedBinding) {
            Button("OK", role: .cancel) { store.dismissError() }
        } message: {
            if case let .failed(message) = store.phase { Text(message) }
        }
    }

    private var accountsBlock: some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.separator)
            accountCard(label: "De", account: store.origin, placeholder: "Escolher conta de origem") {
                picking = .origin
            }
            ZStack {
                Divider().overlay(Theme.separator)
                Button { store.swap() } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 38, height: 38)
                        .background(Theme.surface, in: Circle())
                        .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            accountCard(label: "Para", account: store.destination, placeholder: "Escolher conta de destino") {
                picking = .destination
            }
            Divider().overlay(Theme.separator)
        }
    }

    private func accountCard(label: String, account: BankAccount?, placeholder: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                if let account {
                    BankBadge(account: account, size: 38)
                } else {
                    AccountAvatar(name: "")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.brand(.caption2, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                    Text(account?.name ?? placeholder)
                        .font(.brand(.subheadline, weight: .medium))
                        .foregroundStyle(account == nil ? Theme.textTertiary : Theme.textPrimary)
                    if let account {
                        Text("\(account.accountLabel) • \(account.balance.currencyFromCents())")
                            .font(.brand(.caption))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Numpad

    private var numpad: some View {
        let keys: [NumKey] = [
            .digit(1), .digit(2), .digit(3),
            .digit(4), .digit(5), .digit(6),
            .digit(7), .digit(8), .digit(9),
            .blank, .digit(0), .backspace,
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3),
                         spacing: Spacing.sm) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                numKeyView(key)
            }
        }
    }

    private enum NumKey { case digit(Int), backspace, blank }

    @ViewBuilder private func numKeyView(_ key: NumKey) -> some View {
        switch key {
        case .blank:
            Color.clear.frame(height: 56)
        case .digit(let d):
            Button { store.appendDigit(d) } label: {
                Text("\(d)")
                    .font(.brand(size: 24, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .backspace:
            Button { store.deleteDigit() } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Success

    private func successState(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.positive)
            Text(message)
                .font(.brand(.title3, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            if let o = store.origin, let d = store.destination {
                Text("\(store.amountCents.currencyFromCents()) • \(o.name) → \(d.name)")
                    .font(.brand(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button { onSuccess(); dismiss() } label: { Text("Concluir").frame(maxWidth: .infinity) }
                .buttonStyle(PrimaryActionStyle())
        }
        .padding(Spacing.xl)
    }

    private var failedBinding: Binding<Bool> {
        Binding(get: { if case .failed = store.phase { return true } else { return false } },
                set: { if !$0 { store.dismissError() } })
    }
}
