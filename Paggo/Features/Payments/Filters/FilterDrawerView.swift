import SwiftUI

/// The per-field editor pushed (via navigationDestination) inside the filter sheet's NavigationStack.
/// Switches on `field.kind`, reusing SearchableOptionList / DatePicker / BrandTextField. All edits
/// mutate the shared `draft` binding directly — the parent sheet commits on "Aplicar".
/// Dynamic option-backed kinds load their choices LAZY (per categoria, ao abrir o drawer) via
/// `PayoutStore.loadFilterOptions(key:)` — três estados distintos: carregando ("Buscando…"),
/// erro (mensagem + "Tentar novamente") e vazio de verdade ("Nenhuma opção disponível").
/// Static kinds read from `categories` (catálogo fixo do registry).
struct FilterDrawerView: View {
    let field: FilterField
    @Binding var draft: PayoutFilters
    /// Options for optionSet / singleSelect / status fields (loaded categories merged with the static catalog).
    let categories: [FilterCategory]
    let statusOptions: [PackageStatus]

    @Environment(PayoutStore.self) private var store
    @State private var query: String = ""

    var body: some View {
        Group {
            switch field.kind {
            case .optionSet(let key):
                optionSetBody(key: key, single: false)
            case .singleSelect(let key):
                optionSetBody(key: key, single: true)
            case .dateRange(let dateKey):
                dateBody(dateKey)
            case .status:
                statusBody()
            }
        }
        .navigationTitle(field.title)
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
    }

    private func options(for key: String) -> [FilterOption] {
        categories.first { $0.key == key }?.options ?? []
    }

    // MARK: Option set (multi) / single-select (radio)

    @ViewBuilder
    private func optionSetBody(key: String, single: Bool) -> some View {
        let isStatic = PackageFilterOptions.staticOptionKeys.contains(key)
        let state = store.filterOptionsState(for: key)
        // Dinâmicas: últimas opções válidas (last-good sobrevive a refetch falho); estáticas: catálogo.
        let visible = isStatic ? options(for: key) : (state.options ?? [])

        ScrollView {
            if !isStatic, let error = state.error, visible.isEmpty, !state.isLoading {
                errorBody(error, key: key)
            } else {
                SearchableOptionList(
                    options: visible,
                    selectedIDs: draft.selected(key),
                    onToggle: { id in
                        if single {
                            draft.selections[key] = draft.selected(key).contains(id) ? nil : [id]
                        } else {
                            draft.toggle(key, id)
                        }
                    },
                    query: $query,
                    isLoading: !isStatic && state.isLoading && state.options == nil,
                    emptyText: "Nenhuma opção disponível",
                    searchPrompt: "Buscar \(field.title.lowercased())",
                    singleSelect: single
                )
            }
        }
        .task(id: field.id) {
            if !isStatic { await store.loadFilterOptions(key: key) }
        }
    }

    /// Falha ao carregar a categoria (sem last-good para mostrar) — mensagem + retry.
    /// Distinto de "Nenhuma opção disponível": aqui as opções EXISTEM, só não chegaram.
    private func errorBody(_ message: String, key: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Theme.textTertiary)
            Text(message)
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Tentar novamente") { Task { await store.loadFilterOptions(key: key) } }
                .buttonStyle(PrimaryActionStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .padding(.top, Spacing.xxxl)
    }

    // MARK: Status (special — over PackageStatus)

    private func statusBody() -> some View {
        let opts = statusOptions.map { FilterOption(id: $0.rawValue, name: $0.displayLabel, count: nil) }
        return ScrollView {
            SearchableOptionList(
                options: opts,
                selectedIDs: Set(draft.statuses.map(\.rawValue)),
                onToggle: { id in
                    guard let s = PackageStatus(rawValue: id) else { return }
                    if draft.statuses.contains(s) { draft.statuses.remove(s) } else { draft.statuses.insert(s) }
                },
                query: $query,
                searchPrompt: "Buscar status"
            )
        }
    }

    // MARK: Date range

    private func dateBody(_ key: String) -> some View {
        let range = draft.dateRange(key)
        let isOn = !range.isEmpty
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Toggle(isOn: Binding(
                    get: { isOn },
                    set: { on in
                        if on {
                            draft.setDateRange(key, DateRange(from: Date().adding(days: -30), to: Date()))
                        } else {
                            draft.setDateRange(key, DateRange())
                        }
                    }
                )) {
                    Text("Filtrar por período")
                        .font(.brand(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                }
                .tint(Theme.accent)
                .padding(Spacing.md)
                .cardSurface()

                if isOn {
                    VStack(spacing: Spacing.md) {
                        datePicker("De", date: Binding(
                            get: { draft.dateRange(key).from ?? Date() },
                            set: { var r = draft.dateRange(key); r.from = $0; draft.setDateRange(key, r) }
                        ))
                        Divider().overlay(Theme.separator)
                        datePicker("Até", date: Binding(
                            get: { draft.dateRange(key).to ?? Date() },
                            set: { var r = draft.dateRange(key); r.to = $0; draft.setDateRange(key, r) }
                        ))
                    }
                    .padding(Spacing.md)
                    .cardSurface()

                    Button("Limpar período") { draft.setDateRange(key, DateRange()) }
                        .font(.brand(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
        }
    }

    private func datePicker(_ label: String, date: Binding<Date>) -> some View {
        HStack {
            Text(label).font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
            Spacer()
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "pt_BR"))
        }
    }
}
