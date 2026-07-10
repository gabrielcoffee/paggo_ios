import Foundation

// Contratos do doc 06 (chat-sessions.json / chat-messages.json). Mutações do assistente
// viram `actions` com confirmação obrigatória — a mensagem persistida é a auditoria.

/// Sessão de conversa com o assistente.
struct AssistantSession: Codable, Hashable, Sendable, Identifiable {
    let id: String
    var userId: String
    var title: String
    var createdAt: String
    var updatedAt: String
}

/// Ação proposta pelo assistente dentro de uma mensagem.
struct AssistantAction: Codable, Hashable, Sendable, Identifiable {
    enum Status: String, Codable, Sendable { case proposed, confirmed, executed, failed, dismissed }

    let id: String
    var tool: String                  // freezeCard, requestLimitIncrease, draftReimbursement…
    var params: [String: String]
    var status: Status
    var result: String?
    var confirmedAt: String?
    var executedAt: String?
}

/// Mensagem da conversa (user ou assistant), com ações embutidas.
struct AssistantMessage: Codable, Hashable, Sendable, Identifiable {
    enum Role: String, Codable, Sendable { case user, assistant }

    let id: String
    var sessionId: String
    var role: Role
    var content: String
    var actions: [AssistantAction]
    var createdAt: String
}
