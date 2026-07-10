import SwiftUI

/// Sheet "Personalizar Visualização": escolhe quais informações aparecem nos cartões de pagamento.
/// Espelha o estilo de lista-de-toggles do `NotificationPrefsView` (linhas em `GlassCard` +
/// `Toggle` tingido de `Theme.accent`). As mudanças aplicam-se imediatamente/reativamente aos
/// cartões (via `PaymentCardPrefsStore.shared`) — sem botão "Salvar".
///
/// Portado de apps/paggo-mobile-app/src/components/payout/SettingsBottomSheet.tsx.
struct PaymentCardSettingsSheet: View {
    var body: some View {
        @Bindable var store = PaymentCardPrefsStore.shared
        SheetScaffold(title: "Personalizar Visualização", detents: [.medium, .large]) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Escolha quais informações você deseja ver nos cartões de pagamento.")
                        .font(.brand(.caption, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)

                    GlassCard(padding: Spacing.sm) {
                        VStack(spacing: 0) {
                            // Fixos (sempre visíveis) — toggle ligado e desabilitado.
                            fixedRow("Valor", symbol: "brazilianrealsign.circle")
                            rowDivider
                            fixedRow("Data Agendamento", symbol: "calendar")
                            rowDivider
                            fixedRow("Recebedor", symbol: "person.crop.circle")
                            rowDivider

                            // Personalizáveis — aplicam ao vivo.
                            liveRow("Pagador", symbol: "building.2", isOn: $store.showPayer.animation(.snappy))
                            rowDivider
                            liveRow("Etiquetas", symbol: "tag", isOn: $store.showTags.animation(.snappy))
                            rowDivider
                            liveRow("Conta Gerencial", symbol: "chart.bar.doc.horizontal",
                                    isOn: $store.showManagerialAccount.animation(.snappy))
                            rowDivider
                            liveRow("Centro de Custo", symbol: "square.grid.2x2",
                                    isOn: $store.showCostCenter.animation(.snappy))
                            rowDivider
                            liveRow("Documento", symbol: "doc.text",
                                    isOn: $store.showDocument.animation(.snappy))
                            rowDivider

                            // Ainda não disponíveis — desligados e desabilitados.
                            comingSoonRow("Multa", symbol: "exclamationmark.circle")
                            rowDivider
                            comingSoonRow("Juros", symbol: "percent")
                        }
                    }

                    Button {
                        withAnimation(.snappy) { store.reset() }
                    } label: {
                        Label("Restaurar padrão", systemImage: "arrow.counterclockwise")
                            .font(.brand(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Spacing.xs)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxxl)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    private var rowDivider: some View { Divider().overlay(Theme.separator) }

    // MARK: Rows

    /// Campo fixo (sempre visível): toggle ligado, desabilitado e esmaecido.
    private func fixedRow(_ title: String, symbol: String) -> some View {
        rowShell(title: title, symbol: symbol, isOn: .constant(true), enabled: false)
    }

    /// Campo personalizável: toggle ao vivo ligado ao store.
    private func liveRow(_ title: String, symbol: String, isOn: Binding<Bool>) -> some View {
        rowShell(title: title, symbol: symbol, isOn: isOn, enabled: true)
    }

    /// Campo "Em breve": desligado, desabilitado e esmaecido, com selo de estado.
    private func comingSoonRow(_ title: String, symbol: String) -> some View {
        rowShell(title: title, symbol: symbol, isOn: .constant(false), enabled: false, comingSoon: true)
    }

    private func rowShell(title: String,
                          symbol: String,
                          isOn: Binding<Bool>,
                          enabled: Bool,
                          comingSoon: Bool = false) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: Spacing.md) {
                TintedIcon(symbol: symbol, tint: Theme.accent, size: 32, symbolSize: 13)
                Text(title)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                if comingSoon {
                    Text("Em breve")
                        .font(.brand(.caption2, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Theme.textTertiary.opacity(0.12), in: Capsule())
                }
            }
        }
        .tint(Theme.accent)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .padding(Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }
}

#Preview("Personalizar Visualização") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PaymentCardSettingsSheet()
        }
}
