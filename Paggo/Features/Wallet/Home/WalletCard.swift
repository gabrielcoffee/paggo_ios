import SwiftUI

/// Paleta de gradientes dos cartões da carteira (um tom por carteira).
/// `accent` é a versão clara da cor — usada para identificar o cartão em superfícies
/// pequenas (filete do extrato, bolinhas), onde o gradiente escuro não tem contraste.
struct WalletCardStyle: Sendable {
    let top: Color
    let bottom: Color
    let accent: Color

    static let palette: [WalletCardStyle] = [
        .init(top: Color(hex: "#2A3F25"), bottom: Color(hex: "#0C160B"), accent: Color(hex: "#7FB56E")),  // verde
        .init(top: Color(hex: "#3C3A16"), bottom: Color(hex: "#15140A"), accent: Color(hex: "#B5AC4E")),  // oliva
        .init(top: Color(hex: "#1E2E3A"), bottom: Color(hex: "#0A1016"), accent: Color(hex: "#6FA3C7")),  // azul-petróleo
        .init(top: Color(hex: "#3A2230"), bottom: Color(hex: "#160A11"), accent: Color(hex: "#C76F9B")),  // vinho
    ]

    static func at(_ index: Int) -> WalletCardStyle { palette[((index % palette.count) + palette.count) % palette.count] }
}

/// Cartão de crédito da carteira — visual do app-wallet (gradiente escuro, nome, limite, barra, totais).
struct WalletCardView: View {
    let wallet: Wallet
    let style: WalletCardStyle
    var hidden: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Topo: ícone + nome do cartão (um degrau acima do corpo na escala tipográfica).
            HStack(spacing: Spacing.sm) {
                Image(systemName: "creditcard")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.white.opacity(0.92))
                Text(wallet.name)
                    .font(.brand(.callout, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.lg)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Saldo")
                    .font(.brand(.subheadline))
                    .foregroundStyle(.white.opacity(0.72))
                Text(hidden ? "R$ ••••••" : wallet.availableLimit.currencyFromCents())
                    .font(.brand(size: 26, weight: .regular))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Spacer(minLength: Spacing.md)

            // Barra usa limite/total (não o disponível capado), para a porção escura = "Utilizado".
            WalletLimitBar(available: wallet.limit, total: wallet.maximumLimit, hidden: hidden)

            Spacer(minLength: Spacing.sm)

            HStack {
                Text("Limite: \(hidden ? "R$ ••••" : wallet.maximumLimit.currencyFromCents())")
                Spacer()
            }
            .font(.brand(.subheadline))
            .foregroundStyle(.white.opacity(0.72))
            .monospacedDigit()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .aspectRatio(1.72, contentMode: .fit)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [style.top, style.bottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                // brilho diagonal
                LinearGradient(colors: [.clear, .white.opacity(0.10), .clear],
                               startPoint: .bottomLeading, endPoint: .topTrailing)
                CardCornerPattern()
                    .padding(Spacing.xl)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        // Borda "de cartão físico": fio de luz pegando na aresta superior, esmaecendo embaixo.
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.06)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 10)
    }
}

/// Barra de limite: a porção DISPONÍVEL é um gradiente verde→claro; a porção utilizada fica escura.
struct WalletLimitBar: View {
    let available: Int
    let total: Int
    var hidden: Bool = false

    private var availableFraction: Double {
        guard !hidden, total > 0 else { return 0 }
        return min(1, max(0, Double(available) / Double(total)))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.34))          // trilho (porção utilizada)
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#46A35A"), Color(hex: "#B7C9AE")],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * availableFraction)
            }
        }
        .frame(height: 6)
    }
}

/// Padrão decorativo de cantos (grade de pequenos sinais "+") no canto superior direito do cartão.
struct CardCornerPattern: View {
    var rows = 4
    var cols = 5
    var spacing: CGFloat = 14
    var tick: CGFloat = 4

    var body: some View {
        Canvas { context, _ in
            for r in 0..<rows {
                for c in 0..<cols {
                    let x = CGFloat(c) * spacing
                    let y = CGFloat(r) * spacing
                    var path = Path()
                    path.move(to: CGPoint(x: x - tick, y: y)); path.addLine(to: CGPoint(x: x + tick, y: y))
                    path.move(to: CGPoint(x: x, y: y - tick)); path.addLine(to: CGPoint(x: x, y: y + tick))
                    context.stroke(path, with: .color(.white.opacity(0.16)), lineWidth: 1)
                }
            }
        }
        .frame(width: CGFloat(cols - 1) * spacing, height: CGFloat(rows - 1) * spacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

/// Marca do Pix (4 losangos arredondados) desenhada em SwiftUI (não há asset).
struct PixMark: View {
    var size: CGFloat = 24
    var color: Color = Theme.textPrimary

    var body: some View {
        ZStack {
            diamond.offset(y: -size * 0.30)
            diamond.offset(y: size * 0.30)
            diamond.offset(x: -size * 0.30)
            diamond.offset(x: size * 0.30)
        }
        .frame(width: size, height: size)
        .foregroundStyle(color)
    }

    private var diamond: some View {
        RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
            .stroke(lineWidth: 1.7)
            .frame(width: size * 0.36, height: size * 0.36)
            .rotationEffect(.degrees(45))
    }
}
