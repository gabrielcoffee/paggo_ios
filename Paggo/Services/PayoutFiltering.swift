import Foundation

/// Critérios de filtro aplicados à lista de pagamentos. As categorias (pagador, contraparte,
/// método, tipo, etiquetas, projeto, centro de custo, conta gerencial, unidade, solicitante,
/// categoria da empresa, instituição financeira, origem) são filtradas no BACKEND (query params
/// de /packages, opções de /package-filters). Busca, status (dentro da tab) e "alto valor" são
/// aplicados no cliente.
/// Intervalo de datas (qualquer lado opcional).
struct DateRange: Equatable, Sendable {
    var from: Date?
    var to: Date?
    var isEmpty: Bool { from == nil && to == nil }
}

struct PayoutFilters: Equatable, Sendable {
    var search: String = ""
    var statuses: Set<PackageStatus> = []            // subconjunto dentro da tab; vazio = todos
    var onlyHighValue: Bool = false
    var selections: [String: Set<String>] = [:]      // categoryKey → ids selecionados (server-side);
                                                     // inclui documentConnected/onTime (chave única)

    // Datas (server-side). Chaves em `Self.dateFilters`.
    var dates: [String: DateRange] = [:]

    /// Filtros de data: (chave, rótulo, nome do query param em /packages). Paridade com o payout web.
    /// payment_date/paid_at já são honrados pela mobile-api; os demais espelham o web e ficam
    /// pendentes de handler no backend.
    static let dateFilters: [(key: String, title: String, param: String)] = [
        ("paymentDate", "Data de agendamento", "payment_date"),
        ("dueDate", "Data de vencimento", "due_date"),
        ("paidAt", "Data de pagamento", "paid_at"),
        ("provisionApprovedAt", "Aprovação da provisão", "provision_approved_at"),
        ("createdAt", "Data de criação", "created_at"),
        ("documentDate", "Data do documento", "document_date"),
    ]

    func selected(_ key: String) -> Set<String> { selections[key] ?? [] }

    mutating func toggle(_ key: String, _ id: String) {
        var set = selections[key] ?? []
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        if set.isEmpty { selections[key] = nil } else { selections[key] = set }
    }

    func dateRange(_ key: String) -> DateRange { dates[key] ?? DateRange() }
    mutating func setDateRange(_ key: String, _ range: DateRange) {
        dates[key] = range.isEmpty ? nil : range
    }

    var activeCount: Int {
        var n = 0
        if !search.trimmingCharacters(in: .whitespaces).isEmpty { n += 1 }
        if !statuses.isEmpty { n += 1 }
        if onlyHighValue { n += 1 }
        n += selections.values.filter { !$0.isEmpty }.count
        n += dates.values.filter { !$0.isEmpty }.count
        return n
    }

    var isActive: Bool { activeCount > 0 }

    /// Refino aplicado no cliente sobre as páginas carregadas (não vai ao servidor): busca por
    /// recebedor/documento, "alto valor", e subconjunto de status dentro da tab.
    var hasClientRefinement: Bool {
        !search.trimmingCharacters(in: .whitespaces).isEmpty || onlyHighValue || !statuses.isEmpty
    }

    /// Assinatura estável de tudo que é filtrado no servidor (para chave de cache + trigger de reload).
    var serverSignature: String {
        var parts: [String] = []
        for key in selections.keys.sorted() {
            if let ids = selections[key], !ids.isEmpty { parts.append("\(key)=\(ids.sorted().joined(separator: "|"))") }
        }
        for key in dates.keys.sorted() {
            let r = dates[key]!
            if !r.isEmpty { parts.append("\(key)=\(Self.iso(r.from))~\(Self.iso(r.to))") }
        }
        return parts.joined(separator: ";")
    }

    /// Todos os query params server-side para /packages — status é enviado à parte (pela tab).
    func queryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = selections.compactMap { (key, ids) -> URLQueryItem? in
            guard !ids.isEmpty else { return nil }
            return URLQueryItem(name: PackageFilterOptions.paramName(forCategory: key),
                                value: ids.sorted().joined(separator: ","))
        }
        for (key, _, param) in Self.dateFilters {
            let r = dateRange(key)
            guard !r.isEmpty else { continue }
            items.append(URLQueryItem(name: param, value: "\(Self.iso(r.from)),\(Self.iso(r.to))"))
        }
        return items
    }

    private static func iso(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

enum SortField: String, CaseIterable, Identifiable, Sendable {
    case paymentDate = "Data de pagamento"
    case paymentAmount = "Valor"
    var id: String { rawValue }

    /// Campo `orderBy` aceito pela mobile-api (GET /packages).
    var apiOrderBy: String { self == .paymentAmount ? "paymentAmount" : "paymentDate" }
}

enum SortDirection: Sendable {
    case ascending, descending
    var toggled: SortDirection { self == .ascending ? .descending : .ascending }
    var symbol: String { self == .ascending ? "arrow.up" : "arrow.down" }
    var apiValue: String { self == .ascending ? "asc" : "desc" }
}

/// Filtragem client-side de refino sobre as páginas já carregadas (status dentro da tab / busca /
/// alto valor). A ordenação e a paginação são feitas no SERVIDOR (GET /packages orderBy+sort+page),
/// então a ordem das páginas é preservada aqui — não reordenamos no cliente.
enum PayoutFiltering {
    static func apply(_ packages: [Package], filters: PayoutFilters) -> [Package] {
        packages.filter { pkg in
            if !filters.statuses.isEmpty && !filters.statuses.contains(pkg.status) { return false }

            let query = filters.search.trimmingCharacters(in: .whitespaces).lowercased()
            if !query.isEmpty {
                let haystack = (pkg.receiverName + " " + pkg.receiverTaxId).lowercased()
                if !haystack.contains(query) { return false }
            }

            if filters.onlyHighValue {
                let hasHighValue = (pkg.tags ?? []).contains { $0.type == "HIGH_VALUE" }
                if !hasHighValue { return false }
            }
            return true
        }
    }

    static func statusOptions(_ packages: [Package]) -> [PackageStatus] {
        var seen = Set<PackageStatus>()
        packages.forEach { seen.insert($0.status) }
        return PackageStatus.allCases.filter { seen.contains($0) }
    }

    /// Opções de filtro derivadas dos pacotes carregados — fallback no mock (pagador, contraparte,
    /// etiquetas), já que o mock não tem /package-filters.
    static func clientOptions(_ packages: [Package]) -> PackageFilterOptions {
        func countedOptions(_ pairs: [(id: String, name: String)]) -> [FilterOption] {
            var order: [String] = []
            var names: [String: String] = [:]
            var counts: [String: Int] = [:]
            for p in pairs {
                if names[p.id] == nil { order.append(p.id); names[p.id] = p.name }
                counts[p.id, default: 0] += 1
            }
            return order.map { FilterOption(id: $0, name: names[$0] ?? $0, count: counts[$0]) }
        }

        let orgs = countedOptions(packages.compactMap { pkg in
            pkg.organization.map { (id: $0.taxId, name: $0.legalName) }
        }).sorted { $0.name < $1.name }

        let suppliers = countedOptions(packages.compactMap { pkg in
            pkg.supplier?.taxName.map { (id: $0, name: $0) }
        }).sorted { $0.name < $1.name }

        let tags = countedOptions(packages.flatMap { pkg in
            (pkg.tags ?? []).map { (id: $0.type, name: PackageTagInfo.display(for: $0).displayName) }
        }).sorted { ($0.count ?? 0) > ($1.count ?? 0) }

        var categories: [FilterCategory] = []
        if !orgs.isEmpty { categories.append(FilterCategory(key: "organization", title: "Pagador", options: orgs)) }
        if !suppliers.isEmpty { categories.append(FilterCategory(key: "supplier", title: "Contraparte", options: suppliers)) }
        if !tags.isEmpty { categories.append(FilterCategory(key: "tags", title: "Etiquetas", options: tags)) }
        return PackageFilterOptions(categories: categories)
    }
}
