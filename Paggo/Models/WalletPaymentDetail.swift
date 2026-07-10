import Foundation

/// Comprovante (recibo) de um pagamento da carteira — espelha WalletReceipt do apps/wallet-pwa.
/// Valores em cents.
struct WalletReceipt: Hashable, Sendable, Codable {
    var endToEndId: String?
    var digitableLine: String?
    var authenticationData: String?
    var dueDate: String?
    var fineAmount: Int?
    var interestAmount: Int?
    var discountAmount: Int?
    var originalAmount: Int?
    var assignor: String?

    // Pagador (débito)
    var debitName: String?
    var debitTaxId: String?
    var debitBankName: String?
    var debitBranch: String?
    var debitAccount: String?

    // Recebedor (crédito)
    var creditName: String?
    var creditTaxId: String?
    var creditBankName: String?
    var creditBranch: String?
    var creditAccount: String?
}

/// Detalhe completo de um pagamento da carteira (base + comprovante).
struct WalletPaymentDetail: Identifiable, Hashable, Sendable, Codable {
    var payment: WalletPayment
    var receipt: WalletReceipt

    var id: String { payment.id }
}
