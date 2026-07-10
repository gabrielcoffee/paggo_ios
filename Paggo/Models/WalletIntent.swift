import Foundation

// Modelos transacionais da Carteira — espelham os contratos do wallet-pwa.
// Nomes de campo idênticos ao wire; valores em **cents**.
// Campos tolerantes (opcionais) porque o DICT e o intent usam grafias diferentes para o mesmo
// dado (name/taxId/ispb vs receiverLegalName/receiverTaxId/bankCode) — verificar contra staging
// quando o backend de wallet existir.

/// Tipo de chave Pix (valores do DICT).
enum PixKeyType: String, Codable, Sendable, Hashable {
    case cpf = "CPF"
    case cnpj = "CNPJ"
    case phone = "PHONE"
    case email = "EMAIL"
    case evp = "EVP"          // chave aleatória

    var label: String {
        switch self {
        case .cpf: return "CPF"
        case .cnpj: return "CNPJ"
        case .phone: return "Telefone"
        case .email: return "E-mail"
        case .evp: return "Aleatória"
        }
    }
}

/// Detalhes de uma chave Pix — resposta do DICT (`POST …/intents/pix/dict`) e `keyDetails`
/// do payload de intent. As duas grafias coexistem; use os accessors `display*`.
struct PixKeyDetails: Codable, Hashable, Sendable {
    var id: String?
    var key: String?
    var type: PixKeyType?
    var accountNumber: String?
    var accountType: String?
    var branchCode: String?
    var bankCode: String?          // grafia do intent/decode
    var ispb: String?              // grafia do DICT
    var bankName: String?
    var endToEndId: String?
    var receiverLegalName: String? // grafia do intent/decode
    var receiverTaxId: String?
    var name: String?              // grafia do DICT
    var taxId: String?
    var status: String?

    var displayName: String { receiverLegalName ?? name ?? "" }
    var displayTaxId: String { receiverTaxId ?? taxId ?? "" }
    var displayBankCode: String? { bankCode ?? ispb }
}

/// QR Code Pix decodificado (`POST …/intents/pix/decode` → `qrCode`).
struct QrCodeDetails: Codable, Hashable, Sendable {
    enum QrType: String, Codable, Sendable { case `static`, dynamic }

    var emv: String
    var type: QrType?
    var transactionAmount: Int    // 0 = valor livre; > 0 = fixo pelo recebedor (não editável)
    var merchantCity: String?
    var transactionIdentification: String?
    var dueDate: String?

    var hasFixedAmount: Bool { transactionAmount > 0 }
}

/// Resposta completa do decode de EMV: chave + QR.
struct PixDecodeResult: Codable, Hashable, Sendable {
    var key: PixKeyDetails
    var qrCode: QrCodeDetails
}

/// Bloco `registerData` da consulta de boleto (dados de registro na CIP).
struct BankslipRegisterData: Codable, Hashable, Sendable {
    var recipient: String?
    var documentRecipient: String?
    var payer: String?
    var documentPayer: String?
    var payDueDate: String?
    var dueDateRegister: String?
    var allowChangeValue: Bool?
    var originalValue: Int?
    var totalUpdated: Int?
    var discountValue: Int?
    var interestValueCalculated: Int?
    var fineValueCalculated: Int?
    var totalWithDiscount: Int?
    var totalWithAdditional: Int?
    var minValue: Int?
    var maxValue: Int?
}

/// Consulta de boleto (`POST …/intents/bankslip/check` → BaasBankslipCheck).
struct BankslipCheck: Codable, Hashable, Sendable {
    var id: String
    var payable: Bool
    var assignor: String?
    var dueDate: String?
    var digitable: String
    var value: Int
    var minValue: Int?
    var maxValue: Int?
    var fineAmount: Int?
    var interestAmount: Int?
    var errorCode: String?
    var status: Int?
    var initeHour: String?
    var endHour: String?
    var registerData: BankslipRegisterData?

    /// RN-13: valor final = original + multa + juros − desconto (o backend consolida em
    /// `totalUpdated`; usamos ele quando presente).
    var finalAmount: Int {
        if let total = registerData?.totalUpdated, total > 0 { return total }
        let original = registerData?.originalValue ?? value
        let fine = registerData?.fineValueCalculated ?? fineAmount ?? 0
        let interest = registerData?.interestValueCalculated ?? interestAmount ?? 0
        let discount = registerData?.discountValue ?? 0
        return max(0, original + fine + interest - discount)
    }

    /// Valor editável pelo pagador (dentro de min/max)?
    var allowsChangeValue: Bool { registerData?.allowChangeValue ?? false }
}

/// Payload do `POST /wallets/{id}/intents` — nomes idênticos ao contrato.
struct WalletPaymentIntentDraft: Encodable, Sendable {
    var pixKey: String?
    var paymentMethod: WalletPaymentMethod
    var amount: Int
    var lat: Double
    var lng: Double
    var keyDetails: PixKeyDetails?
    var qrCodeDetails: QrCodeDetails?
    var digitable: String?
    var description: String?
    var deviceInfo: [String: String]?
}

/// Intent criado — resposta do `POST /wallets/{id}/intents`.
struct WalletPaymentIntent: Codable, Hashable, Sendable, Identifiable {
    let id: String
    var paymentMethod: WalletPaymentMethod?
    var amount: Int?
    var pixKey: String?
    var keyDetails: PixKeyDetails?
    var qrCodeDetails: QrCodeDetails?
    var potentialDuplicatedPackageId: String?   // presente ⇒ tela de duplicado (RN-14)
    var createdAt: String?
}

/// Evento de confirmação de pagamento (fedex `WalletPaymentEvent.data`).
struct WalletPaymentEvent: Codable, Hashable, Sendable {
    var id: String
    var confirmed: Bool
    var packageId: String?
}

/// Pagamento existente para comparação de duplicado — espelha `PackageDuplicatedType`
/// do wallet-pwa (`GET /package/{id}` projetado para a tela de duplicado).
struct WalletDuplicatePackage: Codable, Hashable, Sendable {
    var amount: Int
    var paymentDate: String?
    var paymentMethod: String?
    var receiverName: String?
    var payerName: String?
    var status: String?
    var requestName: String?
    var requestDate: String?
}
