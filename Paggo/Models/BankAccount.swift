import Foundation

// Ported from apps/paggo-mobile-app/src/domain/entities/bank-account.entity.ts
// All monetary values are in **cents** (Int).

enum BankAccountType: String, Codable, Sendable {
    case checking = "CHECKING"
    case savings = "SAVINGS"
    case payment = "PAYMENT"

    var label: String {
        switch self {
        case .checking: return "Conta corrente"
        case .savings: return "Poupança"
        case .payment: return "Conta pagamento"
        }
    }
}

/// Informações do banco.
struct BankInfo: Codable, Hashable, Sendable {
    var code: String
    var name: String
    var shortName: String
    var iconUrl: String?
}

/// Conta bancária.
struct BankAccount: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var bankCode: String
    var bankCodeStr: String
    var branchCode: String
    var accountNumber: String
    var accountDigit: String?
    var accountType: BankAccountType
    var name: String            // nome definido pelo usuário
    var taxId: String
    var pixKey: String?
    var isExternal: Bool
    var organizationId: String
    var organizationName: String?
    var balance: Int            // cents
    var availableBalance: Int?  // cents
    var predictedExpenses: Int? // cents
    var bank: BankInfo

    /// "Ag 1234 • Cc 567890-1"
    var accountLabel: String {
        let digit = accountDigit.map { "-\($0)" } ?? ""
        return "Ag \(branchCode) • Cc \(accountNumber)\(digit)"
    }

    /// Número da conta com dígito: "567890-1".
    var accountNumberDisplay: String {
        let digit = accountDigit.map { "-\($0)" } ?? ""
        return "\(accountNumber)\(digit)"
    }
}

/// Resumo de movimentações previstas no período.
struct MovementsSummary: Codable, Sendable {
    struct Period: Codable, Sendable { var start: String; var end: String }
    struct Flow: Codable, Sendable { var total: Int; var count: Int }  // total in cents
    var period: Period
    var income: Flow
    var expense: Flow
}

/// Resposta de listagem de contas.
struct BankAccountListResponse: Codable, Sendable {
    var data: [BankAccount]
    var total: Int
    var totalBalance: Int       // cents
    var movements: MovementsSummary
}

// MARK: - Bank transactions

enum BankTransactionType: String, Codable, Sendable {
    case credit = "CREDIT"
    case debit = "DEBIT"
}

enum BankTransactionCategory: String, Codable, Sendable {
    case transferIn = "TRANSFER_IN"
    case transferOut = "TRANSFER_OUT"
    case pixIn = "PIX_IN"
    case pixOut = "PIX_OUT"
    case tedIn = "TED_IN"
    case tedOut = "TED_OUT"
    case deposit = "DEPOSIT"
    case withdrawal = "WITHDRAWAL"
    case payment = "PAYMENT"
    case refund = "REFUND"
    case fee = "FEE"
    case other = "OTHER"

    var symbol: String {
        switch self {
        case .transferIn, .tedIn, .deposit: return "arrow.down.left"
        case .transferOut, .tedOut, .withdrawal, .payment: return "arrow.up.right"
        case .pixIn: return "arrow.down.left.circle"
        case .pixOut: return "arrow.up.right.circle"
        case .refund: return "arrow.uturn.backward"
        case .fee: return "percent"
        case .other: return "circle.dotted"
        }
    }
}

/// Transação bancária.
struct BankTransaction: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var accountId: String
    var type: BankTransactionType
    var category: BankTransactionCategory
    var amount: Int             // cents
    var balanceAfter: Int?      // cents — null quando a API não expõe o saldo pós-transação
    var description: String
    var counterpartyName: String?
    var counterpartyTaxId: String?
    var date: String

    var isCredit: Bool { type == .credit }
}

/// Ponto de dados do histórico de saldo.
struct BalanceHistoryPoint: Codable, Identifiable, Hashable, Sendable {
    var date: String
    var balance: Int            // cents
    var id: String { date }
    var dateValue: Date { DateText.parse(date) ?? Date() }
}

extension MovementsSummary {
    static let zero = MovementsSummary(
        period: .init(start: "", end: ""),
        income: .init(total: 0, count: 0),
        expense: .init(total: 0, count: 0)
    )
}

extension BankAccountListResponse {
    static let empty = BankAccountListResponse(data: [], total: 0, totalBalance: 0, movements: .zero)
}
