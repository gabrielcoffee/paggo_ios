import Foundation

/// Erro de API normalizado — espelha o `normalizeError` do axios.client.ts
/// (`{ message, status, type, details }`) + erros de transporte/decodificação.
struct APIError: Error, Sendable {
    enum Kind: Sendable, Equatable {
        case offline                 // sem conexão / falha de transporte
        case unauthorized            // 401 após refresh falhar (sessão expirada)
        case server(status: Int)     // 4xx/5xx com corpo de erro
        case decoding                // resposta não casa com o DTO
        case invalidResponse
    }

    var kind: Kind
    var message: String
    var exceptionName: String?       // `type` no backend (Paggo exception name)
    var underlying: Error?

    /// Mensagem amigável pt-BR para toasts (fallback genérico).
    var userMessage: String {
        switch kind {
        case .offline: return "Sem conexão. Mostrando dados salvos."
        case .unauthorized: return "Sua sessão expirou. Entre novamente."
        case .decoding, .invalidResponse: return "Resposta inesperada do servidor."
        case .server: return message.isEmpty ? "Erro inesperado." : message
        }
    }

    static func offline(_ underlying: Error? = nil) -> APIError {
        APIError(kind: .offline, message: "Sem conexão", exceptionName: nil, underlying: underlying)
    }
}

/// Corpo de erro padrão do backend (PaggoHttpError).
struct APIErrorBody: Decodable, Sendable {
    let message: String?
    let type: String?
}
