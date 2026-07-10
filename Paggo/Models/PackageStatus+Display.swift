import SwiftUI

// Status display labels and tones — from PACKAGE_STATUS_DISPLAY (packages.mock.ts) and
// PACKAGE_STATUS_LABELS (constants/index.ts).

extension PackageStatus {
    /// Variante de badge (espelha PACKAGE_STATUS_BADGE_SEMANTIC do utils.ts).
    var badgeVariant: BadgeVariant {
        switch self {
        case .paid: return .success
        case .approved, .waitingApproval, .readyForApproval, .processing, .paymentFailedReview:
            return .info
        case .pendingBankInfo, .refunded: return .warning
        case .cancelled: return .danger
        case .paymentFailed: return .danger
        case .reserve, .provisioned, .notPayable: return .neutral
        }
    }

    /// Rótulo de exibição do status individual.
    var displayLabel: String {
        switch self {
        case .paid: return "Pago"
        case .approved: return "Agendado"
        case .waitingApproval: return "Em Liberação"
        case .readyForApproval: return "Em Validação"
        case .pendingBankInfo: return "Pendente"
        case .cancelled, .notPayable: return "Cancelado"
        case .paymentFailed: return "Falho"
        case .paymentFailedReview: return "Processando"
        case .refunded: return "Estornado"
        case .processing: return "Processando"
        case .reserve: return "Previsão"
        case .provisioned: return "Provisionado"
        }
    }

    /// Cor semântica associada ao status.
    var tone: Color {
        switch self {
        case .paid, .approved: return Theme.positive
        case .waitingApproval, .readyForApproval: return Theme.accent
        case .pendingBankInfo, .paymentFailed, .refunded: return Theme.negative
        case .processing, .paymentFailedReview: return Theme.warning
        case .reserve, .provisioned: return Theme.info
        case .cancelled, .notPayable: return Theme.textTertiary
        }
    }

    /// Símbolo SF associado ao status (usado nos ícones de cards).
    var symbol: String {
        switch self {
        case .paid: return "checkmark.circle.fill"
        case .approved: return "calendar.badge.checkmark"
        case .waitingApproval: return "person.badge.clock"
        case .readyForApproval: return "checkmark.shield"
        case .pendingBankInfo: return "exclamationmark.triangle"
        case .paymentFailed: return "xmark.octagon"
        case .paymentFailedReview, .processing: return "arrow.triangle.2.circlepath"
        case .refunded: return "arrow.uturn.left"
        case .reserve, .provisioned: return "clock.arrow.circlepath"
        case .cancelled, .notPayable: return "slash.circle"
        }
    }
}
