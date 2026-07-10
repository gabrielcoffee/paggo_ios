import Foundation

/// Alvo de reset de sessão: um store que guarda dados por-usuário e precisa ser limpo no signOut
/// para não vazar dados de um usuário para o próximo login na mesma sessão do app.
@MainActor
protocol SessionResettable: AnyObject {
    func reset()
}

/// Registro leve de stores que precisam ser limpos no signOut. Cada store se registra no seu
/// `init`; o `AuthStore.signOut()` chama `resetAll()`, que limpa os stores (referências fracas,
/// sem ciclos de retenção) e o cache do `QueryClient.shared` (memória + disco). É o ponto único
/// de "esquecer o usuário atual" — os stores vivem por toda a sessão do app (@State no root), então
/// não são recriados no logout e sem este reset serviriam dados velhos no próximo login.
@MainActor
final class SessionResetRegistry {
    static let shared = SessionResetRegistry()

    private struct WeakTarget { weak var value: (any SessionResettable)? }
    private var targets: [WeakTarget] = []

    func register(_ target: any SessionResettable) {
        targets.append(WeakTarget(value: target))
    }

    /// Limpa todos os stores registrados e o cache de servidor. Ainda descarta entradas mortas.
    func resetAll() {
        targets.removeAll { $0.value == nil }
        for target in targets { target.value?.reset() }
        QueryClient.shared.clear()
    }
}
