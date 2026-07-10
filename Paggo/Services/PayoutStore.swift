import SwiftUI
import Observation

/// Estado do Payout: carrega pacotes + totais do repositório (mock ou backend), mantém tabs,
/// filtros, ordenação, seleção múltipla e ações em massa. Reads são async com fallback offline
/// (via `LivePayoutRepository` + `QueryClient`); o mock resolve instantâneo.
@MainActor
@Observable
final class PayoutStore: SessionResettable {
    private let repo: PayoutRepository
    private let isLive: Bool

    // Cache mutável por tab (ações em massa movem pacotes entre tabs).
    private(set) var packagesByTab: [PackageTab: [Package]] = [:]
    private(set) var totals = PackageTotals()
    private(set) var isFilteringServerSide = false

    /// Estado de UI por categoria dinâmica de filtro (carregada lazy ao abrir o drawer):
    /// últimas opções válidas (mantidas em falha de refetch), loading e erro.
    struct FilterOptionsState: Sendable {
        var options: [FilterOption]?     // nil = nunca carregada
        var isLoading = false
        var error: String?
        /// Contexto (tab + filtros aplicados) em que as opções foram carregadas. Mismatch =
        /// "sem last-good": o drawer mostra loading/erro em vez de opções de outro contexto.
        var contextSignature: String?
    }
    private(set) var filterOptionsByKey: [String: FilterOptionsState] = [:]

    // Estado de carregamento.
    private(set) var isLoading = false
    private(set) var isReloading = false       // recarga full em andamento (bloqueia loadMore)
    // Single-flight: uma mutação por vez (cross-screen). Exposto para as telas darem feedback
    // (esmaecer clusters/botões + toast "Aguarde…") em vez de engolir toques silenciosamente.
    private(set) var isMutating = false
    private(set) var loadError: String?
    private(set) var isOffline = false
    private(set) var hasLoaded = false

    var selectedTab: PackageTab = .provisioned
    /// Somente `applyFilters` (e `reset`) escrevem — views nunca mutam direto, senão o reload
    /// server-side não dispara (o compare de `serverSignature` fica cego).
    private(set) var filters = PayoutFilters()
    var sortField: SortField = .paymentDate
    var sortDirection: SortDirection = .ascending
    /// O usuário escolheu uma ordenação no SortSheet; senão usa o padrão por tab (paid = desc, resto = asc).
    var hasCustomSort = false

    // Paginação / scroll infinito (por tab).
    static let pageSize = 50
    private(set) var pageByTab: [PackageTab: Int] = [:]
    private(set) var hasMoreByTab: [PackageTab: Bool] = [:]
    private(set) var loadingMoreTab: PackageTab?

    // Seleção múltipla.
    var isSelecting = false
    var selectedIDs: Set<String> = []

    init(repo: PayoutRepository? = nil) {
        self.isLive = AppConfig.current.dataSource == .live
        if let repo {
            self.repo = repo
        } else if isLive {
            self.repo = LivePayoutRepository(api: ServiceContainer.shared.payoutAPI, query: QueryClient.shared)
        } else {
            self.repo = MockPayoutRepository()
        }
        SessionResetRegistry.shared.register(self)
    }

    /// Limpa os pacotes/totais/filtros do usuário atual no signOut. `hasLoaded = false` faz o
    /// próximo login recarregar do zero em vez de servir o cache do usuário anterior.
    func reset() {
        packagesByTab = [:]
        totals = PackageTotals()
        isFilteringServerSide = false
        filterOptionsByKey = [:]
        isLoading = false
        isReloading = false
        isMutating = false
        loadError = nil
        isOffline = false
        hasLoaded = false
        selectedTab = .provisioned
        filters = PayoutFilters()
        sortField = .paymentDate
        sortDirection = .ascending
        hasCustomSort = false
        pageByTab = [:]
        hasMoreByTab = [:]
        loadingMoreTab = nil
        isSelecting = false
        selectedIDs = []
    }

    // MARK: - Carregamento

    /// Carrega todas as tabs + totais. `force` ignora o cache (pull-to-refresh).
    func load(force: Bool = false) async {
        if hasLoaded && !force { return }
        if force { await repo.invalidate() }
        isReloading = true
        defer { isReloading = false }
        isLoading = !hasLoaded
        loadError = nil

        do {
            let repo = repo
            let filters = filters
            // Ordenação por tab (resolvida no MainActor antes do fan-out concorrente).
            let sortByTab = Dictionary(uniqueKeysWithValues: PackageTab.allCases.map { ($0, effectiveSort(for: $0)) })
            var cache: [PackageTab: [Package]] = [:]
            var more: [PackageTab: Bool] = [:]
            try await withThrowingTaskGroup(of: (PackageTab, [Package]).self) { group in
                for tab in PackageTab.allCases {
                    let s = sortByTab[tab]!
                    group.addTask {
                        (tab, try await repo.packages(for: tab, filters: filters, page: 0,
                                                      orderBy: s.orderBy, sort: s.sort))
                    }
                }
                for try await (tab, pkgs) in group {
                    cache[tab] = pkgs
                    more[tab] = pkgs.count == Self.pageSize
                }
            }
            // Totais são best-effort: uma falha aqui não deve zerar a tela de pagamentos.
            let loadedTotals = (try? await repo.totals(filters: filters)) ?? totals
            packagesByTab = cache
            hasMoreByTab = more
            pageByTab = Dictionary(uniqueKeysWithValues: PackageTab.allCases.map { ($0, 0) })
            totals = loadedTotals
            hasLoaded = true
            isOffline = !Connectivity.shared.isOnline
        } catch {
            let apiError = error as? APIError
            isOffline = apiError?.kind == .offline || !Connectivity.shared.isOnline
            loadError = apiError?.userMessage ?? "Não foi possível carregar os pagamentos."
        }
        isLoading = false
    }

    /// Aplica novos filtros. Categorias (server-side) recarregam no live; busca/status/alto valor
    /// são client-side e refletem imediatamente via `packages(for:)`.
    func applyFilters(_ newFilters: PayoutFilters) async {
        let serverChanged = newFilters.serverSignature != filters.serverSignature
        filters = newFilters
        if isLive && serverChanged {
            await load(force: true)
        }
    }

    /// Carrega (lazy) as opções de UMA categoria dinâmica — chamado ao abrir o drawer daquela
    /// categoria (o sheet em si não precisa de opções). O cache real (60s, por tab+filtros) vive
    /// no repositório/QueryClient; aqui fica o estado de UI (loading/erro) e as últimas opções
    /// válidas, mantidas quando um refetch falha.
    func loadFilterOptions(key: String) async {
        guard !PackageFilterOptions.staticOptionKeys.contains(key) else { return }
        let signature = filterContextSignature
        var state = filterOptionsByKey[key] ?? FilterOptionsState()
        // Contexto mudou (outra tab / outros filtros): as opções antigas não são last-good aqui.
        if state.contextSignature != signature {
            state = FilterOptionsState(contextSignature: signature)
        }
        guard !state.isLoading else { return }
        state.isLoading = true
        state.error = nil
        filterOptionsByKey[key] = state
        do {
            state.options = try await repo.filterOptions(key: key, for: selectedTab, filters: filters)
                .sortedByCountDescending()
        } catch {
            state.error = (error as? APIError)?.userMessage ?? "Não foi possível carregar as opções."
        }
        state.isLoading = false
        filterOptionsByKey[key] = state
    }

    /// Estado da categoria para o drawer (loading / erro / opções). Só devolve last-good do
    /// MESMO contexto (tab + filtros) — espelha a chave do QueryClient no repositório.
    func filterOptionsState(for key: String) -> FilterOptionsState {
        guard let state = filterOptionsByKey[key], state.contextSignature == filterContextSignature else {
            return FilterOptionsState()
        }
        return state
    }

    /// Assinatura do contexto atual das opções de filtro (tab + filtros server-side aplicados).
    private var filterContextSignature: String {
        "\(selectedTab.rawValue).\(filters.serverSignature)"
    }

    /// Categorias dinâmicas já carregadas — alimenta rótulos de chips/sumários no sheet de filtros.
    var loadedFilterCategories: [FilterCategory] {
        PackageFilterOptions.order.compactMap { entry in
            guard let options = filterOptionsByKey[entry.key]?.options, !options.isEmpty else { return nil }
            return FilterCategory(key: entry.key, title: entry.title, options: options)
        }
    }

    // MARK: - Paginação / ordenação

    /// Direção padrão por tab: pagos = decrescente, demais = crescente (em paymentDate).
    func defaultDirection(for tab: PackageTab) -> SortDirection { tab == .paid ? .descending : .ascending }

    /// Par (orderBy, sort) a enviar ao servidor para a tab — override do usuário ou padrão por tab.
    private func effectiveSort(for tab: PackageTab) -> (orderBy: String, sort: String) {
        let dir = hasCustomSort ? sortDirection : defaultDirection(for: tab)
        return (sortField.apiOrderBy, dir.apiValue)
    }

    /// Próxima página da tab (scroll infinito). De-duplica por id (a paginação por offset pode
    /// repetir linhas em empates). Quando há refino client-side ativo (busca/alto valor/status),
    /// carrega TODAS as páginas restantes — a busca client-side só enxerga o que já foi carregado.
    func loadMore(_ tab: PackageTab) async {
        guard hasMoreByTab[tab] == true, loadingMoreTab == nil, !isReloading else { return }
        loadingMoreTab = tab
        defer { loadingMoreTab = nil }
        repeat {
            let next = (pageByTab[tab] ?? 0) + 1
            let s = effectiveSort(for: tab)
            guard let more = try? await repo.packages(for: tab, filters: filters, page: next,
                                                      orderBy: s.orderBy, sort: s.sort) else { break }
            let existing = Set((packagesByTab[tab] ?? []).map(\.id))
            let fresh = more.filter { !existing.contains($0.id) }
            if !fresh.isEmpty { packagesByTab[tab, default: []].append(contentsOf: fresh) }
            pageByTab[tab] = next                          // avança mesmo se tudo for duplicado
            hasMoreByTab[tab] = more.count == Self.pageSize
        } while filters.hasClientRefinement && hasMoreByTab[tab] == true
    }

    /// Recarrega TODAS as tabs após o usuário mudar a ordenação (cada tab reordenada no servidor).
    func applySortChange() async {
        hasCustomSort = true
        await load(force: true)
    }

    // MARK: - Leitura

    func rawPackages(for tab: PackageTab) -> [Package] { packagesByTab[tab] ?? [] }

    /// Lista (refino client-side de busca/alto valor/status) — a ordem vem do servidor.
    func packages(for tab: PackageTab) -> [Package] {
        PayoutFiltering.apply(rawPackages(for: tab), filters: filters)
    }

    /// Contagem real da tab (vinda de /packages-totals); cai para o carregado se ainda não houver totais.
    func count(for tab: PackageTab) -> Int {
        tab.bucket(in: totals)?.count ?? rawPackages(for: tab).count
    }

    /// Soma real (em cents) da tab (de /packages-totals); cai para a soma carregada como fallback.
    func totalAmount(for tab: PackageTab) -> Int {
        tab.bucket(in: totals)?.total ?? packages(for: tab).reduce(0) { $0 + $1.paymentAmount }
    }

    /// Detalhes do pacote. Ainda servido pelos mocks — a migração da tela de detalhes
    /// (endpoints por-seção) é o próximo passo (ver docs/BACKEND-INTEGRATION.md).
    func details(for package: Package) -> PackageDetails { MockData.details(for: package) }

    // MARK: - Seleção

    func toggleSelecting() {
        isSelecting.toggle()
        if !isSelecting { selectedIDs.removeAll() }
    }

    func toggle(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    func selectAll(in tab: PackageTab) {
        selectedIDs = Set(packages(for: tab).map(\.id))
    }

    func clearSelection() { selectedIDs.removeAll() }

    // MARK: - Ações em massa / individuais
    // Padrão: snapshot → movimento otimista → request → toast/haptic. Em falha (erro de rede ou
    // falha por-item num HTTP 200), o snapshot é restaurado localmente na hora e, se online,
    // um reconcile em background restaura a verdade do servidor (sucessos parciais do batch).

    /// Liberar (aprovar): Liberação → Agendado.
    @discardableResult
    func approve(ids: Set<String>) async -> Bool {
        guard !ids.isEmpty else { return false }
        let items = packagesByTab.values.flatMap { $0 }
            .filter { ids.contains($0.id) }
            .map { ApprovalInput(id: $0.id, paymentDate: $0.paymentDate) }
        // Ids sem correspondência na lista local (ex.: reconcile removeu a linha) → batch vazio
        // no servidor viraria "sucesso" sem aprovar nada. Falha honesta em vez de POST vazio.
        guard !items.isEmpty else {
            ToastCenter.shared.show("Não foi possível localizar os pagamentos selecionados. Atualize a lista.",
                                    style: .error)
            return false
        }
        return await perform(ids: ids, to: .scheduled, newStatus: .approved,
                             verb: "liberado", verbPlural: "liberados") {
            try await self.repo.approve(items).failureMessage
        }
    }

    /// Retornar para validação: Liberação → Validação.
    @discardableResult
    func returnToValidation(ids: Set<String>) async -> Bool {
        let arr = Array(ids)
        return await perform(ids: ids, to: .validation, newStatus: .readyForApproval,
                             clearApproval: true, verb: "retornado", verbPlural: "retornados") {
            try await self.repo.returnToValidation(ids: arr)
            return nil
        }
    }

    /// Enviar para liberação: Validação → Liberação. Os aprovadores reais chegam no reconcile
    /// pós-sucesso — o movimento otimista não fabrica aprovadores.
    @discardableResult
    func sendToApproval(ids: Set<String>) async -> Bool {
        let arr = Array(ids)
        return await perform(ids: ids, to: .approval, newStatus: .waitingApproval,
                             verb: "enviado para liberação", verbPlural: "enviados para liberação") {
            try await self.repo.sendToApproval(ids: arr).failureMessage
        }
    }

    /// Aprovação individual a partir da tela de detalhes.
    @discardableResult
    func approveSingle(_ id: String) async -> Bool { await approve(ids: [id]) }

    // MARK: - Privados

    /// Fluxo comum das mutações. `action` devolve a mensagem de falha por-item (HTTP 200 com
    /// erros no corpo) ou nil em sucesso; erros lançados também revertem o movimento otimista.
    private func perform(
        ids: Set<String>,
        to: PackageTab,
        newStatus: PackageStatus,
        clearApproval: Bool = false,
        verb: String,
        verbPlural: String,
        action: () async throws -> String?
    ) async -> Bool {
        guard !ids.isEmpty else { return false }
        // Single-flight: um revert de snapshot durante outra mutação em voo clobberaria o
        // movimento otimista dela — os botões por tela já desabilitam, isto fecha o cross-screen.
        guard !isMutating else {
            ToastCenter.shared.show("Aguarde a ação anterior terminar.", style: .info)
            return false
        }
        if isLive && !Connectivity.shared.isOnline {
            ToastCenter.shared.show("Sem conexão. Tente novamente quando estiver online.", style: .info)
            return false
        }
        isMutating = true
        defer { isMutating = false }

        let packagesSnapshot = packagesByTab
        let totalsSnapshot = totals
        move(ids: ids, to: to, newStatus: newStatus, clearApproval: clearApproval)
        selectedIDs.removeAll()
        isSelecting = false

        if isLive {
            do {
                if let failure = try await action() {
                    revert(packages: packagesSnapshot, totals: totalsSnapshot, message: failure)
                    reconcileAfterFailure()
                    return false
                }
            } catch {
                let message = (error as? APIError)?.userMessage ?? "Não foi possível concluir a ação."
                revert(packages: packagesSnapshot, totals: totalsSnapshot, message: message)
                reconcileAfterFailure()
                return false
            }
        }

        let n = ids.count
        ToastCenter.shared.show(n == 1 ? "1 pagamento \(verb)" : "\(n) pagamentos \(verbPlural)")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if isLive && Connectivity.shared.isOnline {
            Task { await load(force: true) }   // reconcile em background com o servidor
        }
        return true
    }

    /// Após falha em que o request pode ter sido processado (falha por-item num HTTP 200,
    /// timeout depois do envio): o revert local dá feedback instantâneo, e este reconcile em
    /// background restaura a verdade do servidor (sucessos parciais). Offline mantém só o revert.
    private func reconcileAfterFailure() {
        guard isLive, Connectivity.shared.isOnline else { return }
        Task { await load(force: true) }
    }

    /// Restaura o snapshot local de forma síncrona (sem rede) — nunca invalida o cache
    /// como mecanismo de revert.
    private func revert(packages: [PackageTab: [Package]], totals: PackageTotals, message: String) {
        packagesByTab = packages
        self.totals = totals
        ToastCenter.shared.show(message, style: .error)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Move os ids para a tab destino a partir da tab onde cada um REALMENTE está — a origem não
    /// é fixa por ação (ex.: "Enviar para Liberação" vale para REFUNDED, que vive em Pendentes;
    /// "Retornar" vale para APPROVED, que vive em Agendados).
    private func move(
        ids: Set<String>,
        to: PackageTab,
        newStatus: PackageStatus,
        clearApproval: Bool = false
    ) {
        guard !ids.isEmpty else { return }
        var dest = packagesByTab[to] ?? []
        // Um cache raro pode ter o MESMO id em mais de uma tab (mudança de status server-side
        // entre os loads concorrentes por tab). O id nunca entra duas vezes no destino —
        // duplicar quebraria o ForEach (Package é Identifiable) e inflaria os totais.
        var insertedIDs = Set(dest.map(\.id))

        for tab in PackageTab.allCases where tab != to {
            guard let list = packagesByTab[tab] else { continue }
            let moving = list.filter { ids.contains($0.id) }
            guard !moving.isEmpty else { continue }
            packagesByTab[tab] = list.filter { !ids.contains($0.id) }

            var insertedCount = 0
            var insertedAmount = 0
            for var pkg in moving where !insertedIDs.contains(pkg.id) {
                insertedIDs.insert(pkg.id)
                pkg.status = newStatus
                if clearApproval { pkg.approval = nil }
                dest.insert(pkg, at: 0)
                insertedCount += 1
                insertedAmount += pkg.paymentAmount
            }
            adjustTotals(from: tab, to: to,
                         removedCount: moving.count,
                         removedAmount: moving.reduce(0) { $0 + $1.paymentAmount },
                         insertedCount: insertedCount,
                         insertedAmount: insertedAmount)
        }

        packagesByTab[to] = dest
    }

    /// Ajuste otimista dos totais (badge/contador) ao mover pacotes entre tabs. Remoções e
    /// inserções contam separado: um id deduplicado sai da origem sem somar de novo no destino.
    private func adjustTotals(from: PackageTab, to: PackageTab,
                              removedCount: Int, removedAmount: Int,
                              insertedCount: Int, insertedAmount: Int) {
        if var b = totals[keyPath: from.bucketKeyPath] {
            b.count = max(0, b.count - removedCount)
            b.total = max(0, b.total - removedAmount)
            totals[keyPath: from.bucketKeyPath] = b
        }
        guard insertedCount > 0 else { return }
        var d = totals[keyPath: to.bucketKeyPath] ?? PackageTotals.Bucket(count: 0, total: 0)
        d.count += insertedCount
        d.total += insertedAmount
        totals[keyPath: to.bucketKeyPath] = d
    }
}
