import Foundation

/// Janelas de tempo do histórico de saldo (espelha as opções do web BalanceHistoryChart).
enum BalanceHistoryRange: String, CaseIterable, Identifiable, Sendable {
    case last30
    case last60
    case thisMonth
    case thisYear

    var id: String { rawValue }

    /// Rótulo completo (no menu).
    var label: String {
        switch self {
        case .last30: return "Últimos 30 dias"
        case .last60: return "Últimos 60 dias"
        case .thisMonth: return "Mês atual"
        case .thisYear: return "Ano atual"
        }
    }

    /// Rótulo curto (chip / subtítulo).
    var shortLabel: String {
        switch self {
        case .last30: return "30 dias"
        case .last60: return "60 dias"
        case .thisMonth: return "Mês"
        case .thisYear: return "Ano"
        }
    }

    /// Texto do delta ("nos últimos 30 dias").
    var deltaCaption: String {
        switch self {
        case .last30: return "nos últimos 30 dias"
        case .last60: return "nos últimos 60 dias"
        case .thisMonth: return "no mês atual"
        case .thisYear: return "no ano atual"
        }
    }

    /// Intervalo [start, end] em `yyyy-MM-dd` (UTC), calculado a partir de `now`.
    func dates(now: Date = Date()) -> (start: String, end: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let end = now
        let start: Date
        switch self {
        case .last30: start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        case .last60: start = calendar.date(byAdding: .day, value: -60, to: end) ?? end
        case .thisMonth:
            start = calendar.date(from: calendar.dateComponents([.year, .month], from: end)) ?? end
        case .thisYear:
            start = calendar.date(from: calendar.dateComponents([.year], from: end)) ?? end
        }
        return (Self.iso.string(from: start), Self.iso.string(from: end))
    }

    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
