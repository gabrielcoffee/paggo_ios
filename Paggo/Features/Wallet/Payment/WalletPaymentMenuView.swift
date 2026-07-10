import SwiftUI

/// "Pagar" — escolha do método de pagamento, agrupado por família (Pix / Boleto), com câmera a
/// um toque quando disponível. Cada método abre o fluxo (`WalletPaymentFlowView`).
struct WalletPaymentMenuView: View {
    @Environment(WalletStore.self) private var wallet
    @State private var payLaunch: WalletPayLaunch?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        sectionLabel("Pix")
                        VStack(spacing: 0) {
                            WalletMethodRow(
                                title: "Ler QR Code",
                                subtitle: WalletScannerView.isSupported
                                    ? "Aponte a câmera para o código e pague"
                                    : "Cole o código do QR para pagar",
                                icon: "qrcode.viewfinder"
                            ) { payLaunch = WalletPayLaunch(entry: .pixQR) }
                            rowDivider
                            WalletMethodRow(title: "Pix Copia e Cola",
                                            subtitle: "Cole o código copiado para pagar",
                                            icon: "doc.on.clipboard") {
                                payLaunch = WalletPayLaunch(entry: .pixCopyPaste)
                            }
                            rowDivider
                            WalletMethodRow(title: "Pix por chave",
                                            subtitle: "CPF/CNPJ, telefone, e-mail ou aleatória",
                                            icon: "key.horizontal") {
                                payLaunch = WalletPayLaunch(entry: .pixKey)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        sectionLabel("Boleto")
                        VStack(spacing: 0) {
                            if WalletScannerView.isSupported {
                                WalletMethodRow(title: "Escanear código de barras",
                                                subtitle: "Aponte a câmera para o boleto",
                                                icon: "barcode.viewfinder") {
                                    payLaunch = WalletPayLaunch(entry: .boleto, preferScanner: true)
                                }
                                rowDivider
                            }
                            WalletMethodRow(title: "Digitar linha digitável",
                                            subtitle: "Digite ou cole os números do boleto",
                                            icon: "number") {
                                payLaunch = WalletPayLaunch(entry: .boleto)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxxl)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .screenBackground(tint: WalletCardStyle.at(wallet.styleIndex(for: wallet.currentWallet)).accent)
            .animation(.easeInOut(duration: 0.4), value: wallet.currentWallet?.id)
            .navigationTitle("Pagar")
            .fullScreenCover(item: $payLaunch) { launch in
                WalletPaymentFlowView(entry: launch.entry, preferScanner: launch.preferScanner)
            }
        }
    }

    private var rowDivider: some View { Divider().overlay(Theme.separator) }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.brand(.caption, weight: .semibold)).tracking(0.8)
            .foregroundStyle(Theme.textTertiary)
    }
}
