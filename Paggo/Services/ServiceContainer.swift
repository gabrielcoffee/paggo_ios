import Foundation

/// Injeção de dependências central. Decide entre mocks e backend real conforme `AppConfig`.
/// As stores leem daqui (default), então trocar `PAGGO_DATA_SOURCE=live` liga a rede sem
/// alterar as telas. Mantido `Sendable` para uso de qualquer isolamento.
final class ServiceContainer: Sendable {
    static let shared = ServiceContainer()

    let config: AppConfig
    let tokenStore: TokenStore
    let apiClient: APIClient
    let payoutAPI: PayoutAPI
    let paymentDetailsAPI: PaymentDetailsAPI
    let authAPI: AuthAPI
    /// Único e compartilhado: o mock é stateful (pagamento novo entra no extrato). Quando as
    /// rotas de wallet existirem na mobile-api, trocar por `LiveWalletRepository` conforme `isLive`.
    let walletRepository: WalletRepository

    // Spend management (specs 01–06): mock hoje (SpendMockServer), Supabase na fase live.
    let budgetRepository: BudgetRepository
    let cardRepository: CardRepository
    let reimbursementRepository: ReimbursementRepository
    let policyRepository: PolicyRepository
    let receiptRepository: ReceiptRepository
    let spendNotificationRepository: SpendNotificationRepository
    let chatRepository: ChatRepository

    private init(config: AppConfig = .current) {
        self.config = config
        let store = KeychainTokenStore()
        self.tokenStore = store
        self.apiClient = APIClient(config: config, tokens: store)
        self.payoutAPI = PayoutAPI(client: apiClient)
        self.paymentDetailsAPI = PaymentDetailsAPI(client: apiClient)
        self.authAPI = AuthAPI(client: apiClient, authBaseURL: config.authBaseURL)
        self.walletRepository = MockWalletRepository()
        self.budgetRepository = MockBudgetRepository()
        self.cardRepository = MockCardRepository()
        self.reimbursementRepository = MockReimbursementRepository()
        self.policyRepository = MockPolicyRepository()
        self.receiptRepository = MockReceiptRepository()
        self.spendNotificationRepository = MockSpendNotificationRepository()
        self.chatRepository = MockChatRepository()
    }

    var isLive: Bool { config.dataSource == .live }
}
