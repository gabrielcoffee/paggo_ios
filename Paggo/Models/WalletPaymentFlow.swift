import Foundation

// Modelo do fluxo de pagamento da Carteira — espelha o fluxo do apps/wallet-pwa.
// Valores em **cents** (Int). O fluxo é mock por enquanto (sem backend de wallet).

/// Como o pagamento foi iniciado (define a tela de entrada).
enum WalletPaymentEntry: String, Identifiable, Hashable, Sendable {
    case pixKey          // Pix por chave (DICT)
    case pixCopyPaste    // Pix Copia e Cola (BR Code)
    case pixQR           // Pix QR Code (scanner)
    case boleto          // Código de barras / linha digitável

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pixKey: return "Pix"
        case .pixCopyPaste: return "Pix Copia e Cola"
        case .pixQR: return "Pix QR Code"
        case .boleto: return "Código de Barras"
        }
    }

    var isPix: Bool { self != .boleto }
}

/// Passos do fluxo (máquina de estados).
enum WalletPaymentStep: Hashable, Sendable {
    case input        // digitar chave / colar código / escanear
    case locating     // obtendo localização (portão obrigatório)
    case review       // conferir recebedor + valor + informações
    case duplicated   // possível pagamento duplicado
    case pin          // PIN de transação
    case processing   // enviando
    case success      // confirmado
    case delayed      // em processamento (liquidação pendente)
    case failed       // falhou
}

/// Recebedor de um Pix resolvido pelo DICT (decode de chave/BR Code).
struct PixRecipient: Hashable, Sendable {
    var name: String
    var taxId: String
    var bankName: String
    var keyValue: String
    var keyTypeLabel: String   // "CPF/CNPJ", "Telefone", "E-mail", "Aleatória"
}

/// Dados de um boleto decodificado (linha digitável / código de barras).
struct BoletoInfo: Hashable, Sendable {
    var assignor: String          // beneficiário
    var digitableLine: String
    var dueDate: String?          // ISO
    var originalAmount: Int       // cents
    var fineAmount: Int
    var interestAmount: Int
    var discountAmount: Int

    /// Valor final = original + multa + juros − desconto.
    var finalAmount: Int { max(0, originalAmount + fineAmount + interestAmount - discountAmount) }
}
