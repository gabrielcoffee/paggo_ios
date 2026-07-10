import Foundation
import Security

/// Sessão de tokens (espelha as SECURE_KEYS do app Expo).
struct TokenBundle: Codable, Sendable {
    var accessToken: String
    var refreshToken: String
    var sessionId: String?
    var expiresAt: Date?

    /// `true` se o access token está expirado (com buffer de 5 min, igual ao app).
    var isExpired: Bool {
        guard let expiresAt else { return true }
        return Date() >= expiresAt.addingTimeInterval(-5 * 60)
    }
}

/// Armazenamento seguro de tokens. Protocolo para permitir um mock em previews/testes.
protocol TokenStore: Sendable {
    func read() -> TokenBundle?
    func save(_ bundle: TokenBundle)
    func clear()
}

/// Implementação em Keychain (substitui o MMKV criptografado do app Expo).
struct KeychainTokenStore: TokenStore {
    private let account = "ai.paggo.mobile.session"
    private let service = "ai.paggo.mobile.tokens"

    func read() -> TokenBundle? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(TokenBundle.self, from: data)
    }

    func save(_ bundle: TokenBundle) {
        guard let data = try? JSONEncoder().encode(bundle) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var attrs = base
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attrs as CFDictionary, nil)
    }

    func clear() {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
    }
}

/// Mock para previews/testes — guarda em memória.
final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var bundle: TokenBundle?
    init(_ bundle: TokenBundle? = nil) { self.bundle = bundle }
    func read() -> TokenBundle? { lock.withLock { bundle } }
    func save(_ bundle: TokenBundle) { lock.withLock { self.bundle = bundle } }
    func clear() { lock.withLock { bundle = nil } }
}
