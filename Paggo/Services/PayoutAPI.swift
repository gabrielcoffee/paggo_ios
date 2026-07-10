import Foundation

// Camada de dados "live" do Payout — espelha 1:1 `data/services/payout/payout.service.ts`.
// Serviço PURO de rede (sem cache); o cache/offline é aplicado por cima via `QueryClient`,
// e mutações offline via `Outbox` (ver docs/BACKEND-INTEGRATION.md).

// MARK: - DTOs de request/response (portados das interfaces do payout.service.ts)

/// `ApprovePackagesDto` → `{ packages: [{ id, paymentDate }] }`
struct ApprovePackagesRequest: Encodable, Sendable {
    struct Item: Encodable, Sendable { let id: String; let paymentDate: String }
    let packages: [Item]
}

/// `CancelApprovalDto` / `SendToApprovalDto` → `{ packageIds: [...] }`
struct PackageIdsRequest: Encodable, Sendable {
    let packageIds: [String]
}

/// Corpo de POST /payments/{id}/chat → `{ text, type }` (rota canônica do chat do pagamento).
struct CreateChatMessageRequest: Encodable, Sendable {
    let text: String
    let type: String
}

/// Mensagem do chat vinda da mobile-api (subset — campos extras são ignorados). Decode TOLERANTE
/// (tudo opcional) para não quebrar antes do deploy do backend.
struct RemoteChatMessage: Decodable, Sendable {
    let id: String?
    let createdAt: String?
    let text: String?
    let type: String?
    let flag: String?
    let userId: String?
    let user: RemoteUser?

    struct RemoteUser: Decodable, Sendable {
        let id: String?
        let name: String?
        let avatar: String?
    }

    /// Converte para o modelo de exibição. `type == "EVENT"` vira pílula de sistema usando o
    /// `flag` como tipo (paridade com o web, onde os platformTypes SÃO os flags); qualquer outro
    /// tipo vira bolha de conversa. `user.id` alimenta o teste enviado/recebido feito na view.
    func toChatMessage() -> ChatMessage {
        let appType = type == "EVENT" ? (flag ?? "EVENT") : (type ?? "USER_MESSAGE")
        let resolvedUserId = user?.id ?? userId
        let chatUser = resolvedUserId.map {
            ChatMessage.ChatUser(id: $0, name: user?.name ?? "", email: nil, image: user?.avatar)
        }
        return ChatMessage(serverId: id, text: text ?? "", createdAt: createdAt ?? "", type: appType, user: chatUser)
    }
}

/// Resposta de GET /payments/{id}/chat — JSON cru (sem envelope), mensagens ASC (antigas→novas).
struct ChatHistoryResponse: Decodable, Sendable {
    let messages: [RemoteChatMessage]?
    let pagination: Pagination?

    struct Pagination: Decodable, Sendable {
        let cursor: String?
        let hasNextPage: Bool?
    }
}

/// Resposta de POST /payments/{id}/chat.
struct CreateChatMessageResponse: Decodable, Sendable {
    let message: RemoteChatMessage?
}

/// `ApprovePackagesResponseDto` → `{ status, message, total?, errors?: [{ id, success, message, code }] }`.
/// HTTP 200 pode carregar falhas por-item em `errors` — o app trata como falha da ação.
struct BatchActionResponse: Decodable, Sendable {
    let status: Int?
    let message: String?
    let total: Int?
    let errors: [BatchActionError]?

    /// Mensagem da primeira falha por-item, ou nil se tudo passou.
    var failureMessage: String? {
        guard let first = (errors ?? []).first(where: { $0.success != true }) else { return nil }
        return first.message ?? "Não foi possível concluir a ação."
    }
}

struct BatchActionError: Decodable, Sendable {
    let id: String?
    let success: Bool?
    let message: String?
    let code: Int?
}

/// `SendToApprovalResponseDto` → `{ statusCode, errors: [...], success: [...] }`.
struct SendToApprovalResponse: Decodable, Sendable {
    let statusCode: Int?
    let errors: [BatchActionError]?
    let success: [BatchActionError]?

    /// Mensagem da primeira falha por-item, ou nil se tudo passou.
    var failureMessage: String? {
        guard let first = (errors ?? []).first(where: { $0.success != true }) else { return nil }
        return first.message ?? "Não foi possível concluir a ação."
    }
}

// MARK: - Serviço

/// Cliente da mobile-api para o domínio Payout. Cada método mapeia uma rota confirmada
/// em `payout.service.ts`.
struct PayoutAPI: Sendable {
    let client: APIClient

    // Queries
    func packages(status: [PackageStatus], filters: PayoutFilters = PayoutFilters(), page: Int = 0,
                  orderBy: String = "paymentDate", sort: String = "asc") async throws -> [Package] {
        var query = status.map { URLQueryItem(name: "status", value: $0.rawValue) }
        query.append(contentsOf: filters.queryItems())
        query.append(URLQueryItem(name: "orderBy", value: orderBy))
        query.append(URLQueryItem(name: "sort", value: sort))
        query.append(URLQueryItem(name: "page", value: String(page)))
        // Decodificação tolerante: um pacote malformado (campo nulo inesperado num cliente grande)
        // é descartado em vez de derrubar a lista inteira ("Resposta inesperada do servidor").
        let response: LossyArray<Package> = try await client.send(.get("/packages", query: query))
        return response.values
    }

    /// Totais por tab (count + soma). Aceita os mesmos filtros de /packages (sem status — é global).
    func totals(filters: PayoutFilters = PayoutFilters()) async throws -> PackageTotals {
        try await client.send(.get("/packages-totals", query: filters.queryItems()))
    }

    /// Opções de UMA categoria dinâmica de GET /package-filters (`active_filter=<key>`) — mesma
    /// forma que web/RN usam contra prod (uma categoria por request; o gate useActiveFilter só
    /// executa o builder pedido). Chave AUSENTE na resposta = builder falhou no backend → lança
    /// (categoria presente porém vazia é "sem opções", não erro).
    func filterOptions(key: String, status: [PackageStatus],
                       filters: PayoutFilters = PayoutFilters()) async throws -> [FilterOption] {
        var query = status.map { URLQueryItem(name: "status", value: $0.rawValue) }
        query.append(contentsOf: filters.queryItems())
        query.append(URLQueryItem(name: "active_filter", value: key))
        let response: PackageFilterOptions = try await client.send(.get("/package-filters", query: query))
        guard let category = response.categories.first(where: { $0.key == key }) else {
            throw APIError(kind: .decoding,
                           message: "Categoria '\(key)' ausente na resposta de /package-filters",
                           exceptionName: nil, underlying: nil)
        }
        return category.options
    }

    // Mutations
    func approve(_ items: [ApprovePackagesRequest.Item]) async throws -> BatchActionResponse {
        try await client.send(.post("/packages/approve", body: ApprovePackagesRequest(packages: items)))
    }

    /// Resposta é passthrough sem shape estável — 2xx = sucesso (corpo ignorado).
    func cancelApproval(ids: [String]) async throws {
        let _: EmptyResponse = try await client.send(
            .post("/packages/cancel-approval", body: PackageIdsRequest(packageIds: ids))
        )
    }

    func sendToApproval(ids: [String]) async throws -> SendToApprovalResponse {
        try await client.send(.post("/packages/send-to-approval", body: PackageIdsRequest(packageIds: ids)))
    }

    /// Envia mensagem no chat do pagamento via a rota canônica POST /payments/{id}/chat. `type`
    /// segue o enum CHAT_TYPES do backend (USER_MESSAGE | EVENT). Retorna a mensagem persistida
    /// (com id/timestamp reais) para substituir o eco otimista.
    func createChatMessage(packageId: String, message: String, type: String = "USER_MESSAGE") async throws -> ChatMessage {
        let response: CreateChatMessageResponse = try await client.send(
            .post("/payments/\(packageId)/chat",
                  body: CreateChatMessageRequest(text: message, type: type))
        )
        guard let sent = response.message?.toChatMessage() else {
            throw APIError(kind: .decoding, message: "Resposta inesperada ao enviar a mensagem.",
                           exceptionName: nil, underlying: nil)
        }
        return sent
    }

    /// Histórico do chat do pagamento (GET /payments/{id}/chat) — JSON cru, mensagens ASC.
    func chatHistory(packageId: String, limit: Int = 50, before: String? = nil) async throws -> [ChatMessage] {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let before { query.append(URLQueryItem(name: "before", value: before)) }
        let response: ChatHistoryResponse = try await client.send(
            .get("/payments/\(packageId)/chat", query: query)
        )
        return (response.messages ?? []).map { $0.toChatMessage() }
    }

    // NOTE: rotas por-seção (GET /payments/{id}/summary, /tags, /allocations, ...) seguem o mesmo
    // padrão — adicionar conforme se portam os DTOs de `@paggo/payments-service/*`.
    // Atenção ao decode: campos não-opcionais sem default exigem a chave no JSON (ver docs).
}
