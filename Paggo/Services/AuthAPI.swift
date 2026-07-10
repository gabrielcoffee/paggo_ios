import Foundation

// Cliente da API de autenticação Paggo — espelha `data/services/auth/auth.service.ts`.
// O fluxo real é mediado por Firebase: provedor → id_token Firebase → POST /auth/login.

// MARK: - DTOs (portados de auth.entity.ts)

struct LoginRequest: Encodable, Sendable {
    let id_token: String
    let provider: String          // "google" | "microsoft" | "custom"
    let device_id: String
    let device_info: String
    let platform_customer_id: String
    let platform_user_id: String
}

struct AuthResponse: Decodable, Sendable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let session_id: String
}

struct CustomTokenResponse: Decodable, Sendable {
    let customToken: String
}

struct VerifyCodeResponse: Decodable, Sendable {
    let isValid: Bool
}

/// Usuário estendido (subset) — usado para resolver `platform_user_id` + `platform_customer_id`.
struct ExtendedUser: Decodable, Sendable {
    let id: String
    let email: String
    let name: String?
    let image: String?
    let sessionCustomer: String?
    let userCustomers: [UserCustomer]?

    struct UserCustomer: Decodable, Sendable {
        let customer: CustomerRef
        struct CustomerRef: Decodable, Sendable {
            let id: String
            let legalName: String?
        }
    }

    var resolvedCustomerId: String? {
        sessionCustomer ?? userCustomers?.first?.customer.id
    }
}

// MARK: - Serviço

struct AuthAPI: Sendable {
    let client: APIClient
    let authBaseURL: URL

    /// Login com id_token externo (Firebase) → tokens de sessão. (authBaseURL, sem Bearer)
    func login(_ request: LoginRequest) async throws -> AuthResponse {
        var endpoint = Endpoint<AuthResponse>.post("/auth/login", body: request, requiresAuth: false)
        endpoint.baseURL = authBaseURL
        return try await client.send(endpoint)
    }

    /// Gera o custom token do Firebase para um e-mail. (apiBaseURL, skip-auth)
    func generateCustomToken(email: String) async throws -> CustomTokenResponse {
        try await client.send(.post("/generate-custom-token",
                                    body: ["email": email.trimmed], requiresAuth: false))
    }

    /// Busca usuário por e-mail (resolve id + customer). (apiBaseURL)
    func userByEmail(_ email: String) async throws -> ExtendedUser {
        try await client.send(.get("/user-by-email",
                                   query: [URLQueryItem(name: "email", value: email.trimmed)],
                                   requiresAuth: false))
    }

    /// Envia o código de verificação por e-mail (OTP).
    func sendMessageToken(email: String) async throws {
        let _: EmptyResponse = try await client.send(
            .post("/auth/message-token", body: ["email": email.trimmed], requiresAuth: false))
    }

    /// Valida o código de verificação.
    func validateMessageToken(email: String, token: String) async throws -> VerifyCodeResponse {
        try await client.send(.post("/auth/validate-message-token",
                                    body: ["email": email.trimmed, "token": token.trimmed],
                                    requiresAuth: false))
    }

    /// Troca a empresa (customer) ativa da sessão — `PATCH /user/change-user-current-customer`
    /// (apiBaseURL, com Bearer). O servidor apenas grava `User.sessionCustomer`; o MESMO token
    /// passa a resolver o novo customer nas próximas requisições (sem re-login). Devolve o usuário
    /// atualizado (com `userCustomers` + `sessionCustomer`). 403 se o usuário não pertence ao customer.
    func changeCustomer(customerId: String) async throws -> ExtendedUser {
        try await client.send(.patch("/user/change-user-current-customer",
                                     body: ["customerId": customerId]))
    }

    /// Logout (authBaseURL).
    func logout(sessionId: String) async throws {
        var endpoint = Endpoint<EmptyResponse>.post("/auth/logout", body: ["session_id": sessionId])
        endpoint.baseURL = authBaseURL
        let _: EmptyResponse = try await client.send(endpoint)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
