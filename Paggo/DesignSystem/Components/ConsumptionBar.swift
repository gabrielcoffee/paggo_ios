import SwiftUI

/// Barra de consumo de orçamento com os marcos de alerta das specs (75% âmbar, 90% vermelho).
/// Envelopa `ProgressBarView` mudando só a cor por faixa — os thresholds são os mesmos das
/// notificações de `budget_threshold`, então barra e aviso nunca discordam.
struct ConsumptionBar: View {
    let consumed: Int
    let limit: Int
    var height: CGFloat = 8
    var showsLabels = false

    private var fraction: Double {
        guard limit > 0 else { return 0 }
        return Double(consumed) / Double(limit)
    }

    private var color: Color {
        switch fraction {
        case ..<0.75: return Theme.positive
        case ..<0.90: return Theme.warning
        default: return Theme.negative
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ProgressBarView(fraction: fraction, color: color, height: height)
            if showsLabels {
                HStack {
                    Text("\(consumed.currencyFromCents()) usados")
                    Spacer()
                    Text("de \(limit.currencyFromCents())")
                }
                .font(.brand(.caption))
                .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
