import Foundation

/// Erros de negócio da Carteira — espelham as respostas de erro do wallet-pwa.
enum WalletError: Error, Sendable, Equatable {
    case insufficientBalance          // pay → details.insufficientBalance
    case invalidPin                   // validate-pin → 403
    case pixKeyNotFound               // dict → 404
    case invalidQrCode                // decode → 4xx
    case bankslipNotPayable(String?)  // check → payable == false
    case generic(String)

    var userMessage: String {
        switch self {
        case .insufficientBalance:
            return "Saldo insuficiente na conta do cartão. Solicite a recarga ao seu time financeiro."
        case .invalidPin:
            return "Falha ao validar o PIN. Verifique se está correto e tente novamente."
        case .pixKeyNotFound:
            return "Chave Pix não encontrada."
        case .invalidQrCode:
            return "QRCode inválido. Verifique o código e tente novamente."
        case .bankslipNotPayable(let message):
            return message ?? "Este boleto não está disponível para pagamento no momento."
        case .generic(let message):
            return message
        }
    }
}

/// Camada de dados da Carteira Digital — espelha 1:1 os endpoints do wallet-pwa. O mock (`MockWalletRepository`) responde com fixtures JSON
/// no shape real; o futuro `LiveWalletRepository` implementa este mesmo protocolo chamando a
/// mobile-api, sem mudanças em modelos ou telas.
protocol WalletRepository: Sendable {
    // MARK: Exibição
    func wallets() async throws -> [Wallet]                                  // GET /wallets
    func balance(walletId: String) async throws -> Int                       // GET …/baas/account/balance
    func payments(walletId: String) async throws -> [WalletPayment]          // GET …/payments
    func paymentDetail(walletId: String, paymentId: String) async throws -> WalletPaymentDetail

    // MARK: Pré-intent (decode)
    func dictLookup(walletId: String, pixKey: String) async throws -> PixKeyDetails      // POST …/intents/pix/dict
    func decodeEmv(walletId: String, emv: String) async throws -> PixDecodeResult        // POST …/intents/pix/decode
    func checkBankslip(walletId: String, digitable: String) async throws -> BankslipCheck // POST …/intents/bankslip/check

    // MARK: Intent + pagamento
    func createIntent(walletId: String, draft: WalletPaymentIntentDraft) async throws -> WalletPaymentIntent // POST …/intents
    func validatePin(walletId: String, pin: String) async throws                          // POST …/validate-pin (403 → invalidPin)
    func pay(walletId: String, intentId: String) async throws -> WalletPayment            // POST …/intents/{id}/pay
    func awaitConfirmation(walletId: String, paymentId: String) async throws -> WalletPaymentEvent // fedex WalletPaymentEvent
    func duplicatePackage(id: String) async throws -> WalletDuplicatePackage              // GET /package/{id}

    // MARK: Enriquecimento pós-pagamento
    func updateDescription(walletId: String, paymentId: String, description: String) async throws
    func attachments(walletId: String, paymentId: String) async throws -> [WalletPaymentAttachment]
    func addAttachment(walletId: String, paymentId: String, fileName: String, data: Data) async throws -> WalletPaymentAttachment
    func allocations(walletId: String, paymentId: String) async throws -> [WalletPaymentAllocation]
    func setAllocations(walletId: String, paymentId: String, _ allocations: [WalletPaymentAllocation]) async throws
    func projects() async throws -> [AllocationOption]                       // GET /configs/projects
    func managerials() async throws -> [AllocationOption]                    // GET /configs/managerials

    func invalidate() async
}
