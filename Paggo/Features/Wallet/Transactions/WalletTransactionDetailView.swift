import SwiftUI
import UIKit

/// Detalhe de uma transação da carteira — espelha o comprovante do apps/wallet-pwa
/// (Recebedor / Pagador / Detalhes da Transação + IDs). Permite compartilhar o comprovante em PDF.
struct WalletTransactionDetailView: View {
    let payment: WalletPayment
    @Environment(WalletStore.self) private var wallet

    @State private var shareURL: URL?
    @State private var copiedField: String?
    @State private var detail: WalletPaymentDetail?
    @State private var infoStore: WalletPaymentDetailStore?

    private var receipt: WalletReceipt { detail?.receipt ?? WalletReceipt() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                hero
                if detail == nil {
                    DetailSectionSkeleton()
                } else {
                    receiverSection
                    payerSection
                    transactionSection
                    if payment.method == .barcode { boletoSection }
                }
                // Enriquecimento (descrição/anexos/alocações) só para pagamento efetivado.
                if payment.status == .confirmed, let infoStore {
                    WalletPaymentInfoSections(store: infoStore)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xxxl)
        }
        .task {
            detail = try? await wallet.detail(for: payment)
            if infoStore == nil, payment.status == .confirmed, let walletId = wallet.currentWallet?.id {
                infoStore = WalletPaymentDetailStore(payment: payment, walletId: walletId)
            }
        }
        // Salvamentos mudam pendências — recarrega o extrato ao sair para o badge refletir (RN-21).
        .onDisappear { Task { await wallet.refreshCurrentPayments() } }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .screenBackground()
        .navigationTitle("Comprovante")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { share() } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(payment.status == .failed || detail == nil)
            }
        }
        .sheet(item: $shareURL) { url in
            ShareSheet(items: [url]).presentationDetents([.medium, .large])
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DetailBadge(label: payment.status.label, variant: payment.status.badgeVariant)
            VStack(alignment: .leading, spacing: 0) {
                Text("VALOR")
                    .font(.brand(.caption2, weight: .medium)).tracking(1)
                    .foregroundStyle(Theme.textTertiary)
                Text(payment.amount.currencyFromCents())
                    .font(.heroNumber).monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            HStack(spacing: Spacing.sm) {
                TintedIcon(symbol: payment.method.icon, tint: Theme.accent, size: 26, symbolSize: 12)
                Text(payment.method.label)
                    .font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(DateText.full(payment.createdAt))
                    .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    // MARK: Parties

    private var receiverSection: some View {
        DetailSection("Recebedor", systemImage: "arrow.down.left.circle") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                DetailInfoField(caption: "Nome", value: receipt.creditName)
                DetailInfoField(caption: "CPF/CNPJ", value: receipt.creditTaxId)
                HStack(alignment: .top, spacing: Spacing.xl) {
                    DetailInfoField(caption: "Agência", value: receipt.creditBranch)
                    DetailInfoField(caption: "Conta", value: receipt.creditAccount)
                }
                DetailInfoField(caption: "Instituição", value: receipt.creditBankName)
            }
        }
    }

    private var payerSection: some View {
        DetailSection("Pagador", systemImage: "arrow.up.right.circle") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                DetailInfoField(caption: "Nome", value: receipt.debitName)
                DetailInfoField(caption: "CPF/CNPJ", value: receipt.debitTaxId)
                HStack(alignment: .top, spacing: Spacing.xl) {
                    DetailInfoField(caption: "Agência", value: receipt.debitBranch)
                    DetailInfoField(caption: "Conta", value: receipt.debitAccount)
                }
                DetailInfoField(caption: "Instituição", value: receipt.debitBankName)
            }
        }
    }

    // MARK: Transaction details

    private var transactionSection: some View {
        DetailSection("Detalhes da transação", systemImage: "doc.text.magnifyingglass") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let e2e = receipt.endToEndId {
                    copyableField(caption: "ID da transação (E2E)", value: e2e)
                }
                if let line = receipt.digitableLine {
                    copyableField(caption: "Linha digitável", value: line)
                }
                if let auth = receipt.authenticationData {
                    copyableField(caption: "Autenticação", value: auth)
                }
            }
        }
    }

    private var boletoSection: some View {
        DetailSection("Boleto", systemImage: "barcode") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                DetailInfoField(caption: "Beneficiário", value: receipt.assignor)
                HStack(alignment: .top, spacing: Spacing.xl) {
                    DetailInfoField(caption: "Valor original",
                                    value: receipt.originalAmount?.currencyFromCents())
                    DetailInfoField(caption: "Vencimento", value: receipt.dueDate.map(DateText.full))
                }
                HStack(alignment: .top, spacing: Spacing.xl) {
                    DetailInfoField(caption: "Multa", value: receipt.fineAmount?.currencyFromCents())
                    DetailInfoField(caption: "Juros", value: receipt.interestAmount?.currencyFromCents())
                    DetailInfoField(caption: "Desconto", value: receipt.discountAmount?.currencyFromCents())
                }
            }
        }
    }

    // MARK: Copyable IDs

    private func copyableField(caption: String, value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            withAnimation { copiedField = caption }
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                await MainActor.run { withAnimation { if copiedField == caption { copiedField = nil } } }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.sm) {
                    Text(caption.uppercased())
                        .font(.brand(.caption2, weight: .medium)).tracking(0.6)
                        .foregroundStyle(Theme.textTertiary)
                    Image(systemName: copiedField == caption ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(copiedField == caption ? Theme.positive : Theme.textTertiary)
                    Spacer()
                }
                Text(value)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func share() {
        guard let detail else { return }
        shareURL = ReceiptPDF.make(for: detail)
    }
}

// Permite usar `.sheet(item:)` com uma URL como identidade.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
