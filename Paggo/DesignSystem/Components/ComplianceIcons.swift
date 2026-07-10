import SwiftUI

/// Ícones de conformidade por linha de gasto (recibo/alocação) — a pendência aparece na
/// lista, sem abrir a transação. Verde = resolvido, âmbar = pendente.
struct ComplianceIcons: View {
    var receiptAttached: Bool?        // nil = recibo não se aplica (ex.: recusada)
    var allocationDone: Bool?         // nil = alocação não se aplica

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let receiptAttached {
                icon("doc.text", done: receiptAttached,
                     label: receiptAttached ? "Recibo anexado" : "Recibo pendente")
            }
            if let allocationDone {
                icon("chart.pie", done: allocationDone,
                     label: allocationDone ? "Alocação completa" : "Alocação pendente")
            }
        }
    }

    private func icon(_ symbol: String, done: Bool, label: String) -> some View {
        Image(systemName: done ? symbol : "\(symbol).fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(done ? Theme.positive : Theme.warning)
            .accessibilityLabel(label)
    }
}
