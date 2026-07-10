import SwiftUI

/// Bottom drawer de perfil (substitui o antigo popover do avatar). Conteúdo sobre o vidro
/// do sheet (`.ultraThinMaterial` no apresentador) — sem `screenBackground`, cards sólidos
/// por cima (disciplina Liquid Glass: vidro só na camada de navegação).
///
/// Estrutura: identidade → cards de modo (Plataforma / Carteira) → preferências
/// (aparência inline + drawer de notificações) → sair.
struct ProfileDrawer: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppearanceStore.self) private var appearance
    @Environment(AppModeStore.self) private var appMode
    @Environment(\.dismiss) private var dismiss

    @State private var showNotifications = false
    @State private var showCustomerPicker = false

    /// Ação diferida até o sheet sumir por completo. O RootView troca a tela raiz ao mudar
    /// o modo ou sair, o que desmontaria este sheet no meio da animação — então a ação é
    /// aplicada no `onDisappear` do conteúdo (dispara exatamente quando o drawer some).
    /// A última escolha antes do fechamento vence; não há task com delay para vazar.
    private enum PendingAction: Equatable {
        case switchMode(AppMode)
        case signOut
    }

    @State private var pendingAction: PendingAction?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    identityHeader
                    workspaceSection
                    modeSection
                    settingsSection
                    signOutRow
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationDestination(isPresented: $showNotifications) {
                NotificationPrefsView()
            }
            .sheet(isPresented: $showCustomerPicker) {
                CustomerPickerSheet()
            }
        }
        .onDisappear(perform: applyPendingAction)
    }

    private func applyPendingAction() {
        switch pendingAction {
        case .switchMode(let mode): appMode.mode = mode
        case .signOut: auth.signOut()
        case nil: break
        }
        pendingAction = nil
    }

    // MARK: Identidade

    private var user: AuthUser? { auth.activeUser ?? auth.savedUser }

    private var identityHeader: some View {
        HStack(spacing: Spacing.md) {
            OwnerAvatar(name: user?.name ?? "Você", imageURL: user?.image, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(user?.name ?? "Você")
                    .font(.brand(.body, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let email = user?.email {
                    Text(email)
                        .font(.brand(.caption, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Empresa (customer / workspace)

    /// Linha com a empresa ativa; toca para abrir o seletor. Só aparece quando o usuário pertence a
    /// mais de uma empresa (`canSwitchCustomer`).
    @ViewBuilder private var workspaceSection: some View {
        if let user, user.canSwitchCustomer {
            let name = user.currentWorkspaceName.flatMap { $0.isEmpty ? nil : $0.capitalizedNamePtBr }
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader("Empresa")
                GlassCard(glass: true, padding: Spacing.sm) {
                    DisclosureRow(title: name ?? "Selecionar empresa", icon: "building.2") {
                        showCustomerPicker = true
                    }
                    .padding(.horizontal, Spacing.sm)
                }
            }
        }
    }

    // MARK: Modo (herói do drawer)

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Modo")
            HStack(spacing: Spacing.md) {
                ForEach(AppMode.allCases) { mode in
                    modeCard(mode)
                }
            }
        }
    }

    private func modeCard(_ mode: AppMode) -> some View {
        let isSelected = mode == appMode.mode
        return Button {
            select(mode)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top) {
                    TintedIcon(symbol: mode.symbol,
                               tint: isSelected ? Theme.accent : Theme.neutralIcon,
                               size: 38, symbolSize: 16)
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary.opacity(0.5))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.label)
                        .font(.brand(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle(for: mode))
                        .font(.brand(.caption2, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Color.clear.glassEffect(.regular, in: .rect(cornerRadius: Radius.xl))
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.accent.opacity(0.16), Theme.accent.opacity(0.04)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                    .stroke(isSelected ? Theme.accent : Theme.stroke, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: appMode.mode)
        .accessibilityLabel("\(mode.label), \(subtitle(for: mode))")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func subtitle(for mode: AppMode) -> String {
        switch mode {
        case .app: return "Pagamentos e aprovações"
        case .wallet: return "Cartões e transações"
        }
    }

    /// Registra o modo pendente e fecha o drawer; a troca acontece no `onDisappear`,
    /// depois que o sheet sumiu por completo (ver `PendingAction`).
    private func select(_ mode: AppMode) {
        guard mode != appMode.mode else {
            // Re-tocar no modo atual cancela uma troca ainda pendente.
            pendingAction = nil
            return
        }
        pendingAction = .switchMode(mode)
        dismiss()
    }

    // MARK: Preferências

    private var settingsSection: some View {
        @Bindable var appearance = appearance
        return VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Preferências")
            GlassCard(glass: true, padding: Spacing.sm) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack(spacing: Spacing.md) {
                            TintedIcon(symbol: "circle.lefthalf.filled", tint: Theme.accent,
                                       size: 32, symbolSize: 13)
                            Text("Aparência")
                                .font(.brand(.subheadline, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        SegmentedControl(selection: $appearance.mode,
                                         options: AppearanceMode.allCases,
                                         label: { $0.label })
                    }
                    .padding(Spacing.sm)
                    .padding(.top, Spacing.xs)

                    Divider().overlay(Theme.separator)

                    DisclosureRow(title: "Notificações", icon: "bell.badge") {
                        showNotifications = true
                    }
                    .padding(.horizontal, Spacing.sm)
                }
            }
        }
    }

    // MARK: Sair

    private var signOutRow: some View {
        Button {
            pendingAction = .signOut
            dismiss()
        } label: {
            HStack(spacing: Spacing.md) {
                TintedIcon(symbol: "rectangle.portrait.and.arrow.right", tint: Theme.negative,
                           size: 32, symbolSize: 13)
                Text("Sair")
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.negative)
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: Radius.lg))
        }
    }
}

#Preview("Drawer de perfil") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ProfileDrawer()
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .environment(AuthStore(repo: MockAuthRepository(), biometrics: MockBiometricAuthenticator()))
        .environment(AppearanceStore())
        .environment(AppModeStore())
}
