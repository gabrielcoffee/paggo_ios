import SwiftUI

/// Mercury-style payout filter sheet. Drop-in replacement for `FilterSheet` (same init signature
/// plus a defaulted `searchOptions` provider for server-side dynamic search).
///
/// Layout: a global search box, a "Selecionados" section of removable chips with "Limpar tudo",
/// an inline "Somente alto valor" toggle, and a grouped vertical list of filter rows. Each row
/// opens a drawer (FilterDrawerView) listing all options for that filter. The list is declarative:
/// adding a filter is one entry in PayoutFilterRegistry / PackageFilterOptions.order / dateFilters.
struct FilterSheetView: View {
    let statusOptions: [PackageStatus]
    let categories: [FilterCategory]
    var onApply: (PayoutFilters) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: PayoutFilters
    @State private var openField: FilterField?

    init(currentFilters: PayoutFilters,
         statusOptions: [PackageStatus],
         categories: [FilterCategory],
         onApply: @escaping (PayoutFilters) -> Void) {
        self.statusOptions = statusOptions
        self.categories = categories
        self.onApply = onApply
        self._draft = State(initialValue: currentFilters)
    }

    /// Categories already lazy-loaded per drawer (labels for chips/summaries) merged with the
    /// fixed-enum catalog (payment method, document, document connection, atraso). The sheet list
    /// itself needs no options — each drawer loads its own category on open.
    private var allCategories: [FilterCategory] { categories + PayoutFilterRegistry.staticCategories }

    private var fields: [FilterField] {
        PayoutFilterRegistry.fields(statusOptions: statusOptions)
    }

    private var allChips: [FilterFieldChip] {
        fields.flatMap { $0.chips(in: draft, categories: allCategories) }
            + (draft.onlyHighValue ? [highValueChip] : [])
    }

    var body: some View {
        SheetScaffold(title: "Filtros", closePlacement: .topBarLeading, detents: [.large]) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if !allChips.isEmpty { selectedSection }
                    fieldList
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, 120)   // room for the bottom bar
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .searchable(text: $draft.search, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Buscar por recebedor ou documento")
            .navigationDestination(item: $openField) { field in
                FilterDrawerView(field: field, draft: $draft, categories: allCategories,
                                 statusOptions: statusOptions)
            }
            .task {
                // Debug: PAGGO_OPEN_FILTER=<id> abre direto o drawer daquele filtro (verificação de UI).
                if let id = ProcessInfo.processInfo.environment["PAGGO_OPEN_FILTER"] {
                    openField = fields.first { $0.id == id }
                }
            }
            .safeAreaInset(edge: .bottom) { applyBar }
        }
    }

    // MARK: Selecionados

    private var selectedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                SectionHeader("Selecionados")
                Spacer()
                Button("Limpar tudo") { withAnimation { draft = PayoutFilters() } }
                    .font(.brand(.caption, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: Spacing.sm, alignment: .leading)],
                      alignment: .leading, spacing: Spacing.sm) {
                ForEach(allChips) { chip in
                    FilterChip(title: chip.label) { withAnimation { chip.remove(&draft) } }
                }
            }
        }
    }

    // MARK: Field list (flat rows + hairline dividers — same surface as the account picker)

    private var fieldList: some View {
        VStack(spacing: 0) {
            highValueRow
            if !fields.isEmpty { rowDivider }
            ForEach(fields) { field in
                DisclosureRow(
                    title: field.title,
                    icon: field.icon,
                    value: field.summary(in: draft, categories: allCategories)
                ) { openField = field }
                if field.id != fields.last?.id { rowDivider }
            }
        }
    }

    private var rowDivider: some View { Divider().overlay(Theme.separator) }

    /// "Somente alto valor" — inline convenience toggle (no drawer), styled as a list row.
    private var highValueRow: some View {
        Toggle(isOn: $draft.onlyHighValue) {
            HStack(spacing: Spacing.md) {
                TintedIcon(symbol: "star.circle", tint: Theme.accent, size: 32, symbolSize: 13)
                Text("Somente alto valor")
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .tint(Theme.accent)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: Apply bar

    private var applyBar: some View {
        BottomActionBar {
            Button { apply() } label: {
                Text("Aplicar").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionStyle())
        }
    }

    // MARK: Actions

    private func apply() {
        onApply(draft)
        dismiss()
    }

    private var highValueChip: FilterFieldChip {
        FilterFieldChip(id: "highValue", label: "Somente alto valor") { draft in
            draft.onlyHighValue = false
        }
    }
}
