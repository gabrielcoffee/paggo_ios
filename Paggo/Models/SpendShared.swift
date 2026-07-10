import SwiftUI

// Tipos compartilhados das features de spend management (docs/specs/00-overview.md):
// dinheiro em cents (Int), datas ISO-8601 em String, pessoas/entidades denormalizadas.

/// Mini-objeto de pessoa denormalizado no wire: `{ id, name, email? }`.
struct PersonRef: Codable, Hashable, Sendable {
    var id: String
    var name: String
    var email: String?

    /// Decisões automáticas usam `{ id: "system" }` (doc 04).
    var isSystem: Bool { id == "system" }
}

/// Mini-objeto de entidade exibível em lista: `{ id, name }`.
struct EntityRef: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
}

/// Categorias de estabelecimento compartilhadas (doc 00). Pix/boleto não trazem MCC —
/// categoria é escolhida pelo pagador (default `other`); cartão traz da rede.
enum MerchantCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case materials, food, transport, lodging, fuel, services, software, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .materials: return "Materiais"
        case .food: return "Alimentação"
        case .transport: return "Transporte"
        case .lodging: return "Hospedagem"
        case .fuel: return "Combustível"
        case .services: return "Serviços"
        case .software: return "Software"
        case .other: return "Outros"
        }
    }

    var symbol: String {
        switch self {
        case .materials: return "shippingbox"
        case .food: return "fork.knife"
        case .transport: return "car"
        case .lodging: return "bed.double"
        case .fuel: return "fuelpump"
        case .services: return "wrench.and.screwdriver"
        case .software: return "laptopcomputer"
        case .other: return "tag"
        }
    }
}

/// Chave Pix de payout do funcionário (doc 03): snapshotada no reembolso.
struct PayoutKey: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable { case cpf, phone, email, evp }
    var type: Kind
    var value: String
}
