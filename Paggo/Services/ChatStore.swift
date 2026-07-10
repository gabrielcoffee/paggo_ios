import Foundation
import Observation

/// Estado do assistente: sessões + mensagens da sessão aberta. Mutações propostas pelo
/// assistente só executam após confirmação do usuário (doc 06 regra 2) — a execução em si
/// é disparada pela tela, nos mesmos stores da UI, e o resultado volta pra cá via `updateAction`.
@MainActor
@Observable
final class ChatStore: SessionResettable {
    private let repo: ChatRepository

    private(set) var sessions: [AssistantSession] = []
    private(set) var currentSession: AssistantSession?
    private(set) var messages: [AssistantMessage] = []
    private(set) var isSending = false
    private(set) var loadError: String?
    private(set) var hasLoaded = false

    init(repo: ChatRepository = ServiceContainer.shared.chatRepository) {
        self.repo = repo
        SessionResetRegistry.shared.register(self)
    }

    func reset() {
        sessions = []
        currentSession = nil
        messages = []
        isSending = false
        loadError = nil
        hasLoaded = false
    }

    func load(force: Bool = false) async {
        if hasLoaded && !force { return }
        if force { await repo.invalidate() }
        loadError = nil
        do {
            sessions = try await repo.sessions()
            hasLoaded = true
        } catch {
            loadError = (error as? SpendError)?.userMessage ?? "Não foi possível carregar as conversas."
        }
    }

    func open(_ session: AssistantSession) async {
        currentSession = session
        messages = (try? await repo.messages(sessionId: session.id)) ?? []
    }

    func startSession() async {
        guard let session = try? await repo.startSession() else { return }
        currentSession = session
        messages = []
        await load(force: true)
    }

    func send(_ text: String) async {
        guard let session = currentSession, !text.isEmpty, !isSending else { return }
        isSending = true
        defer { isSending = false }
        if let new = try? await repo.send(sessionId: session.id, text: text) {
            messages.append(contentsOf: new)
        }
    }

    /// Atualiza o estado de uma ação (confirmar/executar/falhar/dispensar) e reflete na conversa.
    func updateAction(messageId: String, actionId: String,
                      status: AssistantAction.Status, result: String? = nil) async {
        guard let session = currentSession else { return }
        if let updated = try? await repo.updateAction(sessionId: session.id, messageId: messageId,
                                                      actionId: actionId, status: status, result: result),
           let idx = messages.firstIndex(where: { $0.id == updated.id }) {
            messages[idx] = updated
        }
    }
}
