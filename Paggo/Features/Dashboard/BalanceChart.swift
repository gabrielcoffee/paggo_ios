import SwiftUI
import Charts

/// Histórico de saldo consolidado — área + linha branca, no estilo do CashFlowChart do ios-pocs.
struct BalanceChart: View {
    let points: [BalanceHistoryPoint]
    var compact: Bool = false

    @State private var reveal: CGFloat = 0

    var body: some View {
        if points.count < 2 {
            emptyState
        } else {
            chart
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Theme.textTertiary)
            Text("Sem histórico disponível")
                .font(.brand(.subheadline, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Text("O histórico de saldo aparecerá aqui assim que houver movimentações.")
                .font(.brand(.caption))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 120 : 180)
        .padding(.horizontal, Spacing.lg)
    }

    private var chart: some View {
        Chart {
            ForEach(points) { p in
                AreaMark(
                    x: .value("Data", p.dateValue),
                    y: .value("Saldo", p.balance.asReais)
                )
                .foregroundStyle(.linearGradient(
                    // Brilho terracota da marca, mais presente e com queda suave em 3 paradas —
                    // minimalista mas visível (o fill anterior a 0.28 sumia no fundo escuro).
                    Gradient(stops: [
                        .init(color: Theme.accent.opacity(0.42), location: 0.0),
                        .init(color: Theme.accent.opacity(0.16), location: 0.5),
                        .init(color: Theme.accent.opacity(0.0), location: 1.0),
                    ]),
                    startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            }
            ForEach(points) { p in
                LineMark(
                    x: .value("Data", p.dateValue),
                    y: .value("Saldo", p.balance.asReais)
                )
                // Off-white/off-black suave — menos contraste que o branco/preto puro.
                .foregroundStyle(Theme.textPrimary.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round))
                .interpolationMethod(.monotone)
            }
            if let last = points.last {
                PointMark(
                    x: .value("Data", last.dateValue),
                    y: .value("Saldo", last.balance.asReais)
                )
                .symbolSize(80)
                .foregroundStyle(Theme.accent)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: compact ? 2 : 1)) { value in
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(d.shortMonth).font(.brand(.caption2)).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            if compact {
                AxisMarks(values: .automatic(desiredCount: 0))
            } else {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.separator)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v.abbreviated()).font(.brand(.caption2)).foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
        }
        .frame(height: compact ? 120 : 180)
        .mask(GeometryReader { geo in Rectangle().frame(width: geo.size.width * reveal) })
        .onAppear { withAnimation(.easeOut(duration: 1.0)) { reveal = 1 } }
    }
}
