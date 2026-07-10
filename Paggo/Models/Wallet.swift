import Foundation

// Domínio da Carteira Digital (wallet) — espelha apps/wallet-pwa.
// Valores monetários em **cents** (Int). Converter para reais só na exibição.

/// Organização dona da carteira (shape do contrato: `organization.legalName`).
struct WalletOrganization: Codable, Hashable, Sendable {
    var legalName: String?
}

/// Vínculo usuário↔carteira (shape do contrato: `walletUsers[{userId, pin}]`).
/// O PIN presente ⇒ pagamento exige validação de PIN (RN-15).
struct WalletUser: Codable, Hashable, Sendable {
    let userId: String
    var pin: String?
}

/// Carteira Digital: um limite de gasto lastreado por uma conta bancária.
/// Shape espelha `GET /wallets` do wallet-pwa; `balance` vem do endpoint separado
/// `GET /wallets/{id}/baas/account/balance` e é mesclado pela store.
struct Wallet: Identifiable, Hashable, Sendable, Codable {
    let id: String
    var name: String
    var organization: WalletOrganization?
    var active: Bool
    var limit: Int            // limite disponível (cents)
    var maximumLimit: Int     // limite total (cents)
    var walletUsers: [WalletUser]
    var balance: Int          // saldo da conta lastro (cents) — endpoint separado

    var organizationName: String? { organization?.legalName }

    /// O vínculo do usuário com a carteira tem PIN de transação (RN-15).
    var hasPin: Bool { walletUsers.contains { !($0.pin ?? "").isEmpty } }

    init(id: String, name: String, organization: WalletOrganization? = nil, active: Bool,
         limit: Int, maximumLimit: Int, walletUsers: [WalletUser] = [], balance: Int = 0) {
        self.id = id
        self.name = name
        self.organization = organization
        self.active = active
        self.limit = limit
        self.maximumLimit = maximumLimit
        self.walletUsers = walletUsers
        self.balance = balance
    }

    // `balance` e `walletUsers` podem faltar no JSON (balance é outro endpoint) — o Decodable
    // sintetizado não usa defaults de propriedade, então decodificamos manualmente.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        organization = try c.decodeIfPresent(WalletOrganization.self, forKey: .organization)
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
        limit = try c.decodeIfPresent(Int.self, forKey: .limit) ?? 0
        maximumLimit = try c.decodeIfPresent(Int.self, forKey: .maximumLimit) ?? 0
        walletUsers = try c.decodeIfPresent([WalletUser].self, forKey: .walletUsers) ?? []
        balance = try c.decodeIfPresent(Int.self, forKey: .balance) ?? 0
    }

    /// Limite já utilizado (total − disponível).
    var usedLimit: Int { max(0, maximumLimit - limit) }

    /// O disponível pode ser limitado pelo saldo da conta lastro.
    var isCappedByBalance: Bool { balance < limit }

    /// Disponível exibido — limitado pelo saldo da conta (igual ao web: `min(limit, balance)`).
    var availableLimit: Int { min(limit, balance) }

    /// Fração utilizada (0...1) para a barra de progresso.
    var usedFraction: Double {
        maximumLimit > 0 ? Double(usedLimit) / Double(maximumLimit) : 0
    }
}

/// Método de um pagamento da carteira.
enum WalletPaymentMethod: String, Codable, Sendable, Hashable {
    case key = "KEY"            // Pix por chave
    case qrCode = "QR_CODE"     // Pix QR / copia e cola
    case barcode = "BARCODE"    // boleto

    var isPix: Bool { self == .key || self == .qrCode }

    var label: String {
        switch self {
        case .key, .qrCode: return "Pix"
        case .barcode: return "Código de barras"
        }
    }

    var icon: String {
        switch self {
        case .key, .qrCode: return "qrcode"
        case .barcode: return "barcode"
        }
    }
}

/// Status de um pagamento da carteira.
enum WalletPaymentStatus: String, Codable, Sendable, Hashable {
    case processing = "PROCESSING"
    case confirmed = "CONFIRMED"
    case failed = "FAILED"
    case refunded = "REFUNDED"

    var label: String {
        switch self {
        case .processing: return "Processando"
        case .confirmed: return "Confirmado"
        case .failed: return "Falhou"
        case .refunded: return "Estornado"
        }
    }

    var badgeVariant: BadgeVariant {
        switch self {
        case .processing: return .warning
        case .confirmed: return .success
        case .failed: return .danger
        case .refunded: return .neutral
        }
    }
}

/// Um pagamento (transação) da carteira — item do extrato.
struct WalletPayment: Identifiable, Hashable, Sendable, Codable {
    let id: String
    var amount: Int            // cents
    var receiverName: String
    var receiverTaxId: String
    var method: WalletPaymentMethod
    var status: WalletPaymentStatus
    var createdAt: String      // ISO-8601
    var released: Bool         // "Validada"
    var hasAttachments: Bool
    var allocationPending: Bool
    var intentId: String?      // intent que originou o pagamento
    var description: String?   // descrição editável (enriquecimento pós-pagamento)

    /// Há pendências a resolver (sem anexo OU alocação pendente).
    var hasPendencies: Bool { !hasAttachments || allocationPending }
}
