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

    private init(config: AppConfig = .current) {
        self.config = config
        let store = KeychainTokenStore()
        self.tokenStore = store
        self.apiClient = APIClient(config: config, tokens: store)
        self.payoutAPI = PayoutAPI(client: apiClient)
        self.paymentDetailsAPI = PaymentDetailsAPI(client: apiClient)
        self.authAPI = AuthAPI(client: apiClient, authBaseURL: config.authBaseURL)
        self.walletRepository = MockWalletRepository()
    }

    var isLive: Bool { config.dataSource == .live }
}
