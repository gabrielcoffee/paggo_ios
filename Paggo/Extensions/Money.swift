import Foundation

/// Money formatting. Faithful to the mobile-app contract: **all monetary values are in cents**
/// (integers). Convert to reais (divide by 100) only at display time.
extension Int {
    /// Cents → reais as a `Double`.
    var asReais: Double { Double(self) / 100 }

    /// Exact BRL string from cents, e.g. `2500000` → `R$ 25.000,00`.
    func currencyFromCents() -> String { asReais.currencyExact() }

    /// Compact BRL string from cents, e.g. `2500000` → `R$ 25 mil`, `156780050` → `R$ 1,57 mi`.
    func currencyCompactFromCents() -> String { asReais.currencyCompact() }
}

extension Double {
    private static let brl = Locale(identifier: "pt_BR")

    /// Exact BRL currency string with two fraction digits, e.g. `R$ 1.234,56`.
    func currencyExact(code: String = "BRL") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = Double.brl
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// Exact BRL currency string with configurable fraction digits (default 0).
    func currency(code: String = "BRL", fractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = Double.brl
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// Compact BRL for large figures, e.g. `R$ 1,45 mi`, `R$ 506 mil`, `R$ 320`.
    func currencyCompact(code: String = "BRL") -> String {
        let v = abs(self)
        let sign = self < 0 ? "-" : ""
        if v >= 1_000_000 {
            return "\(sign)R$ \(decimalString(v / 1_000_000, places: 2)) mi"
        }
        if v >= 1_000 {
            return "\(sign)R$ \(Int((v / 1_000).rounded())) mil"
        }
        return "\(sign)R$ \(Int(v.rounded()))"
    }

    /// Abbreviated form for chart axis labels, e.g. `1,5 mi`, `500 mil`.
    func abbreviated() -> String {
        let v = abs(self)
        let sign = self < 0 ? "-" : ""
        if v >= 1_000_000 {
            return "\(sign)\(decimalString(v / 1_000_000, places: 1)) mi"
        }
        if v >= 1_000 {
            return "\(sign)\(Int((v / 1_000).rounded())) mil"
        }
        return "\(sign)\(Int(v))"
    }

    /// Formats with a comma decimal separator (pt-BR).
    private func decimalString(_ value: Double, places: Int) -> String {
        String(format: "%.\(places)f", value).replacingOccurrences(of: ".", with: ",")
    }

    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
