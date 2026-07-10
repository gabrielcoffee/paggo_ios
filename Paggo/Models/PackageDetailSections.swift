import SwiftUI

// Per-section detail models + label maps, ported from the Expo PackageDetails components
// (summary, alerts, delivery, budget, conciliation, approvers) and utils.ts.
// No backend — these are populated by MockData. All money is in cents (Int).

// MARK: - Alerts (alerts/PaymentAlerts.tsx)

enum AlertVariant: String, Codable, Hashable, Sendable {
    case warning, error, info

    var badge: BadgeVariant {
        switch self {
        case .warning: return .warning
        case .error: return .danger
        case .info: return .info
        }
    }

    var symbol: String {
        switch self {
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "exclamationmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct PaymentAlert: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var variant: AlertVariant
    var title: String
    var description: String
}

// MARK: - Approvers (details/approvers/PaymentApproversSection.tsx)

/// Aprovador exibido nos detalhes — agrupado por `group` (Nª Liberação), com e-mail e 3 estados.
struct PaymentApproverDetail: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var group: Int
    var name: String
    var email: String
    var image: String?
    /// `true` = aprovou, `false` = rejeitou, `nil` = pendente.
    var approved: Bool?
}

// MARK: - Delivery / Origem (details/delivery/PaymentDeliverySection.tsx)

enum DeliveryType: String, Codable, Hashable, Sendable {
    case paymentRequest = "PAYMENT_REQUEST"
    case reimbursement = "REIMBURSEMENT"
    case payrollCLT = "PAYROLL_CLT"
    case payrollPJ = "PAYROLL_PJ"
    case walletPayment = "WALLET_PAYMENT"
    case paggoBilling = "PAGGO_BILLING"

    var label: String {
        switch self {
        case .paymentRequest: return "Solicitação de Pagamento"
        case .reimbursement: return "Reembolso"
        case .payrollCLT: return "Folha de Pagamento - CLT"
        case .payrollPJ: return "Folha de Pagamento - PJ"
        case .walletPayment: return "Pagamento via Carteira"
        case .paggoBilling: return "Cobrança Paggo"
        }
    }
}

struct DeliveryPerson: Codable, Hashable, Sendable {
    var name: String
    var image: String?
}

struct DeliveryInstallment: Codable, Hashable, Identifiable, Sendable {
    var number: Int
    var amount: Int       // cents
    var dueDate: String
    var status: String?
    var id: Int { number }
}

struct PaymentRequestDelivery: Codable, Hashable, Sendable {
    var documentNumber: String?
    var description: String?
    var requester: DeliveryPerson
    var installments: [DeliveryInstallment]
}

struct ReimbursementDelivery: Codable, Hashable, Sendable {
    var description: String?
    var amount: Int       // cents
    var categoryName: String?
    var user: DeliveryPerson
    var requestingForAnotherPerson: Bool
    var reimbursedUserName: String?
}

struct PayrollDelivery: Codable, Hashable, Sendable {
    var employeeName: String
    var employeeTaxId: String
    var regimen: String   // CLT / PJ / INTERN / INVESTOR
    var status: String
    var salary: Int       // cents
    var payrollMonth: String
}

struct WalletDelivery: Codable, Hashable, Sendable {
    var walletName: String
    var amount: Int       // cents
    var status: String
    var user: DeliveryPerson
    var description: String?
}

struct DeliveryDocument: Codable, Hashable, Sendable {
    var type: DeliveryType
    var paymentRequest: PaymentRequestDelivery?
    var reimbursement: ReimbursementDelivery?
    var payroll: PayrollDelivery?
    var wallet: WalletDelivery?
}

// MARK: - Budget (details/budget/PaymentBudgetSection.tsx)

struct BudgetLine: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var budgetPlanName: String
    var entityName: String
    var entityType: String     // managerialAccount / costCenter / resource
    var totalBudgetAmount: Int // cents
    var totalUsedAmount: Int   // cents
    var packageContributionAmount: Int // cents
    var remainingAmount: Int   // cents
    var percentageUsed: Double
    var isOverBudget: Bool
}

struct BudgetData: Codable, Hashable, Sendable {
    var lines: [BudgetLine]
    var hasOverBudgetLines: Bool
}

// MARK: - Conciliation (conciliation/PaymentConciliation.tsx)

struct ConciliationData: Codable, Hashable, Sendable {
    var reconciled: Bool
    var financialEntryId: String?
    var enforcePostingBeforeConciliation: Bool
    var enforceValidEntriesBeforeConciliation: Bool
}

// MARK: - Label maps (utils.ts / helpers.ts)

enum PackageTypeLabel {
    static func label(for type: PackageType?) -> String? {
        switch type {
        case .paymentRequest: return "Solicitação de Pagamento"
        case .reimbursement: return "Reembolso"
        case .payrollCLT: return "Folha CLT"
        case .payrollPJ: return "Folha PJ"
        case .walletPayment: return "Carteira Digital"
        case .none: return nil
        }
    }
}

enum PayrollLabel {
    static func regimen(_ raw: String) -> String {
        switch raw {
        case "CLT": return "Funcionário CLT"
        case "PJ": return "Prestador de Serviço - PJ"
        case "INTERN": return "Estagiário"
        case "INVESTOR": return "Sócio/Investidor"
        default: return raw
        }
    }
    static func status(_ raw: String) -> String {
        switch raw {
        case "PAID": return "Pago"
        case "SENT": return "Enviado"
        case "DRAFT": return "Rascunho"
        case "WAITING_APPROVAL": return "Aguardando Aprovação"
        case "PAYMENT_REJECTED": return "Pagamento Rejeitado"
        default: return raw
        }
    }
}

enum WalletLabel {
    static func status(_ raw: String) -> String {
        switch raw {
        case "REFUNDED": return "Reembolsado"
        case "PROCESSING": return "Em processamento"
        case "CONFIRMED": return "Confirmado"
        case "FAILED": return "Falhou"
        default: return raw
        }
    }
}

enum DocumentEntryStatusInfo {
    static func label(for status: DocumentEntry.Status) -> String {
        switch status {
        case .identified: return "Identificado"
        case .recognized: return "Reconhecido"
        case .posted: return "Escriturado"
        }
    }
    static func badge(for status: DocumentEntry.Status) -> BadgeVariant {
        switch status {
        case .posted: return .success
        case .identified: return .danger
        case .recognized: return .neutral
        }
    }
}

enum BudgetEntityLabel {
    static func label(_ raw: String) -> String {
        switch raw {
        case "managerialAccount": return "Conta Gerencial"
        case "costCenter": return "Centro de Custo"
        case "resource": return "Recurso"
        default: return raw
        }
    }
}

enum BankCodeName {
    private static let map: [String: String] = [
        "001": "Banco do Brasil", "033": "Santander", "104": "Caixa Econômica",
        "237": "Bradesco", "341": "Itaú", "260": "Nubank", "077": "Inter",
        "756": "Sicoob", "748": "Sicredi", "336": "C6 Bank", "212": "Original",
        "422": "Safra", "070": "BRB", "745": "Citibank", "399": "HSBC", "085": "Ailos",
    ]
    static func name(for code: String?) -> String? {
        guard let code else { return nil }
        return map[code] ?? code
    }
}

enum AccountTypeLabel {
    static func label(_ raw: String?) -> String? {
        switch raw {
        case "CHECKING": return "Conta Corrente"
        case "SAVINGS": return "Poupança"
        case "SALARY": return "Conta Salário"
        case "PAYMENT": return "Conta de Pagamento"
        default: return raw
        }
    }
}

// MARK: - Platform event types (history/PaymentHistory.tsx)

enum ChatEvent {
    // Toda mensagem type=EVENT vira pílula de sistema — o `appType` de um evento é seu `flag`
    // (sem flag vira "EVENT"), então o conjunto cobre TODOS os CHAT_EVENT_FLAGS + o fallback,
    // para nenhum evento cair como bolha de conversa.
    static let platformTypes: Set<String> = [
        "PACKAGE_CREATED", "SENT_FOR_APPROVAL", "APPROVED", "PAYMENT_CONFIRMED",
        "PAYMENT_FAILED", "CANCELLED", "ERP_PAYMENT_CONFIRMED", "RETURNED_TO_VALIDATION",
        "NONE", "PAYMENT_PROCESSING", "PACKAGE_AUTOMATICALLY_UPDATED", "ERP_DATA_UPDATE",
        "COUNTERPARTY_NOTIFIED", "EVENT",
    ]
    static let success: Set<String> = ["PAYMENT_CONFIRMED", "APPROVED", "ERP_PAYMENT_CONFIRMED"]
    static let danger: Set<String> = ["PAYMENT_FAILED", "CANCELLED"]

    static func isPlatform(_ type: String) -> Bool { platformTypes.contains(type) }
}
