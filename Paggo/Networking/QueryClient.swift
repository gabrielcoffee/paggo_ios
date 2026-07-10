import SwiftUI

/// Cache de estado de servidor no estilo React Query — chaveado por string, com `staleTime`,
/// deduplicação de chamadas em voo, invalidação e **persistência em disco para leitura offline**.
/// É o equivalente nativo ao `QueryClient` do TanStack usado no app Expo.
@MainActor
@Observable
final class QueryClient {
    static let shared = QueryClient()

    private struct Entry { let data: Data; let storedAt: Date }
    private var memory: [String: Entry] = [:]
    private var inFlight: [String: Task<Data, Error>] = [:]
    /// Geração por chave, incrementada em `invalidate` — completions de tasks pré-invalidação
    /// não regravam o cache como se fossem frescas.
    private var generation: [String: UInt64] = [:]
    private let dir: URL
    private let encoder = JSONEncoder.api
    private let decoder = JSONDecoder.api

    init() {
        let caches = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true))
            ?? URL.temporaryDirectory
        dir = caches.appendingPathComponent("paggo-query", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Busca com stale-while-revalidate:
    /// - cache fresco → retorna do cache;
    /// - caso contrário → busca na rede, persiste e retorna;
    /// - falha de rede / offline → retorna o último cache (memória ou disco), se houver.
    func fetch<T: Codable & Sendable>(
        _ key: String,
        staleTime: TimeInterval = 30,
        fetch: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        if let entry = memory[key], Date().timeIntervalSince(entry.storedAt) < staleTime,
           let value = try? decoder.decode(T.self, from: entry.data) {
            return value
        }

        let gen = generation[key] ?? 0
        let task: Task<Data, Error>
        if let existing = inFlight[key] {
            task = existing
        } else {
            task = Task { [encoder] in
                let value = try await fetch()
                return try encoder.encode(value)
            }
            inFlight[key] = task
        }
        // Só solta o handle se ainda formos a task registrada (invalidate pode tê-la trocado).
        defer { if inFlight[key] == task { inFlight[key] = nil } }

        do {
            let data = try await task.value
            // Invalidação durante o voo: devolve ao chamador, mas NÃO repopula o cache.
            if (generation[key] ?? 0) == gen { store(key, data) }
            return try decoder.decode(T.self, from: data)
        } catch {
            if let cached = cachedValue(T.self, for: key) { return cached }
            throw error
        }
    }

    /// Lê o valor em cache (memória → disco) sem buscar na rede.
    func cachedValue<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        if let entry = memory[key], let value = try? decoder.decode(T.self, from: entry.data) {
            return value
        }
        guard let data = try? Data(contentsOf: fileURL(key)) else { return nil }
        memory[key] = Entry(data: data, storedAt: .distantPast)
        return try? decoder.decode(T.self, from: data)
    }

    /// Atualiza o cache manualmente (após uma mutação otimista).
    func setData<T: Encodable>(_ key: String, _ value: T) {
        guard let data = try? encoder.encode(value) else { return }
        store(key, data)
    }

    /// Invalida todas as chaves com o prefixo (ex.: `paymentKeys.detail(id)`).
    /// Também descarta tasks em voo do prefixo: a próxima busca começa do zero (não deduplica
    /// numa fetch pré-mutação) e o bump de geração impede que a completion tardia dessas tasks
    /// regrave o cache com dados velhos.
    func invalidate(prefix: String) {
        for key in memory.keys where key.hasPrefix(prefix) {
            memory[key] = nil
            try? FileManager.default.removeItem(at: fileURL(key))
            generation[key, default: 0] += 1
        }
        for key in inFlight.keys where key.hasPrefix(prefix) {
            generation[key, default: 0] += 1
            inFlight[key] = nil
        }
    }

    /// Limpa TODO o cache (memória + voo + disco) — usado no signOut para não vazar dados de
    /// servidor entre usuários. Faz bump de geração em todas as chaves conhecidas para que
    /// completions de tasks em voo pré-limpeza não regravem o cache com dados do usuário anterior.
    func clear() {
        let keys = Set(memory.keys).union(inFlight.keys).union(generation.keys)
        for key in keys { generation[key, default: 0] += 1 }
        memory.removeAll()
        inFlight.removeAll()
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: - Privados

    private func store(_ key: String, _ data: Data) {
        memory[key] = Entry(data: data, storedAt: Date())
        try? data.write(to: fileURL(key), options: .atomic)
    }

    private func fileURL(_ key: String) -> URL {
        // Nome de arquivo estável e seguro a partir da chave.
        let safe = String(UInt64(bitPattern: Int64(key.hashValue)))
        return dir.appendingPathComponent("q_\(safe).json")
    }
}

/// Chaves de query hierárquicas — espelha `paymentKeys.ts` do app Expo.
enum PaymentKeys {
    static let all = "payments"
    static func detail(_ id: String) -> String { "\(all).detail.\(id)" }
    static func summary(_ id: String) -> String { "\(detail(id)).summary" }
    static func tags(_ id: String) -> String { "\(detail(id)).tags" }
    static func allocations(_ id: String) -> String { "\(detail(id)).allocations" }
    static func approvers(_ id: String) -> String { "\(detail(id)).approvers" }
    static func method(_ id: String) -> String { "\(detail(id)).method" }
    static func deliveryDocument(_ id: String) -> String { "\(detail(id)).delivery-document" }
    static func budget(_ id: String) -> String { "\(detail(id)).budget" }
    static func conciliation(_ id: String) -> String { "\(detail(id)).conciliation" }
    static func alerts(_ id: String) -> String { "\(detail(id)).alerts" }
    static func chat(_ id: String) -> String { "\(detail(id)).chat" }
    static func packages(_ tab: String) -> String { "\(all).list.\(tab)" }
    static let totals = "\(all).totals"
}
