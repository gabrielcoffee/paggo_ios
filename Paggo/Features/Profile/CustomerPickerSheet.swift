import SwiftUI

/// Seletor de empresa (customer/workspace). Lista as empresas às quais o usuário pertence; tocar
/// numa troca a empresa ativa via `AuthStore.switchCustomer` (PATCH + recarga sob a nova empresa).
/// Em sucesso, o `mainScreen` remonta (novo `.id`), o que fecha este sheet e o drawer de perfil por
/// baixo; em falha, mostra toast e o seletor permanece para nova tentativa.
struct CustomerPickerSheet: View {
    @Environment(AuthStore.self) private var auth

    @State private var pendingId: String?

    private var user: AuthUser? { auth.activeUser ?? auth.savedUser }

    var body: some View {
        let customers = user?.customers ?? []
        let currentId = user?.currentCustomerId
        SheetScaffold(title: "Trocar empresa", closePlacement: .topBarLeading,
                      detents: [.medium, .large]) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(customers.enumerated()), id: \.element.id) { index, item in
                        Button { select(item, currentId: currentId) } label: {
                            row(item, selected: item.id == currentId)
                        }
                        .buttonStyle(.plain)
                        .disabled(auth.isSwitchingCustomer)
                        if index < customers.count - 1 {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    private func select(_ item: AuthUser.Workspace, currentId: String?) {
        guard item.id != currentId, !auth.isSwitchingCustomer else { return }
        pendingId = item.id
        // Sucesso remonta o app (fecha este sheet); falha mostra toast e mantém o seletor aberto.
        Task { await auth.switchCustomer(to: item.id) }
    }

    private func row(_ item: AuthUser.Workspace, selected: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: "building.2",
                       tint: selected ? Theme.accent : Theme.textTertiary, size: 38, symbolSize: 16)
            Text(item.name.isEmpty ? "Empresa" : item.name.capitalizedNamePtBr)
                .font(.brand(.subheadline, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: Spacing.sm)
            if pendingId == item.id, auth.isSwitchingCustomer {
                ProgressView().controlSize(.small)
            } else if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }
}
