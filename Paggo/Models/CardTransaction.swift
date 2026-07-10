import Foundation

// Contrato do doc 02 (card-transactions.json). Débito no auth: authorized soma no
// membership e debita a carteira; settle ajusta a diferença nos dois.

/// Transação do cartão corporativo (feed auth → settle).
struct CardTransaction: Codable, Hashable, Sendable, Identifiable {
    enum Status: String, Codable, Sendable { case authorized, settled, reversed, declined }

    /// Motivos de recusa, na ordem de avaliação do doc 02 regra 5.
    enum DeclineReason: String, Codable, Sendable {
        case cardFrozen = "card_frozen"
        case cardLocked = "card_locked"
        case categoryBlocked = "category_blocked"
        case policyMaxAmount = "policy_max_amount"
        case insufficientFunds = "insufficient_funds"
        case limitExceeded = "limit_exceeded"
        case budgetExpired = "budget_expired"

        var label: String {
            switch self {
            case .cardFrozen: return "Cartão congelado"
            case .cardLocked: return "Cartão bloqueado"
            case .categoryBlocked: return "Categoria bloqueada pela política"
            case .policyMaxAmount: return "Acima do teto por transação"
            case .insufficientFunds: return "Carteira sem disponível"
            case .limitExceeded: return "Limite do orçamento excedido"
            case .budgetExpired: return "Orçamento expirado"
            }
        }
    }

    struct Merchant: Codable, Hashable, Sendable {
        var name: String
        var category: MerchantCategory
        var city: String?
        var country: String?
    }

    enum ReceiptStatus: String, Codable, Sendable { case missing, attached }

    let id: String
    var cardId: String
    var membershipId: String
    var budget: EntityRef
    var holder: PersonRef
    var merchant: Merchant
    var amount: Int                   // autorização
    var settledAmount: Int?           // preenchido no settle; pode diferir
    var currency: String
    var status: Status
    var declineReason: DeclineReason?
    var authorizedAt: String
    var settledAt: String?
    var receiptStatus: ReceiptStatus
    var createdAt: String
    var updatedAt: String

    /// Valor que conta: liquidado quando existe, senão o autorizado.
    var effectiveAmount: Int { settledAmount ?? amount }

    var statusLabel: String {
        switch status {
        case .authorized: return "Autorizada"
        case .settled: return "Liquidada"
        case .reversed: return "Estornada"
        case .declined: return declineReason?.label ?? "Recusada"
        }
    }

    var countsAsSpend: Bool { status == .authorized || status == .settled }
}
