import Foundation

/// Normalização de chave Pix antes do DICT — porta as regras do wallet-pwa
/// (`pages/api/wallets/[id]/intents/pix/dict.ts`):
/// - CNPJ válido (14 dígitos) → só dígitos
/// - 13 dígitos começando com 55 → prefixo `+`
/// - 12 dígitos começando com 0 → `+55` + resto
/// - 11 dígitos → CPF se válido; senão telefone `+55…`
/// - 10 dígitos → telefone `+55…`
/// - e-mail / chave aleatória (EVP) → inalterados
enum PixKeyNormalizer {
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let numeric = trimmed.filter(\.isNumber)

        if numeric.count == 14, isValidCNPJ(numeric) { return numeric }
        if numeric.count == 13, numeric.hasPrefix("55") { return "+" + numeric }
        if numeric.count == 12, numeric.hasPrefix("0") { return "+55" + numeric.dropFirst() }
        if numeric.count == 11 { return isValidCPF(numeric) ? numeric : "+55" + numeric }
        if numeric.count == 10 { return "+55" + numeric }
        return trimmed
    }

    /// Um EMV (Pix Copia e Cola) colado no campo de chave deve ser rejeitado (RN-12) —
    /// mesma heurística do `isPixQRCode` do wallet-pwa.
    static func looksLikeEmv(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("000201") || t.lowercased().contains("br.gov.bcb.pix")
    }

    /// Rótulo do tipo da chave normalizada (exibição).
    static func typeLabel(_ normalized: String) -> String {
        if normalized.contains("@") { return "E-mail" }
        if normalized.hasPrefix("+") { return "Telefone" }
        let numeric = normalized.filter(\.isNumber)
        if numeric.count == 11, numeric == normalized { return "CPF" }
        if numeric.count == 14, numeric == normalized { return "CNPJ" }
        if normalized.count == 36 { return "Aleatória" }
        return "Chave"
    }

    // MARK: Validação de dígitos verificadores

    static func isValidCPF(_ digits: String) -> Bool {
        let nums = digits.compactMap(\.wholeNumberValue)
        guard nums.count == 11, Set(nums).count > 1 else { return false }
        func check(_ count: Int) -> Int {
            let sum = (0..<count).reduce(0) { $0 + nums[$1] * (count + 1 - $1) }
            let mod = (sum * 10) % 11
            return mod == 10 ? 0 : mod
        }
        return check(9) == nums[9] && check(10) == nums[10]
    }

    static func isValidCNPJ(_ digits: String) -> Bool {
        let nums = digits.compactMap(\.wholeNumberValue)
        guard nums.count == 14, Set(nums).count > 1 else { return false }
        func check(_ weights: [Int]) -> Int {
            let sum = zip(nums, weights).reduce(0) { $0 + $1.0 * $1.1 }
            let mod = sum % 11
            return mod < 2 ? 0 : 11 - mod
        }
        let w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
        let w2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
        return check(w1) == nums[12] && check(w2) == nums[13]
    }
}
