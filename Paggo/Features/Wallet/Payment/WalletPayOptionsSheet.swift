import SwiftUI

/// Lançamento do fluxo de pagamento: entrada + se o scanner deve ser o primeiro passo.
struct WalletPayLaunch: Identifiable, Hashable {
    let id = UUID()
    let entry: WalletPaymentEntry
    var preferScanner = false
}

/// Sheet de opções ao tocar "Pix" ou "Pagar" na home — segunda tela com as formas disponíveis,
/// com câmera a um toque (QR / código de barras) quando o aparelho tem scanner.
struct WalletPayOptionsSheet: View {
    enum Kind: String, Identifiable {
        case pix, boleto
        var id: String { rawValue }

        var title: String {
            switch self {
            case .pix: return "Pagar com Pix"
            case .boleto: return "Pagar boleto"
            }
        }
    }

    let kind: Kind
    let onChoose: (WalletPayLaunch) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(kind.title)
                .font(.brand(.title3, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, Spacing.xl)

            VStack(spacing: 0) {
                switch kind {
                case .pix:
                    WalletMethodRow(
                        title: "Ler QR Code",
                        subtitle: WalletScannerView.isSupported
                            ? "Aponte a câmera para o código e pague"
                            : "Cole o código do QR para pagar",
                        icon: "qrcode.viewfinder"
                    ) { onChoose(WalletPayLaunch(entry: .pixQR)) }
                    divider
                    WalletMethodRow(title: "Pix Copia e Cola",
                                    subtitle: "Cole o código copiado para pagar",
                                    icon: "doc.on.clipboard") {
                        onChoose(WalletPayLaunch(entry: .pixCopyPaste))
                    }
                    divider
                    WalletMethodRow(title: "Pix por chave",
                                    subtitle: "CPF/CNPJ, telefone, e-mail ou aleatória",
                                    icon: "key.horizontal") {
                        onChoose(WalletPayLaunch(entry: .pixKey))
                    }
                case .boleto:
                    if WalletScannerView.isSupported {
                        WalletMethodRow(title: "Escanear código de barras",
                                        subtitle: "Aponte a câmera para o boleto",
                                        icon: "barcode.viewfinder") {
                            onChoose(WalletPayLaunch(entry: .boleto, preferScanner: true))
                        }
                        divider
                    }
                    WalletMethodRow(title: "Digitar linha digitável",
                                    subtitle: "Digite ou cole os números do boleto",
                                    icon: "number") {
                        onChoose(WalletPayLaunch(entry: .boleto))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .presentationDetents([.height(kind == .pix ? 330 : 250)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.base)
    }

    private var divider: some View { Divider().overlay(Theme.separator) }
}

/// Linha de método de pagamento (ícone + título + subtítulo + chevron) — compartilhada entre o
/// sheet de opções da home e a aba "Pagar".
struct WalletMethodRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                TintedIcon(symbol: icon, tint: Theme.accent, size: 40, symbolSize: 17)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        Text(title)
                            .font(.brand(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if let badge {
                            Text(badge.uppercased())
                                .font(.brand(.caption2, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.accent, in: Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.brand(.caption))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
