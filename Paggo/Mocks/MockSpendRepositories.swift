import Foundation

/// Servidor de mentira das features de spend management: um único actor guarda TODO o estado
/// (budgets, memberships, cartão, transações, reembolsos, policies, recibos, notificações,
/// chat) e executa as regras que as specs marcam como server-side — duplo limite, policy
/// engine, auto-aprovação, snapshots. Os `Mock*Repository` abaixo são fachadas por domínio
/// sobre este actor; dono único de estado, sem cópias divergentes entre domínios.
actor SpendMockServer {
    static let shared = SpendMockServer()

    private var budgets: [Budget] = []
    private var memberships: [BudgetMembership] = []
    private var limitRequests: [LimitRequest] = []
    private var card: CorporateCard?
    private var cardTransactions: [CardTransaction] = []
    private var reimbursements: [Reimbursement] = []
    private var policies: [SpendPolicy] = []
    private var receipts: [SmartReceipt] = []
    private var notifications: [AppNotification] = []
    private var chatSessions: [AssistantSession] = []
    private var chatMessages: [String: [AssistantMessage]] = [:]
    private var cardReveals: [(cardId: String, at: String)] = []
    private var seeded = false

    private let currentUser = PersonRef(id: "user-1", name: "Igor Souza", email: "igor@paggo.ai")
    private let profilePayoutKey = PayoutKey(type: .cpf, value: "113.036.437-23")

    // MARK: Seed

    private func seedIfNeeded() throws {
        guard !seeded else { return }
        budgets = try WalletFixtureLoader.load("budgets")
        memberships = try WalletFixtureLoader.load("budget-memberships")
        limitRequests = try WalletFixtureLoader.load("limit-requests")
        let cards: [CorporateCard] = try WalletFixtureLoader.load("cards")
        card = cards.first
        cardTransactions = try WalletFixtureLoader.load("card-transactions")
        reimbursements = try WalletFixtureLoader.load("reimbursements")
        policies = try WalletFixtureLoader.load("policies")
        receipts = try WalletFixtureLoader.load("receipts")
        notifications = try WalletFixtureLoader.load("notifications")
        seeded = true
    }

    private func simulateLatency() async {
        try? await Task.sleep(for: .milliseconds(Int.random(in: 250...600)))
    }

    private func now() -> String { Date().isoString }

    // MARK: Budgets (doc 01)

    func allBudgets() async throws -> [Budget] {
        await simulateLatency(); try seedIfNeeded()
        return budgets
    }

    func myMemberships() async throws -> [BudgetMembership] {
        await simulateLatency(); try seedIfNeeded()
        return memberships.filter { $0.employee.id == currentUser.id }
    }

    func myLimitRequests() async throws -> [LimitRequest] {
        await simulateLatency(); try seedIfNeeded()
        return limitRequests.filter { $0.requestedBy.id == currentUser.id }
    }

    func submitLimitRequest(_ draft: LimitRequestDraft) async throws -> LimitRequest {
        await simulateLatency(); try seedIfNeeded()
        guard let membership = memberships.first(where: { $0.id == draft.membershipId }) else {
            throw SpendError.notFound
        }
        // Regra 8 do doc 01: máximo 1 pedido pendente por membership.
        guard !limitRequests.contains(where: { $0.membershipId == membership.id && $0.isPending }) else {
            throw SpendError.pendingLimitRequest
        }
        let budgetTotal = budgets.first { $0.id == membership.budgetId }?.totalLimit ?? 0
        let request = LimitRequest(
            id: "lir-\(UUID().uuidString.prefix(8))",
            membershipId: membership.id,
            budgetId: membership.budgetId,
            requestedBy: PersonRef(id: currentUser.id, name: currentUser.name),
            currentLimit: membership.effectiveLimit(budgetTotal: budgetTotal),
            requestedLimit: draft.requestedLimit,
            kind: draft.kind,
            validUntil: draft.validUntil,
            reason: draft.reason,
            status: .submitted,
            decidedBy: nil, decidedAt: nil, decisionNote: nil,
            createdAt: now()
        )
        limitRequests.insert(request, at: 0)
        return request
    }

    // MARK: Cartão (doc 02)

    func myCard() async throws -> CorporateCard? {
        await simulateLatency(); try seedIfNeeded()
        return card
    }

    func myCardTransactions() async throws -> [CardTransaction] {
        await simulateLatency(); try seedIfNeeded()
        return cardTransactions.sorted { $0.authorizedAt > $1.authorizedAt }
    }

    func setCardFrozen(_ frozen: Bool) async throws -> CorporateCard {
        await simulateLatency(); try seedIfNeeded()
        guard var current = card, current.status == (frozen ? .active : .frozen) else {
            throw SpendError.cardUnavailable
        }
        current.status = frozen ? .frozen : .active
        current.updatedAt = now()
        card = current
        return current
    }

    func revealCard() async throws -> RevealedCardDetails {
        await simulateLatency(); try seedIfNeeded()
        guard let current = card, current.status != .canceled else { throw SpendError.cardUnavailable }
        cardReveals.append((cardId: current.id, at: now()))
        // PAN de teste (prefixo 4111…): marcadamente falso, nunca logado.
        return RevealedCardDetails(cardId: current.id, pan: "4111111111114821", cvv: "382",
                                   expMonth: current.expMonth, expYear: current.expYear)
    }

    func correctTransactionCategory(transactionId: String, category: MerchantCategory) async throws {
        await simulateLatency(); try seedIfNeeded()
        guard let idx = cardTransactions.firstIndex(where: { $0.id == transactionId }) else {
            throw SpendError.notFound
        }
        cardTransactions[idx].merchant.category = category
        cardTransactions[idx].updatedAt = now()
    }

    // MARK: Reembolsos (doc 03) + policy engine (doc 04)

    func myReimbursements() async throws -> [Reimbursement] {
        await simulateLatency(); try seedIfNeeded()
        return reimbursements.sorted { $0.createdAt > $1.createdAt }
    }

    func submitReimbursement(_ draft: ReimbursementDraft) async throws -> Reimbursement {
        await simulateLatency(); try seedIfNeeded()
        let policy = resolvePolicy(budgetId: draft.budgetId)

        // Recibo obrigatório, relaxado por receiptRequiredAbove (doc 04 regra 4).
        let hasReceipt = draft.receiptURL != nil
        if policy.requiresReceipt(for: draft.amount) && !hasReceipt {
            throw SpendError.receiptRequired
        }

        // Violações não bloqueiam reembolso — viram flags pro aprovador (doc 04 matriz).
        var flags: [String] = []
        if policy.exceedsMax(draft.amount) { flags.append("over_max_amount") }
        if policy.blocks(draft.merchantCategory) { flags.append("blocked_category") }

        let budgetRef = draft.budgetId.flatMap { id in
            budgets.first { $0.id == id }.map { EntityRef(id: $0.id, name: $0.name) }
        }
        var item = Reimbursement(
            id: "rmb-\(UUID().uuidString.prefix(8))",
            requester: PersonRef(id: currentUser.id, name: currentUser.name),
            budget: budgetRef,
            packageId: nil,
            merchantCategory: draft.merchantCategory,
            description: draft.description,
            amount: draft.amount,
            currency: "BRL",
            expenseDate: draft.expenseDate,
            receipt: draft.receiptURL.map { Reimbursement.Receipt(status: "attached", url: $0) },
            status: .submitted,
            policyFlags: flags.isEmpty ? nil : flags,
            estimatedPaymentDate: nil, paidAt: nil,
            payoutKey: profilePayoutKey,
            decidedBy: nil, decidedAt: nil, decisionNote: nil,
            createdAt: now(), updatedAt: now()
        )

        // Auto-aprovação (doc 04 regra 3): abaixo do teto, sem flags, com recibo.
        if policy.autoApproves(amount: draft.amount, hasFlags: !flags.isEmpty, hasReceipt: hasReceipt) {
            item = approve(item, by: PersonRef(id: "system", name: "Política"))
        }

        reimbursements.insert(item, at: 0)
        return item
    }

    /// Aprovação: consome o budget (compromisso) e cria o package na esteira (doc 03 regra 2/3).
    private func approve(_ reimbursement: Reimbursement, by decider: PersonRef) -> Reimbursement {
        var item = reimbursement
        item.status = .approved
        item.decidedBy = decider
        item.decidedAt = now()
        item.estimatedPaymentDate = Date().adding(days: 2).isoString
        item.packageId = "pkg-\(UUID().uuidString.prefix(8))"
        if let budgetId = item.budget?.id,
           let idx = memberships.firstIndex(where: { $0.budgetId == budgetId && $0.employee.id == item.requester.id }) {
            memberships[idx].consumed += item.amount
            memberships[idx].updatedAt = now()
        }
        item.updatedAt = now()
        return item
    }

    func cancelReimbursement(id: String) async throws -> Reimbursement {
        await simulateLatency(); try seedIfNeeded()
        guard let idx = reimbursements.firstIndex(where: { $0.id == id }) else { throw SpendError.notFound }
        guard reimbursements[idx].canCancel else { throw SpendError.cannotCancel }
        reimbursements[idx].status = .canceled
        reimbursements[idx].updatedAt = now()
        return reimbursements[idx]
    }

    // MARK: Policies (doc 04)

    private func resolvePolicy(budgetId: String?) -> ResolvedPolicy {
        let global = policies.first { $0.isGlobal }
        let scoped = budgetId.flatMap { id in policies.first { $0.scope.budgetId == id } }
        return ResolvedPolicy.resolve(global: global, budget: scoped)
    }

    func resolvedPolicy(budgetId: String?) async throws -> ResolvedPolicy {
        await simulateLatency(); try seedIfNeeded()
        return resolvePolicy(budgetId: budgetId)
    }


    // MARK: Recibos (doc 04) — matching server-side

    /// Candidatas ao casamento: transações do usuário com valor ±5%, data ±3 dias, sem recibo.
    private func matchCandidates(for ocr: SmartReceipt.OCR) -> [CardTransaction] {
        cardTransactions.filter { tx in
            guard tx.countsAsSpend, tx.receiptStatus == .missing else { return false }
            if let amount = ocr.amount {
                let tolerance = Double(amount) * 0.05
                guard abs(Double(tx.effectiveAmount - amount)) <= tolerance else { return false }
            }
            if let dateText = ocr.date, let ocrDate = DateText.parse(dateText),
               let txDate = DateText.parse(tx.authorizedAt) {
                let days = abs(ocrDate.timeIntervalSince(txDate)) / 86_400
                guard days <= 3 else { return false }
            }
            return true
        }
    }

    func allReceipts() async throws -> [SmartReceipt] {
        await simulateLatency(); try seedIfNeeded()
        return receipts.sorted { $0.createdAt > $1.createdAt }
    }

    func submitReceipt(url: String, ocr: SmartReceipt.OCR) async throws -> (SmartReceipt, [CardTransaction]) {
        await simulateLatency(); try seedIfNeeded()
        let candidates = matchCandidates(for: ocr)
        var receipt = SmartReceipt(
            id: "rcp-\(UUID().uuidString.prefix(8))",
            uploadedBy: PersonRef(id: currentUser.id, name: currentUser.name),
            url: url, ocr: ocr, match: nil, status: .unmatched,
            createdAt: now(), updatedAt: now()
        )
        // Exatamente 1 candidata → casa automático (doc 04 regra 6).
        if candidates.count == 1, let target = candidates.first {
            receipt.match = SmartReceipt.Match(type: "cardTransaction", id: target.id, method: "auto")
            receipt.status = .matched
            markReceiptAttached(transactionId: target.id)
            receipts.insert(receipt, at: 0)
            return (receipt, [])
        }
        receipts.insert(receipt, at: 0)
        return (receipt, candidates)
    }

    func matchReceipt(receiptId: String, transactionId: String) async throws -> SmartReceipt {
        await simulateLatency(); try seedIfNeeded()
        guard let idx = receipts.firstIndex(where: { $0.id == receiptId }) else {
            throw SpendError.notFound
        }
        receipts[idx].match = SmartReceipt.Match(type: "cardTransaction", id: transactionId, method: "manual")
        receipts[idx].status = .matched
        receipts[idx].updatedAt = now()
        markReceiptAttached(transactionId: transactionId)
        return receipts[idx]
    }

    private func markReceiptAttached(transactionId: String) {
        guard let idx = cardTransactions.firstIndex(where: { $0.id == transactionId }) else { return }
        cardTransactions[idx].receiptStatus = .attached
        cardTransactions[idx].updatedAt = now()
    }

    // MARK: Notificações (doc 05)

    func myNotifications() async throws -> [AppNotification] {
        await simulateLatency(); try seedIfNeeded()
        return notifications.sorted { $0.createdAt > $1.createdAt }
    }

    func markNotificationRead(id: String) async throws {
        try seedIfNeeded()
        guard let idx = notifications.firstIndex(where: { $0.id == id }) else { return }
        if notifications[idx].readAt == nil { notifications[idx].readAt = now() }
    }

    func markAllNotificationsRead() async throws {
        try seedIfNeeded()
        for idx in notifications.indices where notifications[idx].readAt == nil {
            notifications[idx].readAt = now()
        }
    }

    // MARK: Chat (doc 06) — motor roteirizado; troca por Edge Function sem mudar a UI.

    func chatSessions() async throws -> [AssistantSession] {
        await simulateLatency(); try seedIfNeeded()
        return chatSessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    func chatMessages(sessionId: String) async throws -> [AssistantMessage] {
        try seedIfNeeded()
        return chatMessages[sessionId] ?? []
    }

    func startChatSession() async throws -> AssistantSession {
        try seedIfNeeded()
        let session = AssistantSession(id: "chs-\(UUID().uuidString.prefix(8))", userId: currentUser.id,
                                  title: "Nova conversa", createdAt: now(), updatedAt: now())
        chatSessions.insert(session, at: 0)
        chatMessages[session.id] = []
        return session
    }

    func sendChat(sessionId: String, text: String) async throws -> [AssistantMessage] {
        await simulateLatency(); try seedIfNeeded()
        let userMessage = AssistantMessage(id: "msg-\(UUID().uuidString.prefix(8))", sessionId: sessionId,
                                      role: .user, content: text, actions: [], createdAt: now())
        let reply = scriptedReply(to: text, sessionId: sessionId)
        chatMessages[sessionId, default: []].append(contentsOf: [userMessage, reply])
        if let idx = chatSessions.firstIndex(where: { $0.id == sessionId }) {
            chatSessions[idx].updatedAt = now()
            if chatSessions[idx].title == "Nova conversa" {
                chatSessions[idx].title = String(text.prefix(38))
            }
        }
        return [userMessage, reply]
    }

    func updateChatAction(sessionId: String, messageId: String, actionId: String,
                          status: AssistantAction.Status, result: String?) async throws -> AssistantMessage {
        try seedIfNeeded()
        guard var list = chatMessages[sessionId],
              let mIdx = list.firstIndex(where: { $0.id == messageId }),
              let aIdx = list[mIdx].actions.firstIndex(where: { $0.id == actionId }) else {
            throw SpendError.notFound
        }
        list[mIdx].actions[aIdx].status = status
        list[mIdx].actions[aIdx].result = result
        switch status {
        case .confirmed: list[mIdx].actions[aIdx].confirmedAt = now()
        case .executed, .failed: list[mIdx].actions[aIdx].executedAt = now()
        default: break
        }
        chatMessages[sessionId] = list
        return list[mIdx]
    }

    /// Intents por palavra-chave sobre o estado real do servidor (mesma leitura da UI).
    private func scriptedReply(to text: String, sessionId: String) -> AssistantMessage {
        let lowered = text.lowercased()
        var content: String
        var actions: [AssistantAction] = []

        if lowered.contains("congela") || lowered.contains("congelar") {
            content = "Posso congelar seu cartão \(card.map { "•••• \($0.last4)" } ?? "") agora — compras serão recusadas até você descongelar. Confirma?"
            actions = [AssistantAction(id: "act-\(UUID().uuidString.prefix(8))", tool: "freezeCard",
                                  params: ["cardId": card?.id ?? ""], status: .proposed,
                                  result: nil, confirmedAt: nil, executedAt: nil)]
        } else if lowered.contains("descongela") {
            content = "Descongelo seu cartão e as compras voltam a funcionar. Confirma?"
            actions = [AssistantAction(id: "act-\(UUID().uuidString.prefix(8))", tool: "unfreezeCard",
                                  params: ["cardId": card?.id ?? ""], status: .proposed,
                                  result: nil, confirmedAt: nil, executedAt: nil)]
        } else if lowered.contains("orçamento") || lowered.contains("orcamento") || lowered.contains("sobrou")
                    || lowered.contains("limite") {
            let lines = memberships.filter { $0.employee.id == currentUser.id }.map { m -> String in
                let budget = budgets.first { $0.id == m.budgetId }
                let total = budget?.totalLimit ?? 0
                let remaining = m.remaining(budgetTotal: total)
                return "• \(budget?.name ?? m.budgetId): \(remaining.currencyFromCents()) restantes de \(m.effectiveLimit(budgetTotal: total).currencyFromCents())"
            }
            content = lines.isEmpty ? "Você ainda não participa de nenhum orçamento."
                                    : "Seus orçamentos neste período:\n" + lines.joined(separator: "\n")
        } else {
            content = "Posso responder sobre seus orçamentos e gastos, congelar/descongelar o cartão ou preparar um reembolso. O que você precisa?"
        }

        return AssistantMessage(id: "msg-\(UUID().uuidString.prefix(8))", sessionId: sessionId,
                           role: .assistant, content: content, actions: actions, createdAt: now())
    }
}

// MARK: - Fachadas por domínio (implementam os protocolos sobre o servidor único)

struct MockBudgetRepository: BudgetRepository {
    func budgets() async throws -> [Budget] { try await SpendMockServer.shared.allBudgets() }
    func memberships() async throws -> [BudgetMembership] { try await SpendMockServer.shared.myMemberships() }
    func limitRequests() async throws -> [LimitRequest] { try await SpendMockServer.shared.myLimitRequests() }
    func submitLimitRequest(_ draft: LimitRequestDraft) async throws -> LimitRequest {
        try await SpendMockServer.shared.submitLimitRequest(draft)
    }
    func invalidate() async {}
}

struct MockCardRepository: CardRepository {
    func card() async throws -> CorporateCard? { try await SpendMockServer.shared.myCard() }
    func transactions() async throws -> [CardTransaction] { try await SpendMockServer.shared.myCardTransactions() }
    func setFrozen(_ frozen: Bool) async throws -> CorporateCard {
        try await SpendMockServer.shared.setCardFrozen(frozen)
    }
    func reveal() async throws -> RevealedCardDetails { try await SpendMockServer.shared.revealCard() }
    func correctCategory(transactionId: String, category: MerchantCategory) async throws {
        try await SpendMockServer.shared.correctTransactionCategory(transactionId: transactionId, category: category)
    }
    func invalidate() async {}
}

struct MockReimbursementRepository: ReimbursementRepository {
    func reimbursements() async throws -> [Reimbursement] { try await SpendMockServer.shared.myReimbursements() }
    func submit(_ draft: ReimbursementDraft) async throws -> Reimbursement {
        try await SpendMockServer.shared.submitReimbursement(draft)
    }
    func cancel(id: String) async throws -> Reimbursement {
        try await SpendMockServer.shared.cancelReimbursement(id: id)
    }
    func invalidate() async {}
}

struct MockPolicyRepository: PolicyRepository {
    func resolvedPolicy(budgetId: String?) async throws -> ResolvedPolicy {
        try await SpendMockServer.shared.resolvedPolicy(budgetId: budgetId)
    }
    func invalidate() async {}
}


struct MockReceiptRepository: ReceiptRepository {
    func receipts() async throws -> [SmartReceipt] { try await SpendMockServer.shared.allReceipts() }
    func submit(url: String, ocr: SmartReceipt.OCR) async throws -> (receipt: SmartReceipt,
                                                                     suggestions: [CardTransaction]) {
        let (receipt, suggestions) = try await SpendMockServer.shared.submitReceipt(url: url, ocr: ocr)
        return (receipt, suggestions)
    }
    func match(receiptId: String, transactionId: String) async throws -> SmartReceipt {
        try await SpendMockServer.shared.matchReceipt(receiptId: receiptId, transactionId: transactionId)
    }
    func invalidate() async {}
}

struct MockSpendNotificationRepository: SpendNotificationRepository {
    func notifications() async throws -> [AppNotification] { try await SpendMockServer.shared.myNotifications() }
    func markRead(id: String) async throws { try await SpendMockServer.shared.markNotificationRead(id: id) }
    func markAllRead() async throws { try await SpendMockServer.shared.markAllNotificationsRead() }
    func invalidate() async {}
}

struct MockChatRepository: ChatRepository {
    func sessions() async throws -> [AssistantSession] { try await SpendMockServer.shared.chatSessions() }
    func messages(sessionId: String) async throws -> [AssistantMessage] {
        try await SpendMockServer.shared.chatMessages(sessionId: sessionId)
    }
    func startSession() async throws -> AssistantSession { try await SpendMockServer.shared.startChatSession() }
    func send(sessionId: String, text: String) async throws -> [AssistantMessage] {
        try await SpendMockServer.shared.sendChat(sessionId: sessionId, text: text)
    }
    func updateAction(sessionId: String, messageId: String, actionId: String,
                      status: AssistantAction.Status, result: String?) async throws -> AssistantMessage {
        try await SpendMockServer.shared.updateChatAction(sessionId: sessionId, messageId: messageId,
                                                          actionId: actionId, status: status, result: result)
    }
    func invalidate() async {}
}
