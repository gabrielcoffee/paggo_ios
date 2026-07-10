import SwiftUI

/// Lista de pagamentos com tabs por status, filtros, ordenação, multi-seleção e ações em massa.
struct PaymentsView: View {
    @Environment(PayoutStore.self) private var store
    @Environment(AuthStore.self) private var auth
    @State private var showFilters = false
    @State private var showSort = false
    @State private var showCardSettings = false
    @State private var sortSnapshot: String?
    @State private var showBulkApproveGate = false   // 2FA (Face ID / OTP) obrigatório antes de liberar
    @State private var bulkInFlight: String?     // id da ação em massa em voo ("approve"/"send"/"return")
    @State private var bulkCount = 0             // contagem capturada ao iniciar (a seleção limpa otimista)
    @State private var bulkActingAction: BulkAction?   // cluster capturado ao iniciar — congela o spec em voo

    /// Discrimina a ação em massa disparada.
    private enum BulkConfirm {
        case approve, send, returnToValidation
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            VStack(spacing: 0) {
                PaymentTabsBar(selection: $store.selectedTab, counts: counts)
                if store.isOffline && store.hasLoaded { offlineBanner }
                content
            }
            .screenBackground()
            .navigationTitle("Pagamentos")
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) { selectionCluster }
            .task { await store.load() }
            .task {
                // Debug: PAGGO_OPEN_FILTERS=1 abre o sheet de filtros (verificação de UI).
                if ProcessInfo.processInfo.environment["PAGGO_OPEN_FILTERS"] == "1" {
                    showFilters = true
                }
                // Debug: PAGGO_SELECT=1 entra em modo seleção com itens marcados (verificação de UI).
                if ProcessInfo.processInfo.environment["PAGGO_SELECT"] == "1" {
                    await store.load()
                    store.selectedTab = .approval
                    store.isSelecting = true
                    store.selectedIDs = Set(store.packages(for: .approval).prefix(3).map(\.id))
                }
            }
            .sheet(isPresented: $showFilters) {
                // Opções por categoria carregam lazy dentro de cada drawer (FilterDrawerView);
                // o sheet só precisa dos rótulos das categorias já carregadas.
                FilterSheetView(
                    currentFilters: store.filters,
                    statusOptions: PayoutFiltering.statusOptions(store.rawPackages(for: store.selectedTab)),
                    categories: store.loadedFilterCategories,
                    onApply: { applied in Task { await store.applyFilters(applied) } }
                )
            }
            .sheet(isPresented: $showSort) {
                SortSheet(field: $store.sortField, direction: $store.sortDirection)
            }
            .sheet(isPresented: $showCardSettings) {
                PaymentCardSettingsSheet()
            }
            .sheet(isPresented: $showBulkApproveGate) {
                TwoFactorSheet(
                    title: "Liberar pagamentos",
                    reason: "Confirme sua identidade para liberar os pagamentos",
                    email: auth.activeUser?.email ?? auth.savedUser?.email ?? "",
                    onVerified: { runBulk(.approve) },
                    onCancel: {}
                )
                .presentationDetents([.height(480), .large])
                .presentationBackground(.ultraThinMaterial)
            }
            .onChange(of: showSort) { _, showing in
                // Recarrega (todas as tabs) só ao fechar o SortSheet e se a ordenação mudou —
                // coalesce campo+direção numa única recarga e evita corrida com loadMore.
                let current = "\(store.sortField.rawValue)|\(store.sortDirection)"
                if showing {
                    sortSnapshot = current
                } else if sortSnapshot != current {
                    Task { await store.applySortChange() }
                }
            }
        }
    }

    private var counts: [PackageTab: Int] {
        Dictionary(uniqueKeysWithValues: PackageTab.allCases.map { ($0, store.count(for: $0)) })
    }

    private var tab: PackageTab { store.selectedTab }
    private var packages: [Package] { store.packages(for: tab) }

    // MARK: Content / load states

    @ViewBuilder private var content: some View {
        if store.isLoading && !store.hasLoaded {
            loadingState
        } else if let error = store.loadError, !store.hasLoaded {
            errorState(error)
        } else {
            VStack(spacing: 0) {
                summaryRow
                list
            }
        }
    }

    private var loadingState: some View {
        ScrollView {
            PackageListSkeleton(count: 7, showApprovers: tab == .approval)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
        }
        .scrollDisabled(true)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34))
                .foregroundStyle(Theme.textTertiary)
            Text(message)
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Tentar novamente") { Task { await store.load(force: true) } }
                .buttonStyle(PrimaryActionStyle())
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var offlineBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "wifi.slash").font(.system(size: 12, weight: .semibold))
            Text("Modo offline — exibindo dados salvos")
                .font(.brand(.caption, weight: .medium))
        }
        .foregroundStyle(Theme.warning)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(Theme.warning.opacity(0.10))
    }

    // MARK: Summary

    // Com refino client-side ativo, o cabeçalho reflete a lista visível; senão, o total real da tab.
    private var summaryCount: Int {
        store.filters.hasClientRefinement ? packages.count : store.count(for: tab)
    }
    private var summaryAmount: Int {
        store.filters.hasClientRefinement
            ? packages.reduce(0) { $0 + $1.paymentAmount }
            : store.totalAmount(for: tab)
    }

    private var summaryRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(summaryCount) pagamentos")
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(summaryAmount.currencyFromCents())
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
            Spacer()
            if store.filters.isActive {
                Button {
                    Task { await store.applyFilters(PayoutFilters()) }
                } label: {
                    Label("\(store.filters.activeCount) filtro(s)", systemImage: "xmark.circle.fill")
                        .font(.brand(.caption, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: List

    private var list: some View {
        ScrollView {
            if packages.isEmpty {
                if store.hasMoreByTab[tab] == true {
                    // Refino client-side pode ter zerado a página atual — segue paginando até achar/acabar.
                    loadingMoreState
                        .onAppear { Task { await store.loadMore(tab) } }
                } else {
                    emptyState
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(packages.enumerated()), id: \.element.id) { index, package in
                        row(for: package)
                            .onAppear {
                                if index == packages.count - 1 {
                                    Task { await store.loadMore(tab) }
                                }
                            }
                        if index < packages.count - 1 {
                            Divider().overlay(Theme.separator)
                                .padding(.horizontal, Spacing.lg)
                        }
                    }
                    if store.loadingMoreTab == tab {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.lg)
                    }
                }
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxxl)
                .animation(.snappy, value: packages)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await store.load(force: true) }
    }

    @ViewBuilder
    private func row(for package: Package) -> some View {
        if store.isSelecting {
            Button {
                withAnimation(.snappy) { store.toggle(package.id) }
            } label: {
                PackageCardView(
                    package: package,
                    isSelecting: true,
                    isSelected: store.selectedIDs.contains(package.id),
                    showApprovers: tab == .approval,
                    horizontalInset: Spacing.lg
                )
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                PackageDetailView(package: package)
            } label: {
                PackageCardView(package: package, showApprovers: tab == .approval, horizontalInset: Spacing.lg)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundStyle(Theme.textTertiary)
            Text(store.filters.isActive ? "Nenhum pagamento com esses filtros" : "Nenhum pagamento nesta aba")
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxxl * 2)
    }

    private var loadingMoreState: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
            Text("Carregando…")
                .font(.brand(.caption))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxxl * 2)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if store.isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                let allSelected = !packages.isEmpty && store.selectedIDs.count == packages.count
                Button(allSelected ? "Limpar" : "Selecionar todos") {
                    withAnimation(.snappy) {
                        if allSelected { store.clearSelection() } else { store.selectAll(in: tab) }
                    }
                }
                .font(.brand(.subheadline, weight: .medium))
            }
            ToolbarItem(placement: .principal) {
                Text("\(store.selectedIDs.count) selecionado(s)")
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancelar") { withAnimation(.snappy) { store.toggleSelecting() } }
                    .font(.brand(.subheadline, weight: .medium))
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCardSettings = true } label: { Image(systemName: "slider.horizontal.3") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSort = true } label: { Image(systemName: "arrow.up.arrow.down") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showFilters = true } label: {
                    Image(systemName: store.filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
            if tab.bulkAction != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.snappy) { store.toggleSelecting() }
                    } label: {
                        Text("Selecionar").font(.brand(.subheadline, weight: .medium))
                    }
                }
            }
        }
    }

    // MARK: Selection floating actions (liquid-glass, bottom-right)

    /// Cluster de ações em massa — visível durante a seleção e também enquanto a ação roda
    /// (a seleção limpa otimista no início da mutação; o cluster fica para mostrar o spinner).
    /// Em voo, renderiza o spec CONGELADO capturado ao confirmar (ação + contagem) — trocar de
    /// tab durante a mutação não pode trocar rótulo/contagem nem sumir com o indicador.
    @ViewBuilder
    private var selectionCluster: some View {
        if bulkInFlight != nil, let acting = bulkActingAction {
            bulkCluster(for: acting, count: bulkCount)
        } else if bulkInFlight == nil, let action = tab.bulkAction,
                  store.isSelecting, !store.selectedIDs.isEmpty {
            bulkCluster(for: action, count: store.selectedIDs.count)
        }
    }

    private func bulkCluster(for action: BulkAction, count: Int) -> some View {
        FloatingActionCluster(
            primary: primaryBulkAction(action, count: count),
            secondary: action == .approve ? returnBulkAction : nil,
            inFlightID: bulkInFlight,
            blocked: store.isMutating && bulkInFlight == nil
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func primaryBulkAction(_ action: BulkAction, count: Int) -> FloatingClusterAction {
        switch action {
        case .approve:
            return .init(id: "approve", label: "\(action.primaryLabel) (\(count))",
                         symbol: "checkmark.circle.fill", tone: Theme.positive,
                         inFlightLabel: "Liberando…", onTintLabel: .white) { showBulkApproveGate = true }
        case .sendToApproval:
            return .init(id: "send", label: "\(action.primaryLabel) (\(count))",
                         symbol: "paperplane.fill", tone: Theme.accent,
                         inFlightLabel: "Enviando…") { runBulk(.send) }
        }
    }

    private var returnBulkAction: FloatingClusterAction {
        .init(id: "return", label: "Retornar", symbol: "arrow.uturn.backward",
              tone: Theme.warning, inFlightLabel: "Retornando…") { runBulk(.returnToValidation) }
    }

    // MARK: Bulk execution

    /// Roda a mutação em massa, com estado de voo visível no cluster. Toques durante
    /// outra mutação (desta ou de outra tela) respondem com toast — nunca somem em silêncio.
    private func runBulk(_ confirm: BulkConfirm) {
        guard bulkInFlight == nil, !store.isMutating else {
            ToastCenter.shared.show("Aguarde a ação anterior terminar.", style: .info)
            return
        }
        let ids = store.selectedIDs
        bulkCount = ids.count
        bulkInFlight = confirm == .returnToValidation ? "return" : (confirm == .approve ? "approve" : "send")
        // "Retornar" vive no cluster de Liberação (.approve) como ação secundária.
        bulkActingAction = confirm == .send ? .sendToApproval : .approve
        Task {
            switch confirm {
            case .approve: _ = await store.approve(ids: ids)
            case .send: _ = await store.sendToApproval(ids: ids)
            case .returnToValidation: _ = await store.returnToValidation(ids: ids)
            }
            bulkInFlight = nil
            bulkActingAction = nil
        }
    }
}
