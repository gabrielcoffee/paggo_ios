import Foundation

// Ported from packages.mock.ts (TabsEnum, TAB_STATUS_MAP, TAB_CONFIG) and constants/index.ts.

/// Tabs do Payout, na ordem de exibição.
enum PackageTab: String, CaseIterable, Identifiable, Sendable {
    case provisioned = "PROVISIONED"
    case pending = "PENDING"
    case validation = "VALIDATION"
    case approval = "APPROVAL"
    case scheduled = "SCHEDULED"
    case paid = "PAID"

    var id: String { rawValue }

    /// Rótulo exibido na barra de tabs.
    var title: String {
        switch self {
        case .provisioned: return "Previstos"
        case .pending: return "Pendentes"
        case .validation: return "Validação"
        case .approval: return "Liberação"
        case .scheduled: return "Agendados"
        case .paid: return "Pagos"
        }
    }

    /// Status que pertencem a esta tab.
    var statuses: [PackageStatus] {
        switch self {
        case .provisioned: return [.provisioned, .reserve]
        case .pending: return [.paymentFailed, .pendingBankInfo, .refunded]
        case .validation: return [.readyForApproval]
        case .approval: return [.waitingApproval]
        case .scheduled: return [.approved, .paymentFailedReview, .processing]
        case .paid: return [.paid]
        }
    }

    /// Lê a contagem/total correspondente em `PackageTotals`.
    func bucket(in totals: PackageTotals) -> PackageTotals.Bucket? {
        totals[keyPath: bucketKeyPath]
    }

    /// KeyPath gravável para o bucket da tab (permite ajuste otimista após ações em massa).
    var bucketKeyPath: WritableKeyPath<PackageTotals, PackageTotals.Bucket?> {
        switch self {
        case .provisioned: return \.previstos
        case .pending: return \.pendencias
        case .validation: return \.validacao
        case .approval: return \.liberacao
        case .scheduled: return \.agendados
        case .paid: return \.pagos
        }
    }

    /// Ações em massa disponíveis para a tab.
    var bulkAction: BulkAction? {
        switch self {
        case .validation: return .sendToApproval
        case .approval: return .approve
        default: return nil
        }
    }
}

/// Ações em massa de pagamentos.
enum BulkAction: Sendable {
    case sendToApproval   // Validação → Liberação
    case approve          // Liberação → Agendado (+ possibilidade de retornar)

    var primaryLabel: String {
        switch self {
        case .sendToApproval: return "Enviar para liberação"
        case .approve: return "Liberar"
        }
    }
}
