import SwiftUI

/// Aprovações — todos os pagamentos pendentes de liberação (WAITING_APPROVAL), com aprovar/retornar.
struct ApprovalsView: View {
    @Environment(PayoutStore.self) private var store
    @Environment(ToastCenter.self) private var toastCenter
    @Environment(AuthStore.self) private var auth
    @State private var acting: CardAction?
    @State private var approvalGate: Package?   // 2FA (Face ID / OTP) obrigatório antes de liberar

    /// Ação de card em voo — mostra spinner no botão que agiu.
    private struct CardAction: Equatable {
        let packageID: String
        let kind: Kind
        enum Kind { case approve, returnToValidation }
    }

    private var pending: [Package] {
        // Já vem ordenado do servidor (GET /packages orderBy+sort).
        store.rawPackages(for: .approval)
    }

    private var totalPending: Int { pending.reduce(0) { $0 + $1.paymentAmount } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.isLoading && !store.hasLoaded {
                    PackageListSkeleton(count: 5, showApprovers: true)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.sm)
                } else {
                    VStack(spacing: Spacing.lg) {
                        summaryCard

                        if pending.isEmpty {
                            emptyState
                        } else {
                            ForEach(pending) { package in
                                approvalCard(package)
                                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl)
                    .animation(.snappy, value: pending)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .refreshable { await store.load(force: true) }
            .screenBackground()
            .navigationTitle("Aprovações")
            .task { await store.load() }
            .sheet(item: $approvalGate) { pkg in
                TwoFactorSheet(
                    title: "Liberar pagamento",
                    reason: "Confirme sua identidade para liberar o pagamento",
                    email: auth.activeUser?.email ?? auth.savedUser?.email ?? "",
                    onVerified: {
                        run(CardAction(packageID: pkg.id, kind: .approve)) {
                            await store.approve(ids: [pkg.id])
                        }
                    },
                    onCancel: {}
                )
                .presentationDetents([.height(480), .large])
                .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    private var summaryCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aguardando liberação").secondaryLabel()
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Text("\(pending.count)")
                            .font(.heroNumber)
                            .foregroundStyle(Theme.textPrimary)
                        Text(pending.isEmpty ? "tudo em dia" : "para revisar")
                            .font(.brand(.subheadline))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                if !pending.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Valor total").secondaryLabel()
                        Text(totalPending.currencyCompactFromCents())
                            .font(.brand(.title3, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    private func approvalCard(_ package: Package) -> some View {
        VStack(spacing: Spacing.sm) {
            NavigationLink {
                PackageDetailView(package: package)
            } label: {
                PackageCardView(package: package, showApprovers: true, showTagsOverride: true)
            }
            .buttonStyle(.plain)

            HStack(spacing: Spacing.md) {
                Button {
                    run(CardAction(packageID: package.id, kind: .returnToValidation)) {
                        await store.returnToValidation(ids: [package.id])
                    }
                } label: {
                    cardButtonLabel("Retornar", spinning: acting == CardAction(packageID: package.id, kind: .returnToValidation),
                                    tint: Theme.textSecondary)
                }
                .buttonStyle(SecondaryActionStyle())
                Button {
                    approvalGate = package
                } label: {
                    cardButtonLabel("Liberar", spinning: acting == CardAction(packageID: package.id, kind: .approve),
                                    tint: .white)
                }
                .buttonStyle(PrimaryActionStyle())
            }
            // Mutação em voo (daqui ou de outra tela): esmaece, mas toques respondem com toast.
            .opacity(store.isMutating ? 0.6 : 1)
            .animation(.snappy, value: store.isMutating)
        }
    }

    private func cardButtonLabel(_ title: String, spinning: Bool, tint: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            if spinning {
                ProgressView().controlSize(.small).tint(tint)
            }
            Text(title)
        }
        .frame(maxWidth: .infinity)
    }

    /// Dispara a ação do card com single-flight visível: spinner no botão que agiu; toque
    /// durante outra mutação (local ou cross-screen) mostra o toast em vez de sumir em silêncio.
    private func run(_ action: CardAction, _ operation: @escaping () async -> Bool) {
        guard acting == nil, !store.isMutating else {
            toastCenter.show("Aguarde a ação anterior terminar.", style: .info)
            return
        }
        acting = action
        Task {
            _ = await operation()
            acting = nil
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.positive)
            Text("Nenhuma aprovação pendente")
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxxl * 2)
    }
}
