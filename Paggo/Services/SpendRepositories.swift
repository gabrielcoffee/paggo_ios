import Foundation

// Repositórios das features de spend management (specs 01–06), no mesmo padrão da Carteira:
// protocol Sendable + implementação mock (fixtures/contratos) hoje, Supabase depois.
// Regras server-side das specs (duplo limite, policy, auto-aprovação, declines) moram na
// implementação do repositório — store/view só refletem o resultado.

enum SpendError: Error, Equatable {
    case pendingLimitRequest
    case receiptRequired
    case cannotCancel
    case cardUnavailable
    case notFound

    var userMessage: String {
        switch self {
        case .pendingLimitRequest:
            return "Você já tem um pedido de aumento aguardando decisão neste orçamento."
        case .receiptRequired:
            return "Este valor exige recibo anexado para enviar o reembolso."
        case .cannotCancel:
            return "Só é possível cancelar um reembolso enquanto ele está em análise."
        case .cardUnavailable:
            return "O cartão não está disponível para esta ação."
        case .notFound:
            return "Registro não encontrado. Atualize e tente novamente."
        }
    }
}

/// Orçamentos + memberships + pedidos de aumento (doc 01), escopo do usuário atual.
protocol BudgetRepository: Sendable {
    func budgets() async throws -> [Budget]
    func memberships() async throws -> [BudgetMembership]
    func limitRequests() async throws -> [LimitRequest]
    /// Regra: máx. 1 pendente por membership; `currentLimit` snapshotado no servidor.
    func submitLimitRequest(_ draft: LimitRequestDraft) async throws -> LimitRequest
    func invalidate() async
}

/// Cartão virtual do usuário + feed de transações (doc 02).
protocol CardRepository: Sendable {
    func card() async throws -> CorporateCard?
    func transactions() async throws -> [CardTransaction]
    /// Funcionário congela/descongela; lock de admin/sistema não é destravável por aqui.
    func setFrozen(_ frozen: Bool) async throws -> CorporateCard
    /// Exige Face ID recente (chamador). Cada chamada gera registro de auditoria no servidor.
    func reveal() async throws -> RevealedCardDetails
    func correctCategory(transactionId: String, category: MerchantCategory) async throws
    func invalidate() async
}

/// Reembolsos do usuário (doc 03) — policy flags e auto-aprovação aplicadas no servidor (doc 04).
protocol ReimbursementRepository: Sendable {
    func reimbursements() async throws -> [Reimbursement]
    func submit(_ draft: ReimbursementDraft) async throws -> Reimbursement
    func cancel(id: String) async throws -> Reimbursement
    func invalidate() async
}

/// Policies resolvidas (doc 04): herança budget→global já aplicada.
protocol PolicyRepository: Sendable {
    func resolvedPolicy(budgetId: String?) async throws -> ResolvedPolicy
    func invalidate() async
}

/// Recibos inteligentes (doc 04): OCR roda on-device; o CASAMENTO roda no servidor
/// (valor ±5%, data ±3 dias, sem recibo; exatamente 1 candidata casa sozinha).
protocol ReceiptRepository: Sendable {
    func receipts() async throws -> [SmartReceipt]
    /// Envia o recibo com a leitura OCR; devolve o recibo (matched/unmatched) e, quando
    /// não casou sozinho, as transações candidatas pro casamento manual.
    func submit(url: String, ocr: SmartReceipt.OCR) async throws -> (receipt: SmartReceipt,
                                                                     suggestions: [CardTransaction])
    func match(receiptId: String, transactionId: String) async throws -> SmartReceipt
    func invalidate() async
}

/// Notificações in-app (doc 05).
protocol SpendNotificationRepository: Sendable {
    func notifications() async throws -> [AppNotification]
    func markRead(id: String) async throws
    func markAllRead() async throws
    func invalidate() async
}

/// Assistente (doc 06): leitura direta, mutação via action confirmada.
protocol ChatRepository: Sendable {
    func sessions() async throws -> [AssistantSession]
    func messages(sessionId: String) async throws -> [AssistantMessage]
    func startSession() async throws -> AssistantSession
    /// Envia texto do usuário; devolve as mensagens novas (user + resposta do assistente).
    func send(sessionId: String, text: String) async throws -> [AssistantMessage]
    func updateAction(sessionId: String, messageId: String, actionId: String,
                      status: AssistantAction.Status, result: String?) async throws -> AssistantMessage
    func invalidate() async
}
