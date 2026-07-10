import Foundation

// Contrato do doc 01 (limit-requests.json). Máx. 1 pendente por membership;
// `currentLimit` é snapshot do momento do pedido (auditoria).

/// Pedido de aumento de limite do membership; o owner do budget decide.
struct LimitRequest: Codable, Hashable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable { case temporary, permanent }
    enum Status: String, Codable, Sendable { case submitted, approved, rejected }

    let id: String
    var membershipId: String
    var budgetId: String
    var requestedBy: PersonRef
    var currentLimit: Int
    var requestedLimit: Int
    var kind: Kind
    var validUntil: String?           // só temporary
    var reason: String
    var status: Status
    var decidedBy: PersonRef?
    var decidedAt: String?
    var decisionNote: String?
    var createdAt: String

    var isPending: Bool { status == .submitted }

    var kindLabel: String { kind == .temporary ? "Temporário" : "Permanente" }

    var statusLabel: String {
        switch status {
        case .submitted: return "Enviado"
        case .approved: return "Aprovado"
        case .rejected: return "Recusado"
        }
    }
}

/// Payload de criação do pedido (POST).
struct LimitRequestDraft: Sendable {
    var membershipId: String
    var requestedLimit: Int
    var kind: LimitRequest.Kind
    var validUntil: String?
    var reason: String
}
