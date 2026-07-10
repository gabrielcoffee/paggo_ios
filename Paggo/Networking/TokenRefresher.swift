import Foundation

/// Renova o access token de forma single-flight (espelha o `isRefreshing` + `failedQueue` do
/// axios.client.ts): chamadas concorrentes aguardam a mesma renovação em vez de dispararem várias.
actor TokenRefresher {
    private let config: AppConfig
    private let tokens: TokenStore
    private let session: URLSession
    private var inFlight: Task<String, Error>?
    private var attempts = 0
    private let maxAttempts = 5

    init(config: AppConfig, tokens: TokenStore, session: URLSession) {
        self.config = config
        self.tokens = tokens
        self.session = session
    }

    /// Retorna um access token válido, renovando se necessário.
    func validAccessToken() async throws -> String {
        guard let bundle = tokens.read() else {
            throw APIError(kind: .unauthorized, message: "Sem sessão", exceptionName: nil, underlying: nil)
        }
        if !bundle.isExpired { return bundle.accessToken }
        return try await refresh()
    }

    /// Zera o contador de falhas — chamado quando um novo login cria sessão nova e a cada
    /// checagem de sessão iniciada pelo usuário (falhas antigas não devem condenar a sessão nova).
    func resetAttempts() { attempts = 0 }

    /// Força uma renovação (usado no fluxo de retry de 401).
    func refresh() async throws -> String {
        if let inFlight { return try await inFlight.value }
        let task = Task<String, Error> { try await performRefresh() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    private func performRefresh() async throws -> String {
        guard let bundle = tokens.read(), !bundle.refreshToken.isEmpty else {
            throw APIError(kind: .unauthorized, message: "Sem refresh token", exceptionName: nil, underlying: nil)
        }
        guard attempts < maxAttempts else {
            tokens.clear()
            throw APIError(kind: .unauthorized, message: "Falha ao renovar sessão", exceptionName: nil, underlying: nil)
        }

        var request = URLRequest(url: config.authBaseURL.appendingPathComponent("auth/refresh"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "api-key")
        request.httpBody = try JSONEncoder().encode(
            RefreshRequest(refresh_token: bundle.refreshToken, session_id: bundle.sessionId)
        )
        request.timeoutInterval = 10

        // Falhas de transporte (URLError) propagam sem contar tentativa nem limpar o Keychain —
        // um blip de rede não pode destruir a sessão salva.
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(kind: .invalidResponse, message: "Resposta inválida", exceptionName: nil, underlying: nil)
        }
        guard http.statusCode == 200 else {
            // Só 401/403 (refresh token rejeitado) invalida a sessão e conta tentativa.
            if [401, 403].contains(http.statusCode) {
                attempts += 1
                tokens.clear()
                throw APIError(kind: .unauthorized, message: "Falha ao renovar sessão", exceptionName: nil, underlying: nil)
            }
            // 5xx/outros status são falha do backend, não rejeição da sessão — preserva o
            // Keychain e sinaliza como erro de servidor (transitório) para o chamador.
            throw APIError(kind: .server(status: http.statusCode), message: "Falha ao renovar sessão",
                           exceptionName: nil, underlying: nil)
        }

        let decoded: RefreshResponse
        do {
            decoded = try JSONDecoder().decode(RefreshResponse.self, from: data)
        } catch {
            // Resposta 200 mas em formato inesperado → tratar como sessão inválida (relogar),
            // nunca como "erro de conexão".
            tokens.clear()
            throw APIError(kind: .unauthorized, message: "Falha ao renovar sessão",
                           exceptionName: nil, underlying: error)
        }
        let newBundle = TokenBundle(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token ?? bundle.refreshToken,
            sessionId: bundle.sessionId,
            expiresAt: Date().addingTimeInterval(TimeInterval(decoded.expires_in ?? 3000))
        )
        tokens.save(newBundle)
        attempts = 0
        return decoded.access_token
    }

    private struct RefreshRequest: Encodable { let refresh_token: String; let session_id: String? }
    private struct RefreshResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int?
    }
}
