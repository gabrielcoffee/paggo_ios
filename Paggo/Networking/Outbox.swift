import SwiftUI

/// Uma mutação pendente, persistida para reenvio quando a conexão voltar.
/// Conceitualmente espelha o Outbox do backend: a intenção é gravada e despachada depois.
struct OutboxItem: Codable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    let method: String          // "POST" / "PATCH" / ...
    let path: String            // ex.: "/packages/approve"
    let bodyData: Data?
    /// Prefixos de cache a invalidar após o reenvio bem-sucedido.
    let invalidatePrefixes: [String]
}

/// Fila de mutações offline. Enfileira quando offline (ou em falha de envio) e drena ao reconectar.
/// MVP: reenvia POST/PATCH crus via APIClient; a evolução é tipar cada ação para updates otimistas.
@MainActor
@Observable
final class Outbox {
    static let shared = Outbox()

    private(set) var pending: [OutboxItem] = []
    private let fileURL: URL

    init() {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true))
            ?? URL.temporaryDirectory
        fileURL = dir.appendingPathComponent("paggo-outbox.json")
        load()
    }

    func enqueue(_ item: OutboxItem) {
        pending.append(item)
        persist()
    }

    /// Drena a fila (chamar ao reconectar). Itens que falharem permanecem para a próxima tentativa.
    func flush(send: @Sendable (OutboxItem) async throws -> Void,
               onSuccess: (OutboxItem) -> Void = { _ in }) async {
        guard !pending.isEmpty else { return }
        var remaining: [OutboxItem] = []
        for item in pending {
            do {
                try await send(item)
                onSuccess(item)
            } catch {
                remaining.append(item) // mantém para tentar de novo
            }
        }
        pending = remaining
        persist()
    }

    // MARK: - Persistência

    private func persist() {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([OutboxItem].self, from: data) else { return }
        pending = items
    }
}
