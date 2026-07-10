import Foundation

// Contrato do doc 01 (budget-memberships.json). O `consumed` daqui é a única fonte de
// verdade do gasto — o consumo do budget é a soma dos memberships.

/// Vínculo funcionário ↔ orçamento. Funcionário em 2 orçamentos = 2 registros.
struct BudgetMembership: Codable, Hashable, Sendable, Identifiable {
    enum Status: String, Codable, Sendable { case active, suspended }

    /// Aumento temporário ativo (doc 01 regra 8); removido pelo job quando vence.
    struct TemporaryLimit: Codable, Hashable, Sendable {
        var limit: Int
        var validUntil: String        // ISO date
        var requestId: String
    }

    let id: String
    var budgetId: String
    var employee: PersonRef
    var memberLimit: Int?             // null = até o total do orçamento
    var temporaryLimit: TemporaryLimit?
    var consumed: Int
    var status: Status
    var createdAt: String
    var updatedAt: String

    /// Aumento temporário vale enquanto hoje ≤ validUntil (datas ISO comparam lexicograficamente).
    func temporaryLimitActive(today: String = DateText.todayISO) -> Bool {
        guard let temp = temporaryLimit else { return false }
        return today <= temp.validUntil
    }

    /// Limite efetivo (doc 01 regra 2): temporário ativo > base > teto do orçamento.
    func effectiveLimit(budgetTotal: Int, today: String = DateText.todayISO) -> Int {
        if let temp = temporaryLimit, today <= temp.validUntil { return temp.limit }
        return memberLimit ?? budgetTotal
    }

    func remaining(budgetTotal: Int, today: String = DateText.todayISO) -> Int {
        max(0, effectiveLimit(budgetTotal: budgetTotal, today: today) - consumed)
    }

    /// Fração consumida do limite efetivo (0...1), pra barras 75/90%.
    func usedFraction(budgetTotal: Int, today: String = DateText.todayISO) -> Double {
        let limit = effectiveLimit(budgetTotal: budgetTotal, today: today)
        guard limit > 0 else { return 0 }
        return min(1, Double(consumed) / Double(limit))
    }
}
