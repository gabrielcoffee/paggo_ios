import SwiftUI

// Tag display info — ported from TAG_INFO (packages.mock.ts), itself based on
// formatTagTypes from platform-blue.

/// Variantes visuais de badge (ported from components/ui/Badge BadgeVariant).
enum BadgeVariant: Sendable {
    case danger, warning, info, neutral, success, primary

    var color: Color {
        switch self {
        case .danger: return Theme.negative
        case .warning: return Theme.warning
        case .info: return Theme.info
        case .neutral: return Theme.textSecondary
        case .success: return Theme.positive
        case .primary: return Theme.accent
        }
    }
}

struct TagDisplay: Sendable {
    let displayName: String
    let variant: BadgeVariant
}

enum PackageTagInfo {
    static let map: [String: TagDisplay] = [
        "CFOP_INELEGIBLE": TagDisplay(displayName: "CFOP Inelegível", variant: .warning),
        "BANKSLIP_NOT_PAYABLE": TagDisplay(displayName: "Boleto Inválido", variant: .danger),
        "URGENT": TagDisplay(displayName: "Urgente", variant: .danger),
        "ERP_INSTALLMENT_DIVERGENCE": TagDisplay(displayName: "Divergência de Parcela ERP", variant: .warning),
        "FISCAL_DIVERGENCE": TagDisplay(displayName: "Divergência Fiscal", variant: .warning),
        "PAYMENT_ADVANCE": TagDisplay(displayName: "Adiantamento", variant: .info),
        "DUPLICATE": TagDisplay(displayName: "Risco Duplicada", variant: .danger),
        "INVALID_BANK_ACCOUNT": TagDisplay(displayName: "Conta inválida", variant: .danger),
        "LATE_FEES": TagDisplay(displayName: "Penalidades", variant: .warning),
        "ERP_AMOUNT_DIVERGENCE": TagDisplay(displayName: "≠ Valor ERP", variant: .warning),
        "ERP_AUTHORIZATION_CANCELED": TagDisplay(displayName: "Não autorizado ERP", variant: .danger),
        "TAX_ID": TagDisplay(displayName: "Risco Beneficiário", variant: .danger),
        "PAYER_TAX_ID": TagDisplay(displayName: "Risco Pagador", variant: .danger),
        "INVALID_BANKSLIP": TagDisplay(displayName: "Boleto Inválido", variant: .danger),
        "INVOICE_CANCELLED": TagDisplay(displayName: "NF Cancelada", variant: .danger),
        "EDITED_BY_USER": TagDisplay(displayName: "Editado", variant: .neutral),
        "ERP_MEGA": TagDisplay(displayName: "Mega", variant: .neutral),
        "ERP_SIENGE": TagDisplay(displayName: "Sienge", variant: .neutral),
        "ERP_UAU": TagDisplay(displayName: "UAU", variant: .neutral),
        "EXCEEDS_BUDGET": TagDisplay(displayName: "Excede orçamento", variant: .warning),
        "EXCEEDS_FISCAL_AMOUNT": TagDisplay(displayName: "Risco valor excedente", variant: .warning),
        "ADVANCE": TagDisplay(displayName: "Adiantamento", variant: .info),
        "ERP_CONFIRMATION_FAILED": TagDisplay(displayName: "Pago e não baixado", variant: .danger),
        "ERP_CREATION_FAILED": TagDisplay(displayName: "Falha Criação ERP", variant: .danger),
        "ERP_PAYMENT_DELETED": TagDisplay(displayName: "Excluído no ERP", variant: .warning),
        "INVALID_PIX": TagDisplay(displayName: "Pix inválido", variant: .danger),
        "GROUPING_AVAILABLE": TagDisplay(displayName: "Agrupamento disponível", variant: .info),
        "GROUPED_PAYMENT": TagDisplay(displayName: "Pagamento agrupado", variant: .info),
        "INVALID_ALLOCATION": TagDisplay(displayName: "Alocação inválida", variant: .warning),
        "ERP_PAYMENT_SUSPENDED": TagDisplay(displayName: "Pagamento Suspenso ERP", variant: .warning),
        "PAYMENT_ERROR": TagDisplay(displayName: "Erro no pagamento", variant: .danger),
        "MISSING_BANK_INFO": TagDisplay(displayName: "Dados bancários pendentes", variant: .warning),
        "HIGH_VALUE": TagDisplay(displayName: "Alto valor", variant: .warning),
    ]

    /// Resolve a tag para exibição, com fallback para a descrição/tipo cru.
    static func display(for tag: PackageTag) -> TagDisplay {
        if let known = map[tag.type] { return known }
        return TagDisplay(displayName: tag.description ?? tag.type, variant: .neutral)
    }
}

/// Badge de tag exibido nos cards de pagamento.
struct TagBadge: View {
    let tag: PackageTag

    var body: some View {
        let info = PackageTagInfo.display(for: tag)
        Text(info.displayName)
            .font(.brand(.caption2, weight: .semibold))
            .foregroundStyle(info.variant.color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 3)
            .background(info.variant.color.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(info.variant.color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Payment method display (PAYMENT_METHOD_DISPLAY)

enum PaymentMethodDisplay {
    /// (label, SF symbol) for a payment method code.
    static func info(for method: String) -> (label: String, symbol: String) {
        switch method {
        case "PIX": return ("Pix", "qrcode")
        case "PIX_BY_ACCOUNT": return ("Dados Bancários", "building.columns")
        case "PIX_QR": return ("Pix QR Code", "qrcode")
        case "BANKSLIP": return ("Boleto", "barcode")
        case "BARCODE": return ("Guia", "barcode")
        case "TED": return ("Transferência Bancária", "arrow.left.arrow.right")
        default: return ("Não definido", "questionmark.circle")
        }
    }
}

// MARK: - Document type display (DOCUMENT_TYPE_DISPLAY)

enum DocumentTypeDisplay {
    static func label(for type: String) -> String {
        switch type {
        case "FISCAL_INVOICE_PRODUCT": return "Nota Fiscal de Produto"
        case "FISCAL_INVOICE_SERVICE": return "Nota Fiscal de Serviço"
        case "INVOICE": return "Fatura"
        case "RECEIPT": return "Recibo"
        case "CONTRACT": return "Contrato"
        case "DARF": return "DARF"
        case "GPS": return "GPS"
        case "DAS": return "DAS"
        default: return type
        }
    }
}
