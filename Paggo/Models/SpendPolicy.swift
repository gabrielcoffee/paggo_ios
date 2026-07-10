import Foundation

// Contrato do doc 04 (policies.json). Policy de budget sobrepõe o global campo a campo;
// campo null herda. `enabled: false` desliga o policy inteiro (herda global).

/// Regras de gasto configuradas pelo admin, aplicadas nos instrumentos.
struct SpendPolicy: Codable, Hashable, Sendable, Identifiable {
    struct Scope: Codable, Hashable, Sendable {
        var type: String              // global | budget
        var budgetId: String?
    }

    let id: String
    var scope: Scope
    var blockedCategories: [MerchantCategory]?
    var maxPerTransaction: Int?
    var receiptRequiredAbove: Int?
    var autoApproveBelow: Int?
    var enabled: Bool
    var updatedBy: PersonRef
    var createdAt: String
    var updatedAt: String

    var isGlobal: Bool { scope.type == "global" }
}

/// Policy efetivo após herança campo a campo (doc 04 regra 1) — o que os instrumentos aplicam
/// e o que o funcionário lê na seção "O que a política exige".
struct ResolvedPolicy: Sendable, Hashable {
    var blockedCategories: [MerchantCategory]
    var maxPerTransaction: Int?
    var receiptRequiredAbove: Int?
    var autoApproveBelow: Int?

    static func resolve(global: SpendPolicy?, budget: SpendPolicy?) -> ResolvedPolicy {
        let g = (global?.enabled == true) ? global : nil
        let b = (budget?.enabled == true) ? budget : nil
        return ResolvedPolicy(
            blockedCategories: b?.blockedCategories ?? g?.blockedCategories ?? [],
            maxPerTransaction: b?.maxPerTransaction ?? g?.maxPerTransaction,
            receiptRequiredAbove: b?.receiptRequiredAbove ?? g?.receiptRequiredAbove,
            autoApproveBelow: b?.autoApproveBelow ?? g?.autoApproveBelow
        )
    }

    func blocks(_ category: MerchantCategory) -> Bool { blockedCategories.contains(category) }

    func exceedsMax(_ amount: Int) -> Bool {
        guard let max = maxPerTransaction else { return false }
        return amount > max
    }

    func requiresReceipt(for amount: Int) -> Bool {
        guard let threshold = receiptRequiredAbove else { return true }
        return amount >= threshold
    }

    func autoApproves(amount: Int, hasFlags: Bool, hasReceipt: Bool) -> Bool {
        guard let below = autoApproveBelow else { return false }
        return amount < below && !hasFlags && hasReceipt
    }
}
