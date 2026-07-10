import SwiftUI

/// Segundo drawer do perfil (push dentro do sheet): preferências de notificação push.
/// Persistidas localmente via `NotificationPrefsStore` — backend intencionalmente mockado.
struct NotificationPrefsView: View {
    var body: some View {
        // Singleton local (sem injeção no PaggoApp) — body é MainActor, acesso seguro.
        @Bindable var store = NotificationPrefsStore.shared
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Escolha quando receber notificações push neste dispositivo.")
                    .font(.brand(.caption, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                GlassCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        prefToggle("Quando uma aprovação for solicitada",
                                   symbol: "person.badge.clock",
                                   isOn: $store.prefs.approvalRequested)
                        Divider().overlay(Theme.separator)
                        prefToggle("Quando um pagamento for enviado",
                                   symbol: "paperplane",
                                   isOn: $store.prefs.paymentSent)
                        Divider().overlay(Theme.separator)
                        prefToggle("Quando um novo pagamento for recebido",
                                   symbol: "arrow.down.circle",
                                   isOn: $store.prefs.paymentReceived)
                        Divider().overlay(Theme.separator)
                        prefToggle("Quando um pagamento falhar",
                                   symbol: "exclamationmark.triangle",
                                   isOn: $store.prefs.paymentFailed)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Notificações")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func prefToggle(_ title: String, symbol: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: Spacing.md) {
                TintedIcon(symbol: symbol, tint: Theme.accent, size: 32, symbolSize: 13)
                Text(title)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
            }
        }
        .tint(Theme.accent)
        .padding(Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }
}

#Preview("Notificações") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                NotificationPrefsView()
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
            .presentationDragIndicator(.visible)
        }
}
