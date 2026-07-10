import Foundation

/// Uma opção selecionável dentro de uma categoria de filtro (id + rótulo + contagem).
/// Codable para persistir no cache do `QueryClient` (opções por categoria, lazy).
struct FilterOption: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let count: Int?
}

extension Array where Element == FilterOption {
    /// Ordena por contagem (desc); opções sem contagem vão para o fim. `sorted(by:)` não garante
    /// estabilidade, então o índice original é o desempate — categorias inteiras sem contagem
    /// (ex.: financialInstitution) preservam a ordem do servidor.
    func sortedByCountDescending() -> [FilterOption] {
        enumerated()
            .sorted { a, b in
                let ca = a.element.count ?? -1
                let cb = b.element.count ?? -1
                if ca != cb { return ca > cb }
                return a.offset < b.offset
            }
            .map(\.element)
    }
}

/// Uma categoria de filtro (ex.: "Pagador", "Método de pagamento") com suas opções.
struct FilterCategory: Identifiable, Sendable {
    let key: String          // chave usada no query param de /packages
    let title: String        // rótulo exibido
    let options: [FilterOption]
    var id: String { key }
}

/// Opções de filtro vindas de GET /package-filters. Decode TOLERANTE: cada categoria pode vir como
/// array `[{id,name,count}]` ou como mapa `{ CHAVE: count }` (status/type/createdFrom). Ordem e
/// rótulos definidos por `Self.order`. Mapeia para o nome de query param de /packages.
///
/// As categorias dinâmicas são buscadas UMA por request (`active_filter=<key>`, lazy ao abrir o
/// drawer) — paridade com web/RN. O fan-out bulk (CSV com todas as chaves) foi removido: um único
/// builder lento/quebrado no backend derrubava a resposta inteira para `{}`.
struct PackageFilterOptions: Sendable {
    var categories: [FilterCategory] = []

    /// (chave da resposta, rótulo PT-BR, nome do query param em /packages). Paridade com os filtros
    /// do payout web. Os params usam o contrato da mobile-api: camelCase para a maioria; snake_case
    /// onde o backend espera (payment_method) ou onde o filtro ainda não é servido (espelha o web:
    /// document_connected, on_time, banking_account) — pendente de suporte no backend.
    static let order: [(key: String, title: String, param: String)] = [
        ("organization", "Pagador", "organization"),
        ("supplier", "Contraparte", "supplier"),
        ("companyTags", "Categoria da empresa", "companyTags"),
        ("requesters", "Solicitante", "requesters"),
        ("project", "Projetos", "project"),
        ("unit", "Unidades", "unit"),
        ("costCenter", "Centros de custo", "costCenter"),
        ("managerialAccount", "Contas gerenciais", "managerialAccount"),
        ("financialInstitution", "Instituição financeira", "financialInstitution"),
        ("tags", "Etiquetas", "tags"),
        ("type", "Tipo", "type"),
        ("createdFrom", "Origem", "createdFrom"),
        ("paymentMethod", "Método de pagamento", "payment_method"),
        ("document", "Documento", "document"),
        ("documentConnected", "Conexão com documento", "document_connected"),
        ("onTime", "Atraso", "on_time"),
        ("bankingAccount", "Contas bancárias", "banking_account"),
        ("beneficiary_name", "Nome do beneficiário", "beneficiary_name"),
        ("beneficiary_tax_id", "Documento do beneficiário", "beneficiary_tax_id"),
    ]

    /// Categorias cujas opções são fixas (catálogo estático), não vindas de GET /package-filters.
    static let staticOptionKeys: Set<String> = ["paymentMethod", "document", "documentConnected", "onTime"]

    static func paramName(forCategory key: String) -> String {
        order.first { $0.key == key }?.param ?? key
    }

    /// Nome de exibição por código COMPE (subconjunto BACEN mais comum) — espelha o `getBankName`
    /// do web (`@paggo/constants`): resolve pelo código, senão devolve o próprio texto (é assim que
    /// a linha sintética `paggo` vira "Paggo").
    private static let bankNames: [String: String] = [
        "001": "Banco do Brasil", "033": "Santander", "041": "Banrisul",
        "077": "Banco Inter", "104": "Caixa Econômica Federal", "136": "Unicred",
        "197": "Stone", "208": "BTG Pactual", "212": "Banco Original",
        "237": "Bradesco", "260": "Nubank", "290": "PagBank",
        "318": "BMG", "323": "Mercado Pago", "336": "C6 Bank",
        "341": "Itaú Unibanco", "348": "Banco XP", "380": "PicPay",
        "403": "Cora", "422": "Banco Safra", "623": "Banco Pan",
        "655": "Banco Votorantim", "707": "Banco Daycoval", "735": "Banco Neon",
        "748": "Sicredi", "756": "Sicoob",
    ]

    /// Códigos COMPE chegam como "341" ou "00000341" — normaliza os zeros antes de procurar.
    static func bankName(forCode raw: String) -> String {
        let trimmed = String(raw.drop(while: { $0 == "0" }))
        guard !trimmed.isEmpty else { return raw }
        let padded = String(repeating: "0", count: max(0, 3 - trimmed.count)) + trimmed
        return bankNames[padded] ?? raw
    }
}

extension PackageFilterOptions: Decodable {
    private struct DynamicKey: CodingKey {
        var stringValue: String; var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        var result: [FilterCategory] = []

        for entry in Self.order {
            guard let codingKey = DynamicKey(stringValue: entry.key),
                  container.contains(codingKey) else { continue }

            var options: [FilterOption] = []

            // Forma 1: array de itens { id, name, count, aliasName?, bankCodeStr? }.
            if let items = try? container.decode([RawOption].self, forKey: codingKey) {
                options = items.compactMap { $0.toOption(categoryKey: entry.key) }
            }
            // Forma 2: mapa { CHAVE: count } (status / type / createdFrom).
            else if let map = try? container.decode([String: Int].self, forKey: codingKey) {
                options = map.map { FilterOption(id: $0.key, name: Self.label(for: entry.key, value: $0.key), count: $0.value) }
                    .sorted { ($0.count ?? 0) > ($1.count ?? 0) }
            }

            // Categoria presente entra MESMO vazia — presença distingue "sem opções" de
            // "builder falhou" (chave omitida) no fetch por categoria.
            result.append(FilterCategory(key: entry.key, title: entry.title, options: options))
        }
        self.categories = result
    }

    private struct RawOption: Decodable {
        let id: String?
        let name: String?
        let legalName: String?
        let commercialName: String?
        let aliasName: String?
        /// Código COMPE — shape exclusivo de financialInstitution (sem name/count).
        let bankCodeStr: String?
        let count: Int?

        func toOption(categoryKey: String) -> FilterOption? {
            guard let id else { return nil }
            // financialInstitution: rótulo via bankCodeStr (paridade com o web filter-options.ts —
            // linhas sem bankCodeStr são descartadas; 'others' usa o texto literal "Não informada";
            // as demais resolvem o nome do banco pelo código, fallback = o próprio código).
            if categoryKey == "financialInstitution" {
                guard let bankCodeStr, !bankCodeStr.isEmpty else { return nil }
                let label = id == "others" ? bankCodeStr : PackageFilterOptions.bankName(forCode: bankCodeStr)
                return FilterOption(id: id, name: label, count: count)
            }
            let label = aliasName ?? commercialName ?? name ?? legalName ?? id
            return FilterOption(id: id, name: label, count: count)
        }
    }

    /// Rótulos amigáveis para categorias que vêm como mapa de enum→count.
    private static func label(for category: String, value: String) -> String {
        switch category {
        case "type": return PackageTypeLabel.label(for: PackageType(rawValue: value)) ?? value
        case "tags": return PackageTagInfo.display(for: PackageTag(type: value)).displayName
        default: return value
        }
    }
}
