import SwiftUI

/// Mini cartão — identidade visual do cartão em tamanho de ícone. Usado no seletor de escopo
/// do extrato e nas linhas de transação. `symbol` (opcional) centraliza o SF Symbol do método
/// de pagamento em branco — um ícone só identifica o cartão E o tipo da transação.
struct WalletMiniCard: View {
    let style: WalletCardStyle
    var symbol: String? = nil

    /// Tamanho único em todo o app (ratio de cartão físico ~1.52).
    static let size = CGSize(width: 44, height: 29)

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(LinearGradient(colors: [style.top, style.bottom],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                // Mesmo fio de luz do cartão grande (WalletCardView).
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.06)],
                                                 startPoint: .top, endPoint: .bottom),
                                  lineWidth: 1)
            }
            .overlay {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
            .frame(width: Self.size.width, height: Self.size.height)
    }
}

/// Variante genérica (escopo "Todas as carteiras") — neutra, com símbolo de pilha.
struct WalletMiniCardGeneric: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Theme.surfaceHigh)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
            .overlay {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: WalletMiniCard.size.width, height: WalletMiniCard.size.height)
    }
}
