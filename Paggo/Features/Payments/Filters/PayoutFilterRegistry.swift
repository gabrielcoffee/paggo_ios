import SwiftUI

/// Single source of truth for the payout filter list — full parity with the web payout filters
/// (`apps/blue/src/modules/payout/filters/filter-configurations.ts`). Every filter is ALWAYS shown
/// (not gated on loaded options); option-backed filters load their choices LAZY from
/// GET /package-filters (`active_filter=<key>`, one category per request, ao abrir o drawer) or
/// from the static catalog below (fixed enums). Query-param names target the mobile-api
/// contract (camelCase identity for most; snake_case aliases where the backend expects them).
enum PayoutFilterRegistry {
    /// Optional SF Symbols per field id (purely cosmetic leading icon).
    private static let icons: [String: String] = [
        "status": "circle.grid.2x2",
        "organization": "building.2", "supplier": "person.crop.square",
        "type": "shippingbox", "paymentMethod": "creditcard", "tags": "tag",
        "project": "folder", "costCenter": "chart.pie", "managerialAccount": "doc.text",
        "unit": "building", "requesters": "person", "companyTags": "tag.circle",
        "financialInstitution": "banknote", "document": "doc",
        "createdFrom": "arrow.triangle.branch", "bankingAccount": "building.columns",
        "documentConnected": "link", "onTime": "clock",
        "beneficiary_name": "person.text.rectangle", "beneficiary_tax_id": "number",
    ]

    /// Single-select option-backed filters (radio semantics — one value at a time).
    static let singleSelectKeys: Set<String> = ["onTime"]

    /// Build the full ordered field list. `statusOptions.count > 1` gates the Status field.
    static func fields(statusOptions: [PackageStatus]) -> [FilterField] {
        var out: [FilterField] = []

        // 1. Status (special — within the tab).
        if statusOptions.count > 1 {
            out.append(.init(id: "status", title: "Status", icon: icons["status"], kind: .status))
        }

        // 2. Option-backed category fields (driven by PackageFilterOptions.order). onTime is single-select.
        //    Includes beneficiary (option-backed selects served by /package-filters).
        for (key, title, _) in PackageFilterOptions.order {
            let kind: FilterFieldKind = singleSelectKeys.contains(key)
                ? .singleSelect(categoryKey: key)
                : .optionSet(categoryKey: key)
            out.append(.init(id: key, title: title, icon: icons[key], kind: kind))
        }

        // 3. Dates (driven by PayoutFilters.dateFilters).
        for (key, title, _) in PayoutFilters.dateFilters {
            out.append(.init(id: key, title: title, icon: "calendar", kind: .dateRange(dateKey: key)))
        }

        return out
    }

    /// Fixed-enum option sets that /package-filters does not serve. Merged into the loaded
    /// categories so their drawers/chips/summaries resolve labels uniformly. Mirrors web
    /// `filter-options.ts` (paymentMethods, document) + `filter-configurations.ts` (documentConnected, on_time).
    static let staticCategories: [FilterCategory] = [
        FilterCategory(key: "paymentMethod", title: "Método de Pagamento", options: [
            FilterOption(id: "UNSET", name: "Não informado", count: nil),
            FilterOption(id: "BANKSLIP", name: "Boleto", count: nil),
            FilterOption(id: "BARCODE", name: "Guia", count: nil),
            FilterOption(id: "PIX_BY_ACCOUNT", name: "Dados Bancários", count: nil),
            FilterOption(id: "PIX", name: "Chave Pix", count: nil),
            FilterOption(id: "PIX_QR", name: "Pix Copia e Cola", count: nil),
        ]),
        FilterCategory(key: "document", title: "Documento", options: [
            FilterOption(id: "FISCAL_INVOICE", name: "Nota Fiscal", count: nil),
            FilterOption(id: "FISCAL_INVOICE_PRODUCT", name: "Nota Fiscal de Produto", count: nil),
            FilterOption(id: "FISCAL_INVOICE_SERVICE", name: "Nota Fiscal de Serviço", count: nil),
            FilterOption(id: "DOWN_PAYMENT", name: "Adiantamento", count: nil),
            FilterOption(id: "OTHER", name: "Outro", count: nil),
        ]),
        FilterCategory(key: "documentConnected", title: "Conexão com Documento", options: [
            FilterOption(id: "posted", name: "Lançado", count: nil),
            FilterOption(id: "recognized", name: "Reconhecido", count: nil),
            FilterOption(id: "empty", name: "Não Conectado", count: nil),
        ]),
        // "Ver todos" (web on_time=false default) is omitted: no-selection already means "no filter",
        // so only the two meaningful values are offered.
        FilterCategory(key: "onTime", title: "Atraso", options: [
            FilterOption(id: "true", name: "Ocultar atrasados", count: nil),
            FilterOption(id: "nofuture", name: "Ocultar futuros", count: nil),
        ]),
    ]
}
