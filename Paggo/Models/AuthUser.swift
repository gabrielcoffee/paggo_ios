import Foundation

/// Provedores de login suportados na tela de acesso. Sem backend — a autenticação é mockada.
enum AuthProvider: String, Codable, Sendable, CaseIterable, Identifiable {
    case google
    case microsoft
    case email

    var id: String { rawValue }

    var label: String {
        switch self {
        case .google: return "Google"
        case .microsoft: return "Microsoft"
        case .email: return "E-mail"
        }
    }

    /// Texto do botão na lista de provedores.
    var actionLabel: String {
        self == .email ? "Entrar com e-mail" : "Entrar com \(label)"
    }
}

/// Usuário autenticado / salvo no dispositivo. Persistido em UserDefaults para habilitar o
/// atalho de Face ID no próximo acesso.
struct AuthUser: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let email: String
    let provider: AuthProvider
    /// URL da foto de perfil (Google/IdP). Persistida para o atalho de Face ID.
    var image: String? = nil

    /// Empresa (customer/workspace) ativa e a lista à qual o usuário pertence. Opcionais para
    /// decodificar blobs salvos antigos (sem essas chaves) — populados no login e na troca.
    var currentCustomerId: String? = nil
    var customers: [Workspace]? = nil

    /// Empresa (customer) do usuário — id + razão social.
    struct Workspace: Codable, Equatable, Hashable, Sendable, Identifiable {
        let id: String
        let name: String
    }

    /// Primeiro nome para a saudação ("Entrar como Igor").
    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    /// Nome da empresa ativa (casa `currentCustomerId`; cai para a primeira da lista).
    var currentWorkspaceName: String? {
        guard let customers, !customers.isEmpty else { return nil }
        return (customers.first { $0.id == currentCustomerId } ?? customers.first)?.name
    }

    /// Só oferecemos o seletor quando há mais de uma empresa.
    var canSwitchCustomer: Bool { (customers?.count ?? 0) > 1 }
}
