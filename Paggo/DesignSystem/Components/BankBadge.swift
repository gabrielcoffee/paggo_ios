import SwiftUI

/// Resolve um asset de logo de banco a partir do código COMPE / nome.
/// Os logos vêm de `@paggo/icons` (mesmos do web), embarcados em Assets.xcassets como `bank-*`.
enum BankLogo {
    /// COMPE code → asset name.
    private static let byCode: [String: String] = [
        "001": "bank-bb", "033": "bank-santander", "077": "bank-inter",
        "104": "bank-caixa", "197": "bank-stone", "208": "bank-btg",
        "237": "bank-bradesco", "260": "bank-nubank", "290": "bank-pagseguro",
        "323": "bank-mercadopago", "336": "bank-c6", "341": "bank-itau",
        "348": "bank-xp", "380": "bank-picpay", "422": "bank-safra",
        "655": "bank-neon", "735": "bank-neon", "741": "bank-original",
    ]

    /// Substrings de nome → asset (fallback quando o código não bate).
    private static let byName: [(String, String)] = [
        ("itau", "bank-itau"), ("itaú", "bank-itau"), ("bradesc", "bank-bradesco"),
        ("nubank", "bank-nubank"), ("nu pagamentos", "bank-nubank"),
        ("banco do brasil", "bank-bb"), ("inter", "bank-inter"), ("caixa", "bank-caixa"),
        ("btg", "bank-btg"), ("santander", "bank-santander"), ("safra", "bank-safra"),
        ("pagseguro", "bank-pagseguro"), ("pagbank", "bank-pagseguro"),
        ("mercado pago", "bank-mercadopago"), ("mercadopago", "bank-mercadopago"),
        ("stone", "bank-stone"), ("picpay", "bank-picpay"), ("will", "bank-will"),
        ("neon", "bank-neon"), ("next", "bank-next"), ("sicoob", "bank-sicoob"),
        ("sicredi", "bank-sicredi"), ("banrisul", "bank-banrisul"), ("bmg", "bank-bmg"),
        ("cora", "bank-cora"), ("original", "bank-original"), ("unicred", "bank-unicred"),
        ("daycoval", "bank-daycoval"), ("xp", "bank-xp"), ("c6", "bank-c6"),
    ]

    /// Asset name para a conta, ou `nil` quando não há logo conhecido.
    static func asset(for account: BankAccount) -> String? {
        if let a = matchCode(account.bankCode) { return a }
        let haystack = (account.bank.name + " " + account.bank.shortName).lowercased()
        if let match = byName.first(where: { haystack.contains($0.0) }) { return match.1 }
        // Conta interna Paggo (não-externa, sem banco conhecido) → marca Paggo.
        if !account.isExternal { return "bank-paggo" }
        return nil
    }

    /// COMPE codes chegam como "341" (mock) ou "00000341" (live) — normaliza antes de procurar.
    private static func matchCode(_ raw: String) -> String? {
        if let a = byCode[raw] { return a }
        let trimmed = String(raw.drop(while: { $0 == "0" }))
        guard !trimmed.isEmpty else { return nil }
        if let a = byCode[trimmed] { return a }
        let padded = String(repeating: "0", count: max(0, 3 - trimmed.count)) + trimmed
        return byCode[padded]
    }
}

/// Avatar circular com o logo do banco (full-bleed), com fallback para ícone genérico.
struct BankBadge: View {
    let account: BankAccount
    var size: CGFloat = 42
    var ring: Bool = true
    /// Monocromático — visual mais sóbrio/sofisticado nas listas.
    var grayscale: Bool = false

    var body: some View {
        let asset = BankLogo.asset(for: account)
        Group {
            if asset == "bank-paggo" {
                // A marca Paggo enche o tile de ponta a ponta; recua-a para dar respiro dentro do
                // círculo, sobre um fundo do MESMO terracota (#B0572C) — o padding não vira anel branco.
                Color(hex: "#B0572C")
                    .overlay {
                        Image("bank-paggo")
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.14)
                    }
            } else if let asset {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: size, height: size)
                    .background(Theme.surfaceHigh)
            }
        }
        .frame(width: size, height: size)
        .background(.white)
        .clipShape(Circle())
        // Dessatura e levanta o brilho um pouco para os logos escuros não sumirem no fundo escuro.
        .saturation(grayscale ? 0 : 1)
        .brightness(grayscale ? 0.06 : 0)
        .overlay {
            if ring { Circle().stroke(Theme.stroke, lineWidth: 0.5) }
        }
    }
}
