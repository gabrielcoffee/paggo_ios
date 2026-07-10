import Foundation

// Contratos do doc 02 (cards.json, card-reveals.json, RPC revealCard).
// PAN/CVV nunca aparecem no wire de listagem — só na resposta do reveal.

/// Cartão corporativo virtual, pré-pago: lastreado numa carteira, pendurado num membership.
struct CorporateCard: Codable, Hashable, Sendable, Identifiable {
    enum Status: String, Codable, Sendable { case active, frozen, locked, canceled }

    let id: String
    var membershipId: String
    var budget: EntityRef
    var wallet: EntityRef             // conta lastro que financia (doc 02 regra 1)
    var holder: PersonRef
    var type: String
    var brand: String
    var last4: String
    var expMonth: Int
    var expYear: Int
    var status: Status
    var lockedBy: PersonRef?          // admin, ou { id: "system" } nos locks automáticos
    var createdAt: String
    var updatedAt: String

    var statusLabel: String {
        switch status {
        case .active: return "Ativo"
        case .frozen: return "Congelado"
        case .locked: return "Bloqueado"
        case .canceled: return "Cancelado"
        }
    }

    /// Motivo exibível de um lock (doc 02 regra 3): admin nomeado ou automático.
    var lockDescription: String? {
        guard status == .locked else { return nil }
        guard let who = lockedBy else { return "Bloqueado" }
        return who.isSystem ? "Bloqueado automaticamente" : "Bloqueado por \(who.name)"
    }

    var expiryLabel: String { String(format: "%02d/%d", expMonth, expYear % 100) }
}

/// Resposta da RPC `revealCard` — o app exibe e descarta; nunca persiste nem loga.
struct RevealedCardDetails: Codable, Sendable {
    let cardId: String
    let pan: String
    let cvv: String
    let expMonth: Int
    let expYear: Int

    var groupedPan: String {
        stride(from: 0, to: pan.count, by: 4).map { offset in
            let start = pan.index(pan.startIndex, offsetBy: offset)
            let end = pan.index(start, offsetBy: min(4, pan.count - offset))
            return String(pan[start..<end])
        }.joined(separator: " ")
    }
}
