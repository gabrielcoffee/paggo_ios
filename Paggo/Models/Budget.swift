import Foundation

// Contratos do doc 01 (budgets.json). Dinheiro em cents; datas ISO em String.

/// Orçamento por time/projeto/período. O consumo do período atual NÃO existe no wire —
/// é a soma dos `consumed` dos memberships (fonte de verdade única).
struct Budget: Codable, Hashable, Sendable, Identifiable {
    enum Status: String, Codable, Sendable { case active, expired, archived }

    struct Period: Codable, Hashable, Sendable {
        enum Kind: String, Codable, Sendable { case monthly, quarterly, oneTime }
        var type: Kind
        var startDate: String
        var endDate: String?          // obrigatório se oneTime
        var autoRenew: Bool
    }

    struct PeriodSummary: Codable, Hashable, Sendable {
        var period: String            // "2026-06"
        var consumed: Int
    }

    let id: String
    var name: String
    var description: String?
    var ownerId: String
    var period: Period
    var totalLimit: Int
    var currency: String
    var status: Status
    var periodSummaries: [PeriodSummary]
    var createdAt: String
    var updatedAt: String

    var isActive: Bool { status == .active }

    var periodLabel: String {
        switch period.type {
        case .monthly: return "Mensal"
        case .quarterly: return "Trimestral"
        case .oneTime: return period.endDate.map { "Até \(DateText.full($0))" } ?? "Único"
        }
    }
}
