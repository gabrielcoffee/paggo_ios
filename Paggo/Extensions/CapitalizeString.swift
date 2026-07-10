import Foundation

/// Conectivos que permanecem minúsculos (exceto quando são a primeira palavra).
private let noCapitalizeWords: Set<String> = [
    "de", "e", "da", "do", "das", "dos", "em", "com", "por", "a", "as", "o", "os", "na", "no",
    "nas", "nos", "um", "uma", "uns", "umas", "à", "às", "para", "ao", "aos", "sobre", "sob",
    "pelo", "pelos", "pela", "pelas", "ante", "após", "perante", "sem", "ou", "mas", "nem", "que",
    "se", "como", "quando", "porém", "porque", "àquela", "àquele", "àquelas", "àqueles", "até",
    "desde", "durante", "não", "sim", "algum", "alguma", "nenhum", "nenhuma", "qual", "quais",
    "cada", "este", "esta", "isto", "esse", "essa", "isso", "aquele", "aquela", "aquilo", "também",
    "embora", "contudo", "entretanto", "todavia", "apesar",
]

/// Siglas / sufixos societários que permanecem em caixa alta.
private let upperCaseWords: Set<String> = [
    "sa", "s.a.", "s.a", "me", "s/a", "ltda", "cdb", "cri", "cra", "lci", "lca", "lc", "lig", "lf",
    "etf",
]

extension String {
    /// Porta fiel de `capitalizeString` (packages/paggo-core-utils/src/string/formatters.ts): Title
    /// Case pt-BR que preserva conectivos minúsculos (de/da/do…) e siglas/sufixos em caixa alta
    /// (LTDA/SA/ME…), diferente de `String.capitalized` (que rebaixa "LTDA" → "Ltda").
    var capitalizedNamePtBr: String {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !normalized.isEmpty else { return "" }
        let words = normalized.lowercased().split(separator: " ", omittingEmptySubsequences: true)
        let processed = words.enumerated().map { index, wordSub -> String in
            let word = String(wordSub)
            if index > 0, noCapitalizeWords.contains(word) { return word }
            if upperCaseWords.contains(word) { return word.uppercased() }
            return word.prefix(1).uppercased() + word.dropFirst()
        }
        return processed.joined(separator: " ")
    }
}
