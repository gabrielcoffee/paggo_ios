import Foundation

/// Definição tipada de um endpoint — método + caminho + query + corpo + tipo de resposta.
/// Um `Endpoint` por rota da mobile-api (espelha as chamadas de `payout.service.ts`).
struct Endpoint<Response: Decodable & Sendable>: Sendable {
    enum Method: String, Sendable {
        case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
    }

    var method: Method
    var path: String                 // relativo à base (ex.: "/payments/\(id)/summary")
    var query: [URLQueryItem]
    var body: Data?
    var requiresAuth: Bool
    /// Sobrescreve a base (ex.: rotas de auth usam `authBaseURL` em vez de `apiBaseURL`).
    var baseURL: URL?

    // MARK: Construtores

    static func get(_ path: String, query: [URLQueryItem] = [], requiresAuth: Bool = true) -> Endpoint {
        Endpoint(method: .get, path: path, query: query, body: nil, requiresAuth: requiresAuth)
    }

    static func post<Body: Encodable>(_ path: String, body: Body, requiresAuth: Bool = true) -> Endpoint {
        Endpoint(method: .post, path: path, query: [], body: try? JSONEncoder.api.encode(body), requiresAuth: requiresAuth)
    }

    static func post(_ path: String, requiresAuth: Bool = true) -> Endpoint {
        Endpoint(method: .post, path: path, query: [], body: nil, requiresAuth: requiresAuth)
    }

    static func patch<Body: Encodable>(_ path: String, body: Body, requiresAuth: Bool = true) -> Endpoint {
        Endpoint(method: .patch, path: path, query: [], body: try? JSONEncoder.api.encode(body), requiresAuth: requiresAuth)
    }
}

extension JSONEncoder {
    /// Encoder padrão da API (camelCase, igual aos DTOs Zod).
    static var api: JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .useDefaultKeys
        return e
    }
}

extension JSONDecoder {
    /// Decoder padrão da API (camelCase, igual aos DTOs Zod). Datas chegam como String ISO
    /// nos DTOs do app, então não há estratégia especial de datas.
    static var api: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }
}
