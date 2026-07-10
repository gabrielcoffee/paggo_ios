import SwiftUI

/// A searchable, multi-select list of `FilterOption`s with checkmarks and optional counts.
/// Works both as a self-filtering static list and as a server-side search surface (the parent
/// owns the query and supplies pre-filtered options + a loading flag).
struct SearchableOptionList: View {
    let options: [FilterOption]
    let selectedIDs: Set<String>
    var onToggle: (String) -> Void

    /// Search text. When `serverSideSearch` is true the parent reacts to changes and supplies
    /// pre-filtered `options`; otherwise the list filters `options` locally.
    @Binding var query: String
    var isLoading: Bool = false
    var emptyText: String = "Nada encontrado"
    var searchPrompt: String = "Buscar"
    /// When true, do NOT locally filter `options` (parent already searched server-side).
    var serverSideSearch: Bool = false
    /// Radio affordance (single-choice) instead of checkboxes.
    var singleSelect: Bool = false

    private var visible: [FilterOption] {
        if serverSideSearch { return options }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return options }
        return options.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            searchField

            if isLoading {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("Buscando…")
                        .font(.brand(.caption))
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, Spacing.lg)
            } else if visible.isEmpty {
                Text(emptyText)
                    .font(.brand(.subheadline))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Spacing.xl)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(visible) { option in
                        row(for: option)
                        if option.id != visible.last?.id {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }

    private var searchField: some View {
        BrandTextField(searchPrompt, text: $query)
    }

    private func iconName(selected: Bool) -> String {
        if singleSelect { return selected ? "largecircle.fill.circle" : "circle" }
        return selected ? "checkmark.circle.fill" : "circle"
    }

    private func row(for option: FilterOption) -> some View {
        Button { onToggle(option.id) } label: {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .font(.brand(.subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if let count = option.count {
                        Text("\(count)")
                            .font(.brand(.caption2))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: iconName(selected: selectedIDs.contains(option.id)))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selectedIDs.contains(option.id) ? Theme.accent : Theme.textTertiary)
            }
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
