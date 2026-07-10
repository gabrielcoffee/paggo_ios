import SwiftUI

/// Detalhe do pagamento — tela com abas (Detalhes · Documentos · Orçamento · Conciliação ·
/// Histórico) + rodapé de ações, espelhando PackageDetailsScreen do app Expo.
struct PackageDetailView: View {
    let package: Package
    @Environment(PayoutStore.self) private var store
    @Environment(AuthStore.self) private var auth
    @Environment(ToastCenter.self) private var toastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var detail: PackageDetailStore
    @State private var selectedTab = ProcessInfo.processInfo.environment["PAGGO_DETAIL_TAB"] ?? "details"
    @State private var showVerification = false
    @State private var showReceipts = false
    @State private var showSoonAlert = false
    @State private var inFlightAction: String?

    init(package: Package) {
        self.package = package
        _detail = State(initialValue: PackageDetailStore(package: package))
    }

    private var details: PackageDetails { detail.details }

    /// E-mail que recebe o código de liberação — o usuário ativo (ou o salvo no atalho de Face ID).
    private var approverEmail: String {
        auth.activeUser?.email ?? auth.savedUser?.email ?? ""
    }

    private var tabs: [DetailTab] {
        var items: [DetailTab] = [
            DetailTab(key: "details", title: "Detalhes"),
            DetailTab(key: "documents", title: "Documentos",
                      badge: details.documentEntriesCount, badgeVariant: .neutral),
        ]
        if details.consumesBudget {
            let over = details.budget?.hasOverBudgetLines ?? false
            items.append(DetailTab(key: "budget", title: "Orçamento",
                                   badge: over ? 1 : nil, badgeVariant: .danger))
        }
        items.append(DetailTab(key: "conciliation", title: "Conciliação"))
        items.append(DetailTab(key: "history", title: "Histórico"))
        return items
    }

    private var showFooter: Bool {
        selectedTab != "history" && clusterSpec != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailTabBar(tabs: tabs, selection: $selectedTab)
            Divider().overlay(Theme.separator)
            tabContent
        }
        .screenBackground()
        .navigationTitle("Detalhes do Pagamento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)   // dá o rodapé de ações a borda inferior (sem o tab bar de vidro)
        .task { await detail.load() }
        .safeAreaInset(edge: .bottom) {
            if showFooter { footer }
        }
        .sheet(isPresented: $showVerification) {
            TwoFactorSheet(
                title: "Liberar pagamento",
                reason: "Confirme sua identidade para liberar o pagamento",
                email: approverEmail,
                onVerified: { finishApprove() },
                onCancel: {}
            )
            .presentationDetents([.height(480), .large])
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showReceipts) {
            ReceiptsSheet(receipts: details.receipts)
        }
        .alert("Disponível em Breve", isPresented: $showSoonAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Esta ação ainda não está disponível no aplicativo. Use a versão web.")
        }
    }

    // MARK: - Tab content

    @ViewBuilder private var tabContent: some View {
        switch selectedTab {
        case "documents": documentsTab
        case "budget": budgetTab
        case "conciliation": conciliationTab
        case "history": PaymentHistoryView(detail: detail, currentUser: auth.activeUser)
        default: detailsTab
        }
    }

    /// Sem gate global de loading: a semente do Package pinta em t=0 e cada seção chega
    /// independente (skeleton por seção / pop-in), como os hooks SWR do web.
    private var detailsTab: some View {
        ScrollView {
            VStack(spacing: Spacing.section) {
                if !details.alerts.isEmpty { PaymentAlertsView(alerts: details.alerts) }
                PaymentSummaryView(details: details, summaryLoading: detail.isLoading(.summary))
                tagsSection
                if let desc = details.description, !desc.isEmpty {
                    PaymentDescriptionView(description: desc)
                }
                section(.method) {
                    if let method = details.paymentMethod { PaymentMethodSectionView(method: method) }
                }
                section(.allocations) {
                    PaymentAllocationsSectionView(allocations: details.allocations ?? [])
                }
                section(.approvers) {
                    PaymentApproversSectionView(approvers: details.detailApprovers)
                }
                section(.delivery) {
                    if let delivery = details.delivery { PaymentDeliverySectionView(delivery: delivery) }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)   // o cluster flutuante já reserva espaço via safeAreaInset
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await detail.reload() }
    }

    /// Tags semeadas da listagem aparecem imediatamente; skeleton só quando nada foi semeado.
    @ViewBuilder private var tagsSection: some View {
        if detail.isLoading(.tags) && details.paymentTypeLabel == nil && (details.tags ?? []).isEmpty {
            HStack(spacing: Spacing.sm) {
                Skeleton(width: 96, height: 24, cornerRadius: Radius.pill)
                Skeleton(width: 72, height: 24, cornerRadius: Radius.pill)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            PaymentTagsView(typeLabel: details.paymentTypeLabel, tags: details.tags ?? [])
        }
    }

    /// Mostra um skeleton enquanto a seção ainda carrega (live); senão, o conteúdo.
    @ViewBuilder private func section<Content: View>(_ s: PackageDetailStore.Section,
                                                    @ViewBuilder content: () -> Content) -> some View {
        if detail.isLoading(s) {
            DetailSectionSkeleton(lines: 2)
        } else {
            content()
        }
    }

    private var documentsTab: some View {
        ScrollView {
            VStack(spacing: Spacing.section) {
                PaymentDocumentEntriesView(entries: details.packageDocumentEntries ?? [])
                if let attachments = details.attachments, !attachments.isEmpty {
                    PaymentAttachmentsView(attachments: attachments)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)   // o cluster flutuante já reserva espaço via safeAreaInset
        }
    }

    private var budgetTab: some View {
        ScrollView {
            Group {
                if detail.isLoading(.budget) {
                    DetailSectionSkeleton(lines: 3)
                } else {
                    PaymentBudgetSectionView(budget: details.budget)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)   // o cluster flutuante já reserva espaço via safeAreaInset
        }
    }

    private var conciliationTab: some View {
        ScrollView {
            Group {
                if detail.isLoading(.conciliation) {
                    DetailSectionSkeleton(lines: 3)
                } else {
                    PaymentConciliationView(conciliation: details.conciliation)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.xxxl)   // o cluster flutuante já reserva espaço via safeAreaInset
        }
    }

    // MARK: - Footer actions

    /// Cluster flutuante de ações — a cápsula da ação em voo mostra spinner + verbo; mutação
    /// vinda de outra tela (`store.isMutating`) esmaece o cluster e responde toques com toast.
    @ViewBuilder private var footer: some View {
        if let spec = clusterSpec {
            FloatingActionCluster(
                primary: spec.primary,
                secondary: spec.secondary,
                menuActions: spec.menu,
                inFlightID: inFlightAction,
                blocked: store.isMutating && inFlightAction == nil
            )
        }
    }

    private struct ClusterSpec {
        var primary: FloatingClusterAction
        var secondary: FloatingClusterAction?
        var menu: [FloatingClusterAction] = []
    }

    /// Tags que invalidam o método de pagamento — bloqueiam "Enviar para Liberação" em PAYMENT_FAILED.
    private var hasInvalidPaymentMethodTag: Bool {
        let invalid: Set<String> = ["INVALID_BANKSLIP", "INVALID_PIX", "INVALID_BANK_ACCOUNT"]
        return (details.tags ?? []).contains { invalid.contains($0.type) }
    }

    /// Ações por status — espelha o `switch (status)` do rodapé web (apps/blue/.../footer/index.tsx),
    /// mapeado para o cluster flutuante: primária = a ação [API] principal do status (Liberar /
    /// Enviar para Liberação / Retornar quando é a única real); meio = segunda ação real com
    /// destaque (Retornar em WAITING_APPROVAL); menu (ellipsis) = o resto (alertas "Em Breve",
    /// desabilitadas-com-motivo, Ver Comprovante). Liberar, Enviar para Liberação e Retornar têm
    /// mutação real na mobile-api; as demais (Cancelar, Solicitar Correção, Marcar como Pago,
    /// Pagar Imediatamente, Remover status "Pago", Restaurar) não têm rota mobile e abrem o
    /// alerta "Disponível em Breve".
    private var clusterSpec: ClusterSpec? {
        let d = details
        switch d.status {
        case .provisioned:
            return ClusterSpec(primary: correctionAction)
        case .reserve:
            return nil
        case .pendingBankInfo:
            if d.external {
                return ClusterSpec(
                    primary: sendAction(disabledReason: "Fluxo indisponível em pagamentos com conta pagadora externa"),
                    menu: [markPaidAction, cancelAction()]
                )
            }
            return ClusterSpec(
                primary: sendAction(disabledReason: "Resolva as pendências do pagamento para avançar"),
                menu: [cancelAction()]
            )
        case .paymentFailed:
            return ClusterSpec(
                primary: sendAction(disabledReason: hasInvalidPaymentMethodTag
                    ? "Método de pagamento inválido. Revise as informações bancárias do recebedor."
                    : nil),
                menu: [cancelAction()]
            )
        case .refunded, .readyForApproval:
            return ClusterSpec(primary: sendAction(), menu: [cancelAction()])
        case .waitingApproval:
            if d.canApprove && !d.hasApproved {
                return ClusterSpec(primary: approveAction, secondary: returnAction(),
                                   menu: [cancelAction()])
            }
            return ClusterSpec(primary: returnAction(), menu: [cancelAction()])
        case .approved:
            var menu = [cancelAction()]
            if d.canPayImmediately { menu.insert(payImmediatelyAction, at: 0) }
            return ClusterSpec(primary: returnAction(), menu: menu)
        case .paymentFailedReview, .processing:
            let reason = "Não é possível editar pagamentos durante o seu processamento"
            return ClusterSpec(primary: returnAction(disabledReason: reason),
                               menu: [cancelAction(disabledReason: reason)])
        case .paid:
            if d.external {
                return ClusterSpec(
                    primary: removePaidAction,
                    menu: [comprovanteAction(disabledReason: "Pagamento feito fora da Paggo, sem comprovante disponível")]
                )
            }
            // "Duplicar Pagamento" (web) só aparece após estorno TOTAL + permissão CREATE_PR —
            // o summary nativo não expõe os eventos de estorno, então a ação fica de fora.
            return d.receipts.isEmpty ? nil : ClusterSpec(primary: comprovanteAction())
        case .cancelled:
            return ClusterSpec(primary: restoreAction(enabled: false))
        case .notPayable:
            return ClusterSpec(primary: restoreAction(enabled: true))
        }
    }

    // MARK: Action descriptors

    private var approveAction: FloatingClusterAction {
        .init(id: "approve", label: "Liberar", symbol: "checkmark.circle.fill",
              tone: Theme.positive, inFlightLabel: "Liberando…", onTintLabel: .white) { startApprove() }
    }
    private func sendAction(disabledReason: String? = nil) -> FloatingClusterAction {
        .init(id: "send", label: "Enviar para Liberação", symbol: "paperplane.fill",
              tone: Theme.accent, enabled: disabledReason == nil,
              disabledReason: disabledReason, inFlightLabel: "Enviando…") { sendToApproval() }
    }
    private func returnAction(disabledReason: String? = nil) -> FloatingClusterAction {
        .init(id: "return", label: "Retornar", symbol: "arrow.uturn.backward",
              tone: Theme.warning, enabled: disabledReason == nil,
              disabledReason: disabledReason, inFlightLabel: "Retornando…") { returnToValidation() }
    }
    private func cancelAction(disabledReason: String? = nil) -> FloatingClusterAction {
        .init(id: "cancel", label: "Cancelar Pagamento", symbol: "trash",
              tone: Theme.negative, isDestructive: true, enabled: disabledReason == nil,
              disabledReason: disabledReason) { showSoonAlert = true }
    }
    private var correctionAction: FloatingClusterAction {
        .init(id: "correction", label: "Solicitar Correção", symbol: "arrow.uturn.left.circle",
              tone: Theme.negative) { showSoonAlert = true }
    }
    private var markPaidAction: FloatingClusterAction {
        .init(id: "markPaid", label: "Marcar como Pago", symbol: "checkmark.seal",
              tone: Theme.info) { showSoonAlert = true }
    }
    private var payImmediatelyAction: FloatingClusterAction {
        .init(id: "payNow", label: "Pagar Imediatamente", symbol: "bolt.fill",
              tone: Theme.positive) { showSoonAlert = true }
    }
    private var removePaidAction: FloatingClusterAction {
        .init(id: "removePaid", label: "Remover status \"Pago\"", symbol: "arrow.uturn.backward.circle",
              tone: Theme.warning) { showSoonAlert = true }
    }
    private func restoreAction(enabled: Bool) -> FloatingClusterAction {
        .init(id: "restore", label: "Restaurar Pagamento", symbol: "arrow.clockwise",
              tone: Theme.accent, enabled: enabled) { showSoonAlert = true }
    }
    private func comprovanteAction(disabledReason: String? = nil) -> FloatingClusterAction {
        .init(id: "receipt", label: "Ver Comprovante", symbol: "doc.text.magnifyingglass",
              tone: Theme.info, enabled: disabledReason == nil,
              disabledReason: disabledReason) { showReceipts = true }
    }

    // MARK: - Actions

    private func startApprove() {
        showVerification = true
    }

    private func finishApprove() {
        runFooterAction("approve") { await store.approveSingle(package.id) }
    }

    private func returnToValidation() {
        runFooterAction("return") { await store.returnToValidation(ids: [package.id]) }
    }

    private func sendToApproval() {
        runFooterAction("send") { await store.sendToApproval(ids: [package.id]) }
    }

    /// Executa a mutação sem fire-and-dismiss: spinner + verbo na cápsula que agiu, dismiss SÓ em
    /// sucesso; em falha permanece na tela (o toast global de erro mostra o motivo) para tentar de
    /// novo. Toque com outra mutação em voo (local ou de outra tela) responde com toast — nunca
    /// é engolido em silêncio.
    private func runFooterAction(_ id: String, _ operation: @escaping () async -> Bool) {
        guard inFlightAction == nil, !store.isMutating else {
            toastCenter.show("Aguarde a ação anterior terminar.", style: .info)
            return
        }
        inFlightAction = id
        Task {
            let succeeded = await operation()
            inFlightAction = nil
            if succeeded { dismiss() }
        }
    }
}

/// Lista de comprovantes (metadados) de um pagamento pago. O detalhe bancário completo depende de
/// rota futura na mobile-api — aqui exibimos data + valor de cada comprovante.
struct ReceiptsSheet: View {
    let receipts: [PaymentReceipt]

    var body: some View {
        SheetScaffold(title: "Comprovantes", detents: [.medium, .large]) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(receipts.enumerated()), id: \.element.id) { index, receipt in
                        row(receipt)
                        if index < receipts.count - 1 { Divider().overlay(Theme.separator) }
                    }
                    if receipts.isEmpty {
                        Text("Nenhum comprovante disponível")
                            .font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity).padding(.top, Spacing.xxxl)
                    }
                }
                .padding(.horizontal, Spacing.lg)

                if !receipts.isEmpty {
                    Text("A visualização do comprovante bancário completo chegará em breve.")
                        .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.lg).padding(.top, Spacing.lg)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    private func row(_ receipt: PaymentReceipt) -> some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: "checkmark.seal.fill", tint: Theme.positive, size: 38, symbolSize: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pagamento")
                    .font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textPrimary)
                Text(DateText.full(receipt.paymentDate))
                    .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: Spacing.md)
            Text(receipt.paymentAmount.currencyFromCents())
                .font(.brand(.subheadline, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }
}
