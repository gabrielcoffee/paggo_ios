import Foundation

/// ISO-8601 parsing + pt-BR display formatting. The mobile-app DTOs carry dates as ISO strings
/// (`new Date().toISOString()`), so we parse those strings and format with the Brazilian locale.
enum DateText {
    static let ptBR = Locale(identifier: "pt_BR")

    /// Parses an ISO string, tolerating both full timestamps (with/without fractional seconds)
    /// and plain `yyyy-MM-dd` dates.
    static func parse(_ iso: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: iso) { return d }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: iso) { return d }

        let dateOnly = DateFormatter()
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.dateFormat = "yyyy-MM-dd"
        return dateOnly.date(from: iso)
    }

    private static func formatted(_ iso: String, _ pattern: String) -> String {
        guard let date = parse(iso) else { return "—" }
        let f = DateFormatter()
        f.locale = ptBR
        f.dateFormat = pattern
        return f.string(from: date)
    }

    /// `15/01/2024`
    static func full(_ iso: String) -> String { formatted(iso, "dd/MM/yyyy") }

    /// `15/01`
    static func short(_ iso: String) -> String { formatted(iso, "dd/MM") }

    /// `15/01/24`
    static func shortYear(_ iso: String) -> String { formatted(iso, "dd/MM/yy") }

    /// `15 jan` (month lowercased, no trailing dot)
    static func withMonth(_ iso: String) -> String {
        formatted(iso, "dd MMM").replacingOccurrences(of: ".", with: "")
    }

    /// Relative, localized, e.g. `há 2 dias`.
    static func relative(_ iso: String) -> String {
        guard let date = parse(iso) else { return "—" }
        let f = RelativeDateTimeFormatter()
        f.locale = ptBR
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
}

extension Date {
    private static let ptBR = Locale(identifier: "pt_BR")

    /// Short month label, e.g. `Mar`.
    var shortMonth: String {
        let f = DateFormatter()
        f.locale = Date.ptBR
        f.dateFormat = "MMM"
        return f.string(from: self).replacingOccurrences(of: ".", with: "").capitalized
    }

    /// Day/month label, e.g. `12/06`.
    var dayMonth: String {
        let f = DateFormatter()
        f.locale = Date.ptBR
        f.dateFormat = "dd/MM"
        return f.string(from: self)
    }

    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }

    /// ISO-8601 string with fractional seconds (mirrors JS `toISOString()`).
    var isoString: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: self)
    }
}
