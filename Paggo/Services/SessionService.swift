import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

/// Bootstrap do Firebase + GoogleSignIn — configurado **programaticamente** a partir do `AppConfig`
/// (espelha `src/config/firebase.ts` do app Expo), sem precisar de GoogleService-Info.plist.
enum FirebaseBootstrap {
    @MainActor private(set) static var isConfigured = false

    @MainActor static func configure() {
        guard FirebaseApp.app() == nil else { isConfigured = true; return }
        let fb = AppConfig.current.firebase
        let options = FirebaseOptions(googleAppID: fb.googleAppID, gcmSenderID: fb.gcmSenderID)
        options.apiKey = fb.apiKey
        options.projectID = fb.projectID
        options.storageBucket = fb.storageBucket
        FirebaseApp.configure(options: options)

        let google = AppConfig.current.google
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: google.iosClientID, serverClientID: google.serverClientID)
        isConfigured = true
    }
}

/// Debug: injeta uma sessão (tokens obtidos fora do app) no Keychain, para validar o caminho
/// "fetch payments" com dados reais sem o login interativo. Ativado por PAGGO_SESSION_ACCESS_TOKEN.
enum DevSession {
    @MainActor static func seedIfNeeded(into tokens: TokenStore) {
        let env = ProcessInfo.processInfo.environment
        guard let access = env["PAGGO_SESSION_ACCESS_TOKEN"], !access.isEmpty else { return }
        tokens.save(TokenBundle(
            accessToken: access,
            refreshToken: env["PAGGO_SESSION_REFRESH_TOKEN"] ?? "",
            sessionId: env["PAGGO_SESSION_ID"],
            expiresAt: Date().addingTimeInterval(60 * 50)
        ))
    }
}

/// Orquestra o login real: provedor (Google / e-mail) → Firebase id_token → POST /auth/login →
/// persiste a sessão no Keychain (que o APIClient/TokenRefresher consomem). Espelha o
/// `completeFirebaseLogin` do app Expo. Tudo em @MainActor (chamadas de UI/SDK).
@MainActor
final class SessionService {
    private let authAPI: AuthAPI
    private let tokens: TokenStore

    init(authAPI: AuthAPI, tokens: TokenStore) {
        self.authAPI = authAPI
        self.tokens = tokens
    }

    var hasValidSession: Bool { tokens.read() != nil }

    /// Garante que a sessão salva ainda funciona (renova o token se expirado). Usado pelo atalho
    /// de Face ID para não entrar no app com um token morto (que falharia em toda requisição).
    /// `.expired` = precisa cunhar sessão nova; `.offline` = falha de transporte, tentar de novo.
    func ensureUsableSession() async -> SessionCheck {
        guard tokens.read() != nil else { return .expired }
        return await authAPI.client.ensureValidSession()
    }

    // MARK: Google

    func signInWithGoogle() async throws -> AuthUser {
        guard FirebaseBootstrap.isConfigured else { throw notConfigured }
        let presenter = try topViewController()
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let googleIDToken = result.user.idToken?.tokenString else {
            throw APIError(kind: .invalidResponse, message: "Token Google ausente", exceptionName: nil, underlying: nil)
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: googleIDToken, accessToken: result.user.accessToken.tokenString)
        let firebaseUser = try await Auth.auth().signIn(with: credential).user
        let email = firebaseUser.email ?? result.user.profile?.email ?? ""
        let photoURL = firebaseUser.photoURL?.absoluteString
            ?? result.user.profile?.imageURL(withDimension: 240)?.absoluteString
        let firebaseIDToken = try await firebaseUser.idTokenForcingRefresh(true)
        return try await completeLogin(firebaseIDToken: firebaseIDToken, email: email,
                                       provider: .google, photoURL: photoURL)
    }

    // MARK: Microsoft (OAuth genérico do Firebase — espelha useMicrosoftSignIn do app Expo)

    func signInWithMicrosoft() async throws -> AuthUser {
        guard FirebaseBootstrap.isConfigured else { throw notConfigured }
        let provider = OAuthProvider(providerID: "microsoft.com")
        provider.scopes = ["openid", "profile", "email", "User.Read"]
        provider.customParameters = ["prompt": "select_account"]
        let credential = try await provider.credential(with: nil)
        let firebaseUser = try await Auth.auth().signIn(with: credential).user
        guard let email = firebaseUser.email ?? firebaseUser.providerData.first?.email,
              !email.isEmpty else {
            throw APIError(kind: .invalidResponse, message: "E-mail da conta Microsoft ausente",
                           exceptionName: nil, underlying: nil)
        }
        let firebaseIDToken = try await firebaseUser.idTokenForcingRefresh(true)
        return try await completeLogin(firebaseIDToken: firebaseIDToken, email: email,
                                       provider: .microsoft,
                                       photoURL: firebaseUser.photoURL?.absoluteString)
    }

    // MARK: E-mail (OTP → custom token → Firebase)

    func sendEmailCode(_ email: String) async throws {
        try await authAPI.sendMessageToken(email: email)
    }

    // MARK: Liberação (OTP de aprovação — mesmo endpoint de message-token do login por e-mail)

    /// Envia o código de liberação por e-mail. Propaga o `APIError` do backend (ex.: 403
    /// "Email sem registro na Paggo." / offline) para a UI mapear via `userMessage`.
    func sendApprovalCode(_ email: String) async throws {
        try await authAPI.sendMessageToken(email: email)
    }

    /// Valida o código de liberação; retorna `isValid`. Propaga erros de transporte/servidor.
    func validateApprovalCode(email: String, code: String) async throws -> Bool {
        try await authAPI.validateMessageToken(email: email, token: code).isValid
    }

    func signInWithEmail(email: String, code: String) async throws -> AuthUser {
        guard FirebaseBootstrap.isConfigured else { throw notConfigured }
        let validation = try await authAPI.validateMessageToken(email: email, token: code)
        guard validation.isValid else {
            throw APIError(kind: .server(status: 400), message: "Código inválido", exceptionName: nil, underlying: nil)
        }
        let custom = try await authAPI.generateCustomToken(email: email)
        let firebaseUser = try await Auth.auth().signIn(withCustomToken: custom.customToken).user
        let firebaseIDToken = try await firebaseUser.idTokenForcingRefresh(true)
        return try await completeLogin(firebaseIDToken: firebaseIDToken, email: email,
                                       provider: .email, photoURL: firebaseUser.photoURL?.absoluteString)
    }

    /// Recarrega o perfil (nome/foto) do backend para um usuário já salvo — usado no atalho de
    /// Face ID, cujo `savedUser` persistido pode não ter a foto. Retorna nil se falhar.
    func refreshedProfile(for saved: AuthUser) async -> AuthUser? {
        guard let user = try? await authAPI.userByEmail(saved.email) else { return nil }
        return AuthUser(
            id: user.id,
            name: user.name ?? saved.name,
            email: saved.email,
            provider: saved.provider,
            image: user.image ?? saved.image,
            currentCustomerId: user.resolvedCustomerId ?? saved.currentCustomerId,
            customers: Self.workspaces(from: user)
        )
    }

    /// Troca a empresa (customer) ativa: PATCH e reconstrói o `AuthUser` com a empresa nova + a
    /// lista atualizada. O token NÃO muda — o servidor passa a resolver o customer por
    /// `sessionCustomer` a cada requisição. Lança em 403 (não pertence) ou falha de rede.
    func switchCustomer(to customerId: String, for user: AuthUser) async throws -> AuthUser {
        let updated = try await authAPI.changeCustomer(customerId: customerId)
        return AuthUser(id: user.id, name: user.name, email: user.email, provider: user.provider,
                        image: user.image,
                        currentCustomerId: updated.sessionCustomer ?? customerId,
                        customers: Self.workspaces(from: updated))
    }

    // MARK: Re-login silencioso (atalho de Face ID)

    /// Cunha uma sessão NOVA para o usuário salvo em vez de depender do refresh token — o
    /// mobile-auth expira a sessão após ~1 dia ocioso, então o atalho de Face ID não pode contar
    /// com o refresh (espelha o `loginWithBiometrics` do app Expo). Por criar sessão, só deve ser
    /// chamado depois de o gate biométrico ter sucesso. Falhas de transporte (URLError / rede do
    /// Firebase) viram `APIError.offline` para o chamador manter o cartão do usuário salvo.
    func signInSilently(for saved: AuthUser) async throws -> AuthUser {
        guard FirebaseBootstrap.isConfigured else { throw notConfigured }
        do {
            // O currentUser do Firebase pode divergir do usuário salvo (ex.: "Usar outra conta"
            // cujo completeLogin falhou deixa o Firebase logado na outra conta) — só reutiliza o
            // token dele quando o e-mail bate com o salvo; senão cunha via custom token abaixo,
            // que é emitido para o e-mail salvo.
            if let firebaseUser = Auth.auth().currentUser {
                var candidateEmails = [firebaseUser.email]
                for provider in firebaseUser.providerData { candidateEmails.append(provider.email) }
                if Self.emailMatches(saved.email, candidates: candidateEmails) {
                    let firebaseIDToken = try await firebaseUser.idTokenForcingRefresh(true)
                    return try await completeLogin(firebaseIDToken: firebaseIDToken, email: saved.email,
                                                   provider: saved.provider,
                                                   photoURL: firebaseUser.photoURL?.absoluteString ?? saved.image)
                }
            }
            // Sem usuário Firebase correspondente (ex.: após signOut, ou conta divergente):
            // custom token via mobile-api → Firebase.
            let custom = try await authAPI.generateCustomToken(email: saved.email)
            let firebaseUser = try await Auth.auth().signIn(withCustomToken: custom.customToken).user
            let firebaseIDToken = try await firebaseUser.idTokenForcingRefresh(true)
            return try await completeLogin(firebaseIDToken: firebaseIDToken, email: saved.email,
                                           provider: saved.provider, providerName: "custom",
                                           photoURL: saved.image)
        } catch let error as APIError {
            throw error
        } catch let urlError as URLError {
            throw APIError.offline(urlError)
        } catch {
            let nsError = error as NSError
            if nsError.domain == AuthErrors.domain,
               nsError.code == AuthErrorCode.networkError.rawValue {
                throw APIError.offline(error)
            }
            throw error
        }
    }

    /// `true` quando algum dos e-mails do usuário Firebase (direto ou de provedor vinculado)
    /// corresponde ao e-mail salvo — comparação case-insensitive.
    private nonisolated static func emailMatches(_ email: String, candidates: [String?]) -> Bool {
        candidates.contains { $0?.caseInsensitiveCompare(email) == .orderedSame }
    }

    /// `true` quando o erro é o usuário cancelando o fluxo de login (fechar a janela OAuth do
    /// Google/Microsoft) — não deve virar mensagem de erro.
    static func isUserCancelled(_ error: Error) -> Bool {
        if let gidError = error as? GIDSignInError, gidError.code == .canceled { return true }
        let nsError = error as NSError
        return nsError.domain == AuthErrors.domain
            && nsError.code == AuthErrorCode.webContextCancelled.rawValue
    }

    // MARK: Logout

    func signOut() async {
        if let sessionId = tokens.read()?.sessionId {
            try? await authAPI.logout(sessionId: sessionId)
        }
        tokens.clear()
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: - Privados

    /// Passo final compartilhado: resolve user/customer, troca o id_token por sessão, persiste.
    /// `providerName` sobrescreve o provider enviado ao backend (ex.: re-login silencioso via
    /// custom token envia "custom" preservando o provedor original do usuário salvo).
    private func completeLogin(firebaseIDToken: String, email: String, provider: AuthProvider,
                               providerName: String? = nil, photoURL: String? = nil) async throws -> AuthUser {
        let user = try await authAPI.userByEmail(email)
        guard let customerId = user.resolvedCustomerId else {
            throw APIError(kind: .server(status: 422), message: "Usuário sem empresa associada",
                           exceptionName: nil, underlying: nil)
        }
        let device = deviceInfo()
        let response = try await authAPI.login(LoginRequest(
            id_token: firebaseIDToken,
            provider: providerName ?? Self.loginProviderName(provider),
            device_id: device.id,
            device_info: device.description,
            platform_customer_id: customerId,
            platform_user_id: user.id
        ))
        tokens.save(TokenBundle(
            accessToken: response.access_token,
            refreshToken: response.refresh_token,
            sessionId: response.session_id,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expires_in))
        ))
        // Sessão nova → falhas de refresh antigas não contam mais.
        await authAPI.client.resetRefreshAttempts()
        return AuthUser(id: user.id, name: user.name ?? email, email: email, provider: provider,
                        image: photoURL ?? user.image,
                        currentCustomerId: customerId, customers: Self.workspaces(from: user))
    }

    /// Empresas (customers) do usuário: id + razão social, para o seletor de empresa do perfil.
    private static func workspaces(from user: ExtendedUser) -> [AuthUser.Workspace] {
        (user.userCustomers ?? []).map { uc in
            AuthUser.Workspace(id: uc.customer.id, name: uc.customer.legalName ?? "")
        }
    }

    /// Provider aceito pelo POST /auth/login (espelha o app Expo: e-mail/OTP loga como "custom").
    private static func loginProviderName(_ provider: AuthProvider) -> String {
        switch provider {
        case .google: return "google"
        case .microsoft: return "microsoft"
        case .email: return "custom"
        }
    }

    private var notConfigured: APIError {
        APIError(kind: .server(status: 0),
                 message: "Login não configurado (adicione o GoogleService-Info.plist).",
                 exceptionName: nil, underlying: nil)
    }

    private func deviceInfo() -> (id: String, description: String) {
        let device = UIDevice.current
        return (device.identifierForVendor?.uuidString ?? "unknown",
                "Apple \(device.model) - (iOS/\(device.systemVersion))")
    }

    private func topViewController() throws -> UIViewController {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        guard let root = scene?.keyWindow?.rootViewController ?? scene?.windows.first?.rootViewController else {
            throw APIError(kind: .invalidResponse, message: "Sem janela ativa", exceptionName: nil, underlying: nil)
        }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
