import Foundation

/// Decodificação tolerante de arrays: elementos que falham individualmente são descartados em vez
/// de derrubar o array inteiro. Usado nas listas da mobile-api para que UM pacote malformado (ex.:
/// um campo nulo que o DTO espera não-nulo) não quebre a tela toda — visto em prod com clientes
/// grandes, cujo volume/variedade de dados expõe casos de borda.
struct LossyArray<Element: Decodable & Sendable>: Decodable, Sendable {
    let values: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var accumulated: [Element] = []
        while !container.isAtEnd {
            // `Wrapped` nunca lança na decodificação do elemento, então o container sempre avança
            // (evita loop infinito) e um elemento inválido vira `nil`, sendo descartado.
            let wrapped = try container.decode(Wrapped.self)
            if let value = wrapped.value { accumulated.append(value) }
        }
        values = accumulated
    }

    private struct Wrapped: Decodable {
        let value: Element?
        init(from decoder: Decoder) throws { value = try? Element(from: decoder) }
    }
}
