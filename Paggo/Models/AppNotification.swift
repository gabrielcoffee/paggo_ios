import Foundation

// Contrato do doc 05 (notifications.json). Só o servidor cria; título/corpo chegam prontos
// em pt-BR (fonte única de texto). `payload` carrega o necessário pro deep-link.

/// Notificação in-app do funcionário/admin.
struct AppNotification: Codable, Hashable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable {
        case budgetThreshold = "budget_threshold"
        case budgetExpiring = "budget_expiring"
        case budgetExpired = "budget_expired"
        case limitRequestSubmitted = "limit_request_submitted"
        case limitRequestDecided = "limit_request_decided"
        case cardTransaction = "card_transaction"
        case cardDeclined = "card_declined"
        case receiptPending = "receipt_pending"
        case reimbursementSubmitted = "reimbursement_submitted"
        case reimbursementDecided = "reimbursement_decided"
        case reimbursementPaid = "reimbursement_paid"

        var symbol: String {
            switch self {
            case .budgetThreshold, .budgetExpiring, .budgetExpired: return "chart.bar"
            case .limitRequestSubmitted, .limitRequestDecided: return "arrow.up.circle"
            case .cardTransaction: return "creditcard"
            case .cardDeclined: return "creditcard.trianglebadge.exclamationmark"
            case .receiptPending: return "doc.text.magnifyingglass"
            case .reimbursementSubmitted, .reimbursementDecided, .reimbursementPaid:
                return "arrow.uturn.backward.circle"
            }
        }
    }

    /// Campos possíveis do payload de deep-link (subconjunto por tipo).
    struct Payload: Codable, Hashable, Sendable {
        var budgetId: String?
        var membershipId: String?
        var threshold: Int?
        var cardId: String?
        var transactionId: String?
        var requestId: String?
        var reimbursementId: String?
    }

    struct Recipient: Codable, Hashable, Sendable { var id: String }

    let id: String
    var recipient: Recipient
    var type: Kind
    var payload: Payload?
    var title: String
    var body: String
    var readAt: String?
    var createdAt: String

    var isUnread: Bool { readAt == nil }
}
