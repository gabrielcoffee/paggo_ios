import SwiftUI
import Observation

/// Carrega os detalhes de UM pagamento. Mock → monta tudo instantâneo de MockData. Live → semeia do
/// Package base (a tela pinta em t=0) e dispara TODAS as seções em paralelo — o summary é apenas
/// mais um filho concorrente; só o orçamento encadeia nele (flag `consumesBudget`). Cada resposta
/// preenche o `details` progressivamente (skeleton por seção), com cache via `QueryClient`
/// (staleTime 30s) para reentrada instantânea e deduplicação de chamadas em voo.
@MainActor
@Observable
final class PackageDetailStore {
    enum Section: CaseIterable, Sendable {
        case summary, tags, method, allocations, approvers, delivery, budget, conciliation, alerts,
             documents, history
    }

    let package: Package
    private let isLive: Bool
    private let api: PaymentDetailsAPI
    private let query: QueryClient

    private(set) var details: PackageDetails
    private(set) var loadingSections: Set<Section> = []
    private var hasLoaded = false

    init(package: Package) {
        self.package = package
        self.isLive = AppConfig.current.dataSource == .live
        self.api = ServiceContainer.shared.paymentDetailsAPI
        self.query = QueryClient.shared
        self.details = .seed(from: package)
    }

    func isLoading(_ section: Section) -> Bool { loadingSections.contains(section) }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        guard isLive else {
            details = MockData.details(for: package)
            return
        }

        loadingSections = Set(Section.allCases)

        // Todas as seções em paralelo — nada espera o summary. Tempo total =
        // max(summary + orçamento, seção mais lenta).
        async let s: Void = loadSummaryThenBudget()
        async let t: Void = loadSection(.tags)
        async let m: Void = loadSection(.method)
        async let a: Void = loadSection(.allocations)
        async let ap: Void = loadSection(.approvers)
        async let d: Void = loadSection(.delivery)
        async let c: Void = loadSection(.conciliation)
        async let al: Void = loadSection(.alerts)
        async let de: Void = loadSection(.documents)
        async let h: Void = loadSection(.history)
        await s; await t; await m; await a; await ap; await d; await c; await al; await de; await h
    }

    /// Summary define status/valores/flags + `consumesBudget` — a única dependência real do
    /// orçamento. Assim que o summary chega, o orçamento começa imediatamente (sem esperar as
    /// demais seções) ou tem seu skeleton limpo.
    private func loadSummaryThenBudget() async {
        await loadSection(.summary)
        if details.consumesBudget {
            await loadSection(.budget)
        } else {
            loadingSections.remove(.budget)
        }
    }

    /// Envia mensagem no chat do pagamento (POST /payments/{id}/chat) e devolve a mensagem
    /// persistida. Só é chamado no modo live (o mock entrega o eco localmente).
    func sendChatMessage(_ text: String) async throws -> ChatMessage {
        try await ServiceContainer.shared.payoutAPI.createChatMessage(packageId: package.id, message: text)
    }

    // MARK: - Chat (eco local + estado de entrega)
    // Vive no STORE (não na view): o conteúdo das abas é um `switch`, que destrói a view do
    // Histórico (e seu @State) ao trocar de aba — mensagens enviadas sobrevivem à navegação.

    /// Estado de entrega de uma mensagem (eco otimista do envio).
    enum ChatDelivery: Equatable, Sendable { case delivered, sending, failed }

    /// Mensagem local + estado de entrega.
    struct ChatEntry: Identifiable, Equatable, Sendable {
        var message: ChatMessage
        var delivery: ChatDelivery = .delivered
        var id: String { message.id }
    }

    private(set) var chatEntries: [ChatEntry] = []
    private var chatSeeded = false

    /// Semeia o chat (uma única vez). Mock popula de `details.chat`; live é semeado pela seção
    /// `.history` (GET real) no `load()`, então aqui é no-op para não sobrescrever com vazio.
    func seedChatIfNeeded() {
        guard !chatSeeded else { return }
        chatSeeded = true
        guard !isLive else { return }
        chatEntries = (details.chat?.messages ?? []).map { ChatEntry(message: $0) }
    }

    /// Aplica o histórico REAL vindo do GET. Mensagens do servidor entram como entregues;
    /// ecos otimistas ainda pendentes (enviando/falha) que o servidor ainda não conhece são
    /// preservados ao fim (merge por id — o id do eco é local; o do servidor é o timestamp real).
    private func applyHistory(_ messages: [ChatMessage]) {
        let serverIds = Set(messages.map(\.id))
        // Preserva ecos locais (pendentes OU já entregues) que o servidor ainda não reflete — evita
        // sumir com uma mensagem recém-enviada quando o refetch chega antes de o servidor propagá-la.
        let localExtras = chatEntries.filter { !serverIds.contains($0.id) }
        chatEntries = messages.map { ChatEntry(message: $0, delivery: .delivered) } + localExtras
        chatSeeded = true
    }

    /// Eco local imediato + envio real; a bolha mostra "Enviando…" e, em falha, fica marcada
    /// com toque-para-reenviar. Mock: entrega instantânea (sem rede).
    func sendChat(_ message: ChatMessage) {
        chatEntries.append(ChatEntry(message: message, delivery: isLive ? .sending : .delivered))
        if isLive { deliverChat(id: message.id) }
    }

    /// Reenvia a mensagem com aquele id — usado no toque em bolha com falha.
    func retryChat(id: String) {
        guard isLive else { return }
        deliverChat(id: id)
    }

    private func deliverChat(id: String) {
        guard let index = chatEntries.firstIndex(where: { $0.id == id }) else { return }
        chatEntries[index].delivery = .sending
        let text = chatEntries[index].message.text
        Task {
            do {
                let sent = try await sendChatMessage(text)
                upsertSentMessage(localId: id, server: sent)
            } catch {
                setChatDelivery(.failed, id: id)
                ToastCenter.shared.show(
                    (error as? APIError)?.userMessage ?? "Não foi possível enviar a mensagem.",
                    style: .error
                )
            }
        }
    }

    private func setChatDelivery(_ delivery: ChatDelivery, id: String) {
        if let index = chatEntries.firstIndex(where: { $0.id == id }) { chatEntries[index].delivery = delivery }
    }

    /// Substitui o eco otimista pela mensagem real do servidor (id/timestamp corretos), marcando
    /// como entregue. Se o servidor já estiver presente (ex.: histórico revalidou), só remove o eco.
    private func upsertSentMessage(localId: String, server: ChatMessage) {
        let entry = ChatEntry(message: server, delivery: .delivered)
        if let index = chatEntries.firstIndex(where: { $0.id == localId }) {
            if server.id != localId, chatEntries.contains(where: { $0.id == server.id }) {
                chatEntries.remove(at: index)
            } else {
                chatEntries[index] = entry
            }
        } else if !chatEntries.contains(where: { $0.id == server.id }) {
            chatEntries.append(entry)
        }
    }

    /// Pull-to-refresh: invalida o cache do detalhe deste pagamento e refaz o load paralelo.
    /// A reentrada normal (voltar à tela) NÃO invalida — serve do cache em ~0ms.
    func reload() async {
        hasLoaded = false
        if isLive { query.invalidate(prefix: PaymentKeys.detail(package.id)) }
        details = .seed(from: package)
        await load()
    }

    private func loadSection(_ section: Section) async {
        defer { loadingSections.remove(section) }
        let id = package.id
        let api = self.api
        do {
            switch section {
            case .summary:
                try await query.fetch(PaymentKeys.summary(id), staleTime: 30) {
                    try await api.summary(id: id)
                }.apply(to: &details)
            case .tags:
                try await query.fetch(PaymentKeys.tags(id), staleTime: 30) {
                    try await api.tags(id: id)
                }.apply(to: &details)
            case .method:
                try await query.fetch(PaymentKeys.method(id), staleTime: 30) {
                    try await api.methods(id: id)
                }.apply(to: &details)
            case .allocations:
                try await query.fetch(PaymentKeys.allocations(id), staleTime: 30) {
                    try await api.allocations(id: id)
                }.apply(to: &details)
            case .approvers:
                try await query.fetch(PaymentKeys.approvers(id), staleTime: 30) {
                    try await api.approvers(id: id)
                }.apply(to: &details)
            case .delivery:
                try await query.fetch(PaymentKeys.deliveryDocument(id), staleTime: 30) {
                    try await api.delivery(id: id)
                }.apply(to: &details)
            case .budget:
                try await query.fetch(PaymentKeys.budget(id), staleTime: 30) {
                    try await api.budget(id: id)
                }.apply(to: &details)
            case .conciliation:
                try await query.fetch(PaymentKeys.conciliation(id), staleTime: 30) {
                    try await api.conciliation(id: id)
                }.apply(to: &details)
            case .alerts:
                try await query.fetch(PaymentKeys.alerts(id), staleTime: 30) {
                    try await api.alerts(id: id)
                }.apply(to: &details)
            case .documents:
                // Enriquece as entradas semeadas pelo summary com fileUrl + amount (merge-by-id).
                // A mobile-api implantada pode ainda não ter a rota — 404 cai no catch silencioso
                // e a aba segue funcionando só com os metadados do summary.
                try await query.fetch(PaymentKeys.documentEntries(id), staleTime: 30) {
                    try await api.documentEntries(id: id)
                }.apply(to: &details)
            case .history:
                // GET real do chat (JSON cru). A mobile-api implantada pode ainda não ter a rota —
                // 404/erro cai no catch silencioso e o histórico segue vazio até o deploy.
                let messages = try await query.fetch(PaymentKeys.chat(id), staleTime: 30) {
                    try await ServiceContainer.shared.payoutAPI.chatHistory(packageId: id)
                }
                applyHistory(messages)
            }
        } catch {
            // Seção indisponível → fica vazia (a UI mostra "—"/seção vazia). Não derruba a tela.
        }
    }
}

extension PaymentKeys {
    static func documentEntries(_ id: String) -> String { "\(detail(id)).document-entries" }
}
