import SwiftUI

/// What kind of editor a filter row opens in its drawer.
enum FilterFieldKind {
    /// Multi-select over an option set (from loaded /package-filters categories or the static catalog).
    case optionSet(categoryKey: String)
    /// Single-select over an option set (radio — one value at a time, e.g. "Atraso").
    case singleSelect(categoryKey: String)
    /// From/to date pickers. `dateKey` matches a PayoutFilters.dateFilters key.
    case dateRange(dateKey: String)
    /// Special-case multi-select over PackageStatus (not a category key; lives in `statuses`).
    case status
}

/// One declarative filter row. Adding a filter = appending one of these to the registry.
struct FilterField: Identifiable, Hashable {
    let id: String          // stable id (category key / date key / "status" / "beneficiaryName" …)
    let title: String       // PT-BR label shown on the row + chip prefix
    let icon: String?       // optional SF Symbol for the leading TintedIcon
    let kind: FilterFieldKind

    init(id: String, title: String, icon: String? = nil, kind: FilterFieldKind) {
        self.id = id
        self.title = title
        self.icon = icon
        self.kind = kind
    }

    // Identity is the stable id — enough for ForEach + navigationDestination(item:).
    static func == (lhs: FilterField, rhs: FilterField) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A removable chip for the "Selecionados" section. Carries its own removal mutation so the sheet
/// stays declarative (no per-field switch in the view).
struct FilterFieldChip: Identifiable {
    let id: String                          // unique per chip (fieldID + optionID)
    let label: String
    let remove: (inout PayoutFilters) -> Void
}

extension FilterField {
    /// pt-BR date formatter for chip/summary labels (dd/MM).
    private static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM"
        return f
    }()

    private func optionName(_ key: String, _ id: String, _ categories: [FilterCategory]) -> String {
        categories.first { $0.key == key }?.options.first { $0.id == id }?.name ?? id
    }

    private func formatRange(_ range: DateRange) -> String {
        let from = range.from.map { Self.dayMonth.string(from: $0) }
        let to = range.to.map { Self.dayMonth.string(from: $0) }
        switch (from, to) {
        case let (.some(f), .some(t)): return "\(f) – \(t)"
        case let (.some(f), .none): return "A partir de \(f)"
        case let (.none, .some(t)): return "Até \(t)"
        case (.none, .none): return ""
        }
    }

    /// Is this field currently contributing to the filter?
    func isActive(in f: PayoutFilters) -> Bool {
        switch kind {
        case .optionSet(let key), .singleSelect(let key):
            return !f.selected(key).isEmpty
        case .dateRange(let dateKey):
            return !f.dateRange(dateKey).isEmpty
        case .status:
            return !f.statuses.isEmpty
        }
    }

    /// Removable chips for the "Selecionados" section. One chip per selected id for multi-select.
    func chips(in f: PayoutFilters, categories: [FilterCategory]) -> [FilterFieldChip] {
        switch kind {
        case .optionSet(let key), .singleSelect(let key):
            return f.selected(key).sorted().map { id in
                let name = optionName(key, id, categories)
                return FilterFieldChip(id: "\(self.id):\(id)", label: "\(title): \(name)") { draft in
                    draft.toggle(key, id)
                }
            }
        case .status:
            return f.statuses.map(\.rawValue).sorted().map { raw in
                let name = PackageStatus(rawValue: raw)?.displayLabel ?? raw
                return FilterFieldChip(id: "status:\(raw)", label: "\(title): \(name)") { draft in
                    if let s = PackageStatus(rawValue: raw) { draft.statuses.remove(s) }
                }
            }
        case .dateRange(let dateKey):
            let range = f.dateRange(dateKey)
            guard !range.isEmpty else { return [] }
            return [FilterFieldChip(id: "date:\(dateKey)", label: "\(title): \(formatRange(range))") { draft in
                draft.setDateRange(dateKey, DateRange())
            }]
        }
    }

    /// Clears just this field from the draft.
    func clear(in f: inout PayoutFilters) {
        switch kind {
        case .optionSet(let key), .singleSelect(let key):
            f.selections[key] = nil
        case .dateRange(let dateKey):
            f.setDateRange(dateKey, DateRange())
        case .status:
            f.statuses = []
        }
    }

    /// Trailing summary string for the DisclosureRow ("2 selecionados", a date span, …).
    func summary(in f: PayoutFilters, categories: [FilterCategory]) -> String? {
        switch kind {
        case .optionSet(let key), .singleSelect(let key):
            let ids = f.selected(key)
            switch ids.count {
            case 0: return nil
            case 1: return optionName(key, ids.first ?? "", categories)
            default: return "\(ids.count) selecionados"
            }
        case .status:
            let count = f.statuses.count
            switch count {
            case 0: return nil
            case 1: return f.statuses.first?.displayLabel
            default: return "\(count) selecionados"
            }
        case .dateRange(let dateKey):
            let range = f.dateRange(dateKey)
            return range.isEmpty ? nil : formatRange(range)
        }
    }
}
