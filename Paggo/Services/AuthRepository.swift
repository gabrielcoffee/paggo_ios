import Foundation

/// Abstrai o sign-in para que o mock possa ser trocado por um cliente real (OAuth/identity provider)
/// sem tocar no store nem nas views.
protocol AuthRepository: Sendable {
    func signIn(with provider: AuthProvider, email: String?) async -> AuthUser
}

/// Mock: simula a latência de rede e devolve um usuário determinístico.
struct MockAuthRepository: AuthRepository {
    func signIn(with provider: AuthProvider, email: String?) async -> AuthUser {
        try? await Task.sleep(for: .milliseconds(650))

        switch provider {
        case .email:
            let address = (email?.isEmpty == false) ? email! : "igor@paggo.ai"
            return AuthUser(id: "user_\(address)", name: Self.name(from: address),
                            email: address, provider: .email)
        case .google, .microsoft:
            return AuthUser(id: "user_igor", name: "Igor", email: "igor@paggo.ai", provider: provider)
        }
    }

    /// Deriva um nome amigável a partir do local-part do e-mail ("ana.souza@x" → "Ana Souza").
    private static func name(from email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? email
        let parts = local.split { $0 == "." || $0 == "_" || $0 == "-" }
        let capitalized = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }
        let joined = capitalized.joined(separator: " ")
        return joined.isEmpty ? "Você" : joined
    }
}
