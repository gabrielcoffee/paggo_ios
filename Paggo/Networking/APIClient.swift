import SwiftUI

/// Cliente HTTP tipado sobre URLSession — espelha o axios.client.ts (headers de device, api-key,
/// Bearer, renovação de token e retry de 401). Stateless e Sendable.
final class APIClient: Sendable {
    private let config: AppConfig
    private let tokens: TokenStore
    private let refresher: TokenRefresher
    private let session: URLSession

    init(config: AppConfig = .current, tokens: TokenStore = KeychainTokenStore(), session: URLSession = .shared) {
        self.config = config
        self.tokens = tokens
        self.session = session
        self.refresher = TokenRefresher(config: config, tokens: tokens, session: session)
    }

    private static let skipAuthPaths = ["/auth/login", "/auth/refresh", "/generate-custom-token"]

    /// Envia o endpoint e decodifica a resposta. Renova token e refaz uma vez em 401.
    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        do {
            let request = try await makeRequest(for: endpoint, forceFreshToken: false)
            return try await perform(request, endpoint: endpoint, isRetry: false)
        } catch let error as APIError {
            throw error
        } catch let urlError as URLError {
            // Apenas falhas REAIS de conectividade viram "offline".
            throw APIError.offline(urlError)
        } catch {
            // Qualquer outra falha (ex.: decode de token/resposta) NÃO é "sem conexão" —
            // não mascarar como erro de conexão.
            throw APIError(kind: .invalidResponse, message: "Falha inesperada na requisição",
                           exceptionName: nil, underlying: error)
        }
    }

    /// Garante um access token utilizável (renovando se expirado) — usado antes de entrar via
    /// Face ID. Tri-state: `.offline` para falhas transitórias (transporte ou 5xx do backend —
    /// a sessão salva continua válida), `.expired` só quando o backend rejeitou a sessão
    /// (precisa relogar).
    func ensureValidSession() async -> SessionCheck {
        await refresher.resetAttempts()
        do {
            _ = try await refresher.validAccessToken()
            return .usable
        } catch let error as APIError {
            switch error.kind {
            case .offline:
                return .offline
            case .unauthorized:
                return .expired
            case .server, .decoding, .invalidResponse:
                // 5xx/resposta inesperada do /auth/refresh é falha do backend, não rejeição da
                // sessão — tratar como transitório (mesmo caminho do offline: manter o cartão).
                return .offline
            }
        } catch is URLError {
            return .offline
        } catch {
            return .expired
        }
    }

    /// Zera o contador de tentativas de refresh — chamado quando um novo login cria sessão nova.
    func resetRefreshAttempts() async {
        await refresher.resetAttempts()
    }

    // MARK: - Privados

    private func perform<Response>(_ request: URLRequest, endpoint: Endpoint<Response>, isRetry: Bool) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(kind: .invalidResponse, message: "Resposta inválida", exceptionName: nil, underlying: nil)
        }

        // 401 → renova e refaz uma vez (rotas de auth não tentam).
        if http.statusCode == 401, !isRetry, endpoint.requiresAuth,
           !Self.skipAuthPaths.contains(where: { endpoint.path.contains($0) }) {
            _ = try await refresher.refresh()
            let retried = try await makeRequest(for: endpoint, forceFreshToken: true)
            return try await perform(retried, endpoint: endpoint, isRetry: true)
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = try? JSONDecoder.api.decode(APIErrorBody.self, from: data)
            if http.statusCode == 401 {
                throw APIError(kind: .unauthorized, message: body?.message ?? "Sessão expirada",
                               exceptionName: body?.type, underlying: nil)
            }
            throw APIError(kind: .server(status: http.statusCode),
                           message: body?.message ?? "Erro \(http.statusCode)",
                           exceptionName: body?.type, underlying: nil)
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        do {
            return try JSONDecoder.api.decode(Response.self, from: data)
        } catch {
            throw APIError(kind: .decoding, message: "Falha ao ler a resposta", exceptionName: nil, underlying: error)
        }
    }

    private func makeRequest<Response>(for endpoint: Endpoint<Response>, forceFreshToken: Bool) async throws -> URLRequest {
        let base = endpoint.baseURL ?? config.apiBaseURL
        var components = URLComponents(
            url: base.appendingPathComponent(endpoint.path.hasPrefix("/") ? String(endpoint.path.dropFirst()) : endpoint.path),
            resolvingAgainstBaseURL: false
        )
        if !endpoint.query.isEmpty { components?.queryItems = endpoint.query }
        guard let url = components?.url else {
            throw APIError(kind: .invalidResponse, message: "URL inválida", exceptionName: nil, underlying: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "api-key")
        for (key, value) in await Self.deviceHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if endpoint.requiresAuth, !Self.skipAuthPaths.contains(where: { endpoint.path.contains($0) }) {
            let token = forceFreshToken ? (tokens.read()?.accessToken ?? "") : (try await refresher.validAccessToken())
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// Headers de device (espelha getDeviceHeaders do app Expo).
    @MainActor private static func deviceHeaders() -> [String: String] {
        let device = UIDevice.current
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return [
            "x-platform": "ios",
            "x-bundle-id": Bundle.main.bundleIdentifier ?? "ai.paggo.mobile",
            "x-device-id": device.identifierForVendor?.uuidString ?? "unknown",
            "User-Agent": "Paggo/\(version) iOS/\(device.systemVersion)",
        ]
    }
}

/// Resultado da checagem de sessão pré-entrada: distingue sessão morta no backend (relogar)
/// de falha de transporte (offline — não descartar a sessão nem o usuário salvos).
enum SessionCheck: Sendable, Equatable {
    case usable
    case expired
    case offline
}

/// Resposta vazia para endpoints sem corpo (ex.: create-chat-message).
struct EmptyResponse: Decodable, Sendable {}
