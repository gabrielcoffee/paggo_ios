import Foundation

// Contrato do doc 03 (reimbursements.json). Consome o budget na APROVAÇÃO; aprovado vira
// package REIMBURSEMENT na esteira; `packageId` do wire é derivado (packages.reimbursementId).

/// Despesa do próprio bolso do funcionário, devolvida via Pix na chave do perfil.
struct Reimbursement: Codable, Hashable, Sendable, Identifiable {
    enum Status: String, Codable, Sendable { case submitted, approved, paid, rejected, canceled }

    struct Receipt: Codable, Hashable, Sendable {
        var status: String            // attached
        var url: String
    }

    let id: String
    var requester: PersonRef
    var budget: EntityRef?            // opcional (doc 01 regra 10)
    var packageId: String?            // wire: derivado; preenchido na aprovação
    var merchantCategory: MerchantCategory
    var description: String
    var amount: Int
    var currency: String
    var expenseDate: String           // ISO date
    var receipt: Receipt?
    var status: Status
    var policyFlags: [String]?        // doc 04: over_max_amount | blocked_category
    var estimatedPaymentDate: String? // aprovação + 2 corridos (expectativa exibida)
    var paidAt: String?
    var payoutKey: PayoutKey
    var decidedBy: PersonRef?
    var decidedAt: String?
    var decisionNote: String?
    var createdAt: String
    var updatedAt: String

    var statusLabel: String {
        switch status {
        case .submitted: return "Enviado"
        case .approved: return "Aprovado"
        case .paid: return "Pago"
        case .rejected: return "Recusado"
        case .canceled: return "Cancelado"
        }
    }

    var canCancel: Bool { status == .submitted }
    var wasAutoApproved: Bool { decidedBy?.isSystem == true }
}

/// Payload de submissão (POST).
struct ReimbursementDraft: Sendable {
    var amount: Int
    var expenseDate: String
    var merchantCategory: MerchantCategory
    var budgetId: String?
    var description: String
    var receiptURL: String?           // obrigatório salvo relaxamento por policy (doc 04 regra 4)
}
