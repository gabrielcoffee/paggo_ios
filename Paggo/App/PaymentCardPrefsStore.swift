import Foundation
import Observation

/// Preferências de visualização dos cartões de pagamento (quais campos aparecem na listagem).
/// Persistidas apenas no dispositivo (`UserDefaults`) — o backend é intencionalmente local/mockado
/// por enquanto; quando o mobile-api expuser preferências de layout, este store sincroniza lá.
///
/// Espelha `NotificationPrefsStore`: `@MainActor @Observable`, singleton `.shared`, JSON em
/// `UserDefaults`. `Valor`, `Data Agendamento` e `Recebedor` são fixos (sempre visíveis) e por isso
/// não têm flag aqui; `Multa`/`Juros` ainda não estão disponíveis ("Em breve").
@MainActor
@Observable
final class PaymentCardPrefsStore {
    static let shared = PaymentCardPrefsStore()

    /// Estrutura persistida. O `init(from:)` customizado usa `decodeIfPresent` por chave para que
    /// um blob legado (que só tinha `showPayer`/`showTags`) NÃO zere os campos novos nem os antigos:
    /// cada chave ausente cai para o seu default individual em vez de resetar a struct inteira.
    struct Prefs: Codable, Equatable, Sendable {
        var showPayer = false               // "Pagador" — desligado por padrão
        var showTags = true                 // "Etiquetas" — ligado por padrão
        var showManagerialAccount = false   // "Conta Gerencial" — desligado por padrão
        var showCostCenter = false          // "Centro de Custo" — desligado por padrão
        var showDocument = false            // "Documento" — desligado por padrão

        init(showPayer: Bool = false,
             showTags: Bool = true,
             showManagerialAccount: Bool = false,
             showCostCenter: Bool = false,
             showDocument: Bool = false) {
            self.showPayer = showPayer
            self.showTags = showTags
            self.showManagerialAccount = showManagerialAccount
            self.showCostCenter = showCostCenter
            self.showDocument = showDocument
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Prefs()
            showPayer = (try? c.decodeIfPresent(Bool.self, forKey: .showPayer)) ?? d.showPayer
            showTags = (try? c.decodeIfPresent(Bool.self, forKey: .showTags)) ?? d.showTags
            showManagerialAccount =
                (try? c.decodeIfPresent(Bool.self, forKey: .showManagerialAccount)) ?? d.showManagerialAccount
            showCostCenter =
                (try? c.decodeIfPresent(Bool.self, forKey: .showCostCenter)) ?? d.showCostCenter
            showDocument = (try? c.decodeIfPresent(Bool.self, forKey: .showDocument)) ?? d.showDocument
        }
    }

    /// Exibe o bloco "Pagador → Contraparte" no cartão. Padrão: `false`.
    var showPayer: Bool {
        didSet { persist() }
    }

    /// Exibe a linha de etiquetas do cartão. Padrão: `true`.
    var showTags: Bool {
        didSet { persist() }
    }

    /// Exibe a linha "Conta Gerencial" no cartão. Padrão: `false`.
    var showManagerialAccount: Bool {
        didSet { persist() }
    }

    /// Exibe a linha "Centro de Custo" no cartão. Padrão: `false`.
    var showCostCenter: Bool {
        didSet { persist() }
    }

    /// Exibe a linha "Documento" no cartão. Padrão: `false`.
    var showDocument: Bool {
        didSet { persist() }
    }

    private static let storageKey = "paggo.paymentCardPrefs"

    init() {
        let decoded: Prefs
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let parsed = try? JSONDecoder().decode(Prefs.self, from: data) {
            decoded = parsed
        } else {
            decoded = Prefs()
        }
        self.showPayer = decoded.showPayer
        self.showTags = decoded.showTags
        self.showManagerialAccount = decoded.showManagerialAccount
        self.showCostCenter = decoded.showCostCenter
        self.showDocument = decoded.showDocument
    }

    /// Restaura os padrões (todos os campos aos seus valores default).
    func reset() {
        let d = Prefs()
        showPayer = d.showPayer
        showTags = d.showTags
        showManagerialAccount = d.showManagerialAccount
        showCostCenter = d.showCostCenter
        showDocument = d.showDocument
    }

    private func persist() {
        let prefs = Prefs(showPayer: showPayer,
                          showTags: showTags,
                          showManagerialAccount: showManagerialAccount,
                          showCostCenter: showCostCenter,
                          showDocument: showDocument)
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
