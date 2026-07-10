import SwiftUI
import Observation

/// Estado de autenticação (sem backend). Mantém o usuário salvo para habilitar o atalho de Face ID
/// e gerencia a transição entre a tela de login e o app.
@MainActor
@Observable
final class AuthStore {
    /// `launching` = autenticado, exibindo o splash da marca enquanto o home carrega atrás.
    enum Phase: Equatable { case loggedOut, launching, authenticated }

    private let repo: AuthRepository
    private let biometrics: BiometricAuthenticating
    private let isLive: Bool
    private let session: SessionService?

    private(set) var phase: Phase = .loggedOut
    private(set) var savedUser: AuthUser?
    private(set) var activeUser: AuthUser?

    /// Em State A (usuário salvo), revela a lista de provedores ao tocar "Usar outra conta".
    var presentingProviders = false
    var isAuthenticating = false
    /// Em andamento a troca de empresa (customer) — desabilita o seletor e mostra o spinner.
    var isSwitchingCustomer = false
    var errorMessage: String?

    private static let storageKey = "paggo.savedUser"

    init(repo: AuthRepository = MockAuthRepository(),
         biometrics: BiometricAuthenticating = BiometricAuthenticator()) {
        self.repo = repo
        self.biometrics = biometrics
        self.isLive = AppConfig.current.dataSource == .live
        self.session = self.isLive
            ? SessionService(authAPI: ServiceContainer.shared.authAPI, tokens: ServiceContainer.shared.tokenStore)
            : nil

        // Debug: PAGGO_AUTH=saved|faceid semeia um usuário salvo (tela "Entrar como Igor").
        let authEnv = ProcessInfo.processInfo.environment["PAGGO_AUTH"]
        if authEnv == "saved" || authEnv == "faceid" || authEnv == "launching" {
            self.savedUser = AuthUser(
                id: "user_igor", name: "Igor", email: "igor@paggo.ai", provider: .google,
                currentCustomerId: "cust_1",
                customers: [
                    .init(id: "cust_1", name: "Paggo Tecnologia LTDA"),
                    .init(id: "cust_2", name: "Acme Pagamentos ME"),
                ])
        } else {
            self.savedUser = Self.loadSavedUser()
        }
        // Debug: PAGGO_AUTH=launching abre direto no splash pós-login (verificação do fluxo real).
        if authEnv == "launching" {
            self.activeUser = self.savedUser
            self.phase = .launching
        }
    }

    /// Debug: dispara o fluxo de Face ID automaticamente (usado para verificação de UI).
    var autoTriggersBiometrics: Bool {
        ProcessInfo.processInfo.environment["PAGGO_AUTH"] == "faceid"
    }

    /// Mostra a seção de atalho do usuário salvo (vs. a lista de provedores).
    var showsSavedUser: Bool { savedUser != nil && !presentingProviders }
    var biometryLabel: String { biometrics.biometryLabel }

    // MARK: - Ações

    /// Atalho do usuário salvo: confirma identidade por Face ID e entra.
    func authenticateSavedUser() async {
        guard let user = savedUser, !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil
        let result = await biometrics.evaluate(reason: "Entrar na sua conta Paggo")

        let gatePassed: Bool
        switch result {
        case .success:
            gatePassed = true
        case .unavailable:
            // Biometria indisponível (não cadastrada / permissão negada ao app): cai para o gate
            // do dono do dispositivo (código do aparelho) antes de qualquer criação de sessão.
            gatePassed = await biometrics.evaluateDeviceOwner(reason: "Entrar na sua conta Paggo") == .success
        case .failed:
            isAuthenticating = false
            errorMessage = "Não foi possível confirmar sua identidade."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        isAuthenticating = false

        if isLive, let session {
            // Gate biométrico aprovado — garante um token utilizável ANTES de entrar (senão o app
            // entraria com token morto e toda requisição falharia). Se a rede ainda não subiu logo
            // após o desbloqueio (offline transitório), `enterWithRetries` retenta antes de desistir.
            isAuthenticating = true
            await enterWithRetries(user: user, session: session, gatePassed: gatePassed)
        } else {
            enter(as: user)
        }
    }

    /// Login por provedor (Google / Microsoft / E-mail).
    func signIn(with provider: AuthProvider, email: String? = nil) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil
        do {
            let user: AuthUser
            if isLive, let session {
                switch provider {
                case .google:
                    user = try await session.signInWithGoogle()
                case .microsoft:
                    user = try await session.signInWithMicrosoft()
                case .email:
                    // E-mail usa o fluxo de OTP (requestEmailCode + submitEmailCode); não cai aqui.
                    isAuthenticating = false
                    return
                }
            } else {
                user = await repo.signIn(with: provider, email: email)
            }
            isAuthenticating = false
            persist(user)
            enter(as: user)
        } catch {
            isAuthenticating = false
            // Cancelar a janela OAuth não é erro — volta silenciosamente para a tela de login.
            if SessionService.isUserCancelled(error) { return }
            errorMessage = (error as? APIError)?.userMessage ?? "Não foi possível entrar."
        }
    }

    /// E-mail (OTP): envia o código. No mock é no-op (qualquer código entra).
    func requestEmailCode(_ email: String) async throws {
        if isLive, let session { try await session.sendEmailCode(email) }
    }

    /// E-mail (OTP): valida o código e entra.
    func submitEmailCode(email: String, code: String) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil
        do {
            let user: AuthUser
            if isLive, let session {
                user = try await session.signInWithEmail(email: email, code: code)
            } else {
                user = await repo.signIn(with: .email, email: email)
            }
            isAuthenticating = false
            persist(user)
            enter(as: user)
        } catch {
            isAuthenticating = false
            errorMessage = (error as? APIError)?.userMessage ?? "Código inválido."
        }
    }

    // MARK: - Troca de empresa (customer)

    /// Troca a empresa ativa. No live faz `PATCH /user/change-user-current-customer` (mesmo token)
    /// e, em sucesso, limpa os dados por-empresa — o `mainScreen` remonta pelo
    /// `.id(activeUser?.currentCustomerId)` e recarrega tudo sob a nova empresa. Falha → toast.
    func switchCustomer(to id: String) async {
        guard let user = activeUser ?? savedUser, id != user.currentCustomerId, !isSwitchingCustomer
        else { return }
        isSwitchingCustomer = true
        errorMessage = nil
        if isLive, let session {
            do {
                let updated = try await session.switchCustomer(to: id, for: user)
                applySwitched(updated)
            } catch {
                isSwitchingCustomer = false
                ToastCenter.shared.show(
                    (error as? APIError)?.userMessage ?? "Não foi possível trocar de empresa.",
                    style: .error)
            }
        } else {
            var updated = user
            updated.currentCustomerId = id
            applySwitched(updated)
        }
    }

    private func applySwitched(_ user: AuthUser) {
        activeUser = user
        persist(user)   // também atualiza savedUser + UserDefaults
        // Limpa stores por-empresa + cache de servidor; o remount do mainScreen recarrega.
        SessionResetRegistry.shared.resetAll()
        isSwitchingCustomer = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Liberação (OTP de aprovação)

    /// Aprovação (OTP): envia o código de liberação por e-mail. No mock é no-op (qualquer código
    /// entra); no live delega ao `SessionService` (POST /auth/message-token). Espelha o fluxo de
    /// `requestEmailCode`, mantendo a decisão mock/live num único lugar.
    func sendApprovalCode(email: String) async throws {
        if isLive, let session { try await session.sendApprovalCode(email) }
    }

    /// Aprovação (OTP): valida o código de liberação. No mock aceita qualquer código de 6
    /// caracteres; no live valida via `SessionService` (POST /auth/validate-message-token).
    func validateApprovalCode(email: String, code: String) async throws -> Bool {
        guard isLive, let session else { return true }
        return try await session.validateApprovalCode(email: email, code: code)
    }

    func useAnotherAccount() { presentingProviders = true }
    func cancelAnotherAccount() { presentingProviders = false }

    func forgetDevice() {
        savedUser = nil
        presentingProviders = false
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    /// Sai do app mantendo o usuário salvo (preserva o atalho de Face ID no próximo acesso).
    /// No modo live também encerra a sessão no backend e limpa os tokens do Keychain.
    func signOut() {
        activeUser = nil
        presentingProviders = false
        errorMessage = nil
        // Limpa os stores por-usuário + o cache de servidor para o próximo login não herdar
        // saldo/transações/pagamentos do usuário que acabou de sair.
        SessionResetRegistry.shared.resetAll()
        if isLive, let session { Task { await session.signOut() } }
        phase = .loggedOut
    }

    // MARK: - Privados

    /// Resultado de UMA tentativa de entrar com a sessão salva (sem mostrar mensagens — o laço de
    /// retry decide). `.offline` é o único estado que vale retentar (rede ainda subindo).
    private enum EntryOutcome { case entered, needsInteractiveLogin, offline }

    /// Entra com a sessão salva, retentando ENQUANTO ficar offline: logo após desbloquear, o iPhone
    /// pode ainda estar terminando de conectar. Até 5 retentativas a cada 200ms. Só chega aqui com o
    /// gate biométrico JÁ aprovado — um Face ID recusado (rosto errado) barra antes, sem retry algum.
    private func enterWithRetries(user: AuthUser, session: SessionService, gatePassed: Bool) async {
        let maxRetries = 5
        for attempt in 0...maxRetries {
            switch await attemptEntry(user: user, session: session, gatePassed: gatePassed) {
            case .entered:
                return
            case .needsInteractiveLogin:
                isAuthenticating = false
                presentingProviders = true
                errorMessage = "Sua sessão expirou. Entre novamente."
                return
            case .offline:
                // Rede talvez subindo: espera 200ms e retenta (menos na última tentativa).
                if attempt < maxRetries {
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
        }
        // Offline em TODAS as tentativas: mantém o cartão do usuário salvo.
        isAuthenticating = false
        errorMessage = "Sem conexão. Tente novamente."
    }

    /// Uma tentativa: verifica a sessão salva e, se preciso e permitido, cunha uma nova em silêncio.
    private func attemptEntry(user: AuthUser, session: SessionService,
                              gatePassed: Bool) async -> EntryOutcome {
        switch await session.ensureUsableSession() {
        case .usable:
            // Atualiza nome/foto do backend (o savedUser persistido pode não ter a foto).
            let fresh = await session.refreshedProfile(for: user) ?? user
            isAuthenticating = false
            persist(fresh)
            enter(as: fresh)
            return .entered
        case .expired:
            // Sessão morta no backend (o mobile-auth expira após ~1 dia ocioso): só cunha nova
            // sessão com o gate local aprovado.
            guard gatePassed else { return .needsInteractiveLogin }
            return await silentEntry(user: user, session: session)
        case .offline:
            // Sem gate não há como cunhar sessão nova — sinaliza offline (o laço retenta/mostra erro).
            // Com gate, tenta o caminho INDEPENDENTE do /auth/refresh que falhou (Firebase + /auth/login).
            guard gatePassed else { return .offline }
            return await silentEntry(user: user, session: session)
        }
    }

    /// Cunha uma sessão nova em silêncio; devolve o resultado (offline vira retry no laço;
    /// erro de autenticação exige login interativo).
    private func silentEntry(user: AuthUser, session: SessionService) async -> EntryOutcome {
        do {
            let fresh = try await session.signInSilently(for: user)
            isAuthenticating = false
            persist(fresh)
            enter(as: fresh)
            return .entered
        } catch {
            if (error as? APIError)?.kind == .offline { return .offline }
            return .needsInteractiveLogin
        }
    }

    private func enter(as user: AuthUser) {
        activeUser = user
        savedUser = user
        presentingProviders = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // Splash da marca (LogoSplashView) enquanto o home carrega atrás; finishLaunch() entra no app.
        phase = .launching
    }

    /// Chamado pelo splash quando termina o fade-out — revela o home.
    func finishLaunch() {
        if phase == .launching { phase = .authenticated }
    }

    private func persist(_ user: AuthUser) {
        savedUser = user
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func loadSavedUser() -> AuthUser? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(AuthUser.self, from: data)
    }
}
