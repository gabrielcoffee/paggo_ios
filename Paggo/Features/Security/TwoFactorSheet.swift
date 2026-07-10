import SwiftUI

/// Gate de 2FA reutilizável para ações que movem dinheiro (liberar pagamento, transferir).
/// Exige confirmação **toda vez**: tenta biometria (Face ID / Touch ID) primeiro; se o aparelho
/// não tiver biometria habilitada — ou se o usuário escolher — cai para o código por e-mail (OTP).
/// `onVerified` roda a ação sensível; `onCancel` apenas fecha.
///
/// Debug: `PAGGO_2FA=otp` força o fluxo de código; `PAGGO_2FA=faceid` pula o fallback de e-mail.
struct TwoFactorSheet: View {
    let title: String
    let reason: String
    let email: String
    let onVerified: () -> Void
    let onCancel: () -> Void

    private let biometrics: BiometricAuthenticating

    init(title: String, reason: String, email: String,
         biometrics: BiometricAuthenticating? = nil,
         onVerified: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.reason = reason
        self.email = email
        self.onVerified = onVerified
        self.onCancel = onCancel
        self.biometrics = biometrics
            ?? (AppConfig.current.dataSource == .live
                ? BiometricAuthenticator()
                : MockBiometricAuthenticator())
    }

    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    private enum Mode { case authenticating, biometricRetry, otp }
    private enum SendState: Equatable { case sending, sent, failed(String) }

    /// Charset do código: maiúsculas exceto I/O + dígitos 2–9.
    private static let allowed = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let cooldownSeconds = 60

    @State private var mode: Mode = .authenticating
    @State private var biometricAvailable = true
    @State private var otpSendStarted = false

    @State private var code = ""
    @State private var sendState: SendState = .sending
    @State private var validating = false
    @State private var validationError: String?
    @State private var cooldown = 0
    @State private var validationTask: Task<Void, Never>?
    @State private var cooldownTask: Task<Void, Never>?
    @State private var dismissed = false
    @FocusState private var focused: Bool

    private var isValid: Bool { code.count == 6 }
    private var biometryLabel: String { biometrics.biometryLabel }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            switch mode {
            case .authenticating: authenticatingView
            case .biometricRetry: biometricRetryView
            case .otp: otpView
            }
        }
        .padding(Spacing.xl)
        .presentationDragIndicator(.visible)
        .task { await start() }
        .onDisappear {
            // Swipe-to-dismiss / fechamento por qualquer via: aborta validação e contador em voo
            // para não confirmar (nem mutar estado órfão) depois que o sheet saiu.
            dismissed = true
            validationTask?.cancel()
            cooldownTask?.cancel()
        }
    }

    // MARK: - Biometria (padrão)

    private var authenticatingView: some View {
        VStack(spacing: Spacing.lg) {
            shieldIcon(systemName: "faceid")
            Text(title)
                .font(.brand(.title3, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            ProgressView()
                .padding(.vertical, Spacing.xs)
            Text("Autenticando com \(biometryLabel)…")
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            Button("Cancelar") { cancel() }
                .font(.brand(.subheadline, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var biometricRetryView: some View {
        VStack(spacing: Spacing.lg) {
            shieldIcon(systemName: "faceid", tone: Theme.warning)
            Text(title)
                .font(.brand(.title3, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Não foi possível confirmar com \(biometryLabel).")
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: Spacing.sm)
            VStack(spacing: Spacing.md) {
                Button {
                    Task { await runBiometric() }
                } label: {
                    Text("Tentar com \(biometryLabel)").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionStyle())

                Button("Usar código por e-mail") { goToOTP() }
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.accent)

                Button("Cancelar") { cancel() }
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - OTP (fallback)

    private var otpView: some View {
        VStack(spacing: Spacing.xl) {
            otpHeader
            codeField
            if let error = validationError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.brand(.caption, weight: .medium))
                    .foregroundStyle(Theme.negative)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            resendRow
            Spacer(minLength: Spacing.sm)
            otpActions
        }
    }

    private var otpHeader: some View {
        VStack(spacing: Spacing.md) {
            shieldIcon(systemName: "lock.shield.fill")
            Text("Confirme sua identidade")
                .font(.brand(.title3, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(subtitle)
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var subtitle: String {
        switch sendState {
        case .sending: return "Enviando um código de 6 caracteres para \(emailLabel)…"
        case .sent: return "Enviamos um código de 6 caracteres para \(emailLabel)."
        case .failed(let message): return message
        }
    }

    private var emailLabel: String { email.isEmpty ? "seu e-mail" : email }

    private var codeField: some View {
        TextField("", text: $code, prompt: Text("K7PM2W").foregroundStyle(Theme.textTertiary))
            .keyboardType(.asciiCapable)
            .textContentType(.oneTimeCode)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .font(.brand(size: 28, weight: .semibold))
            .multilineTextAlignment(.center)
            .tracking(10)
            .foregroundStyle(Theme.textPrimary)
            .focused($focused)
            .submitLabel(.go)
            .onSubmit { if isValid { startConfirm() } }
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(validationError != nil ? Theme.negative.opacity(0.6) : Theme.stroke, lineWidth: 1)
            )
            .onChange(of: code) { _, new in
                let filtered = String(new.uppercased().filter { Self.allowed.contains($0) }.prefix(6))
                if filtered != code { code = filtered }
                if validationError != nil { validationError = nil }
            }
    }

    @ViewBuilder private var resendRow: some View {
        if case .failed = sendState {
            Button("Tentar novamente") { Task { await send() } }
                .font(.brand(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.accent)
        } else {
            Button(cooldown > 0 ? "Reenviar em \(cooldown)s" : "Reenviar código") {
                Task { await send() }
            }
            .font(.brand(.subheadline, weight: cooldown > 0 ? .medium : .semibold))
            .foregroundStyle(cooldown > 0 ? Theme.textTertiary : Theme.accent)
            .disabled(cooldown > 0 || sendState == .sending)
        }
    }

    private var otpActions: some View {
        VStack(spacing: Spacing.md) {
            Button {
                startConfirm()
            } label: {
                HStack(spacing: Spacing.sm) {
                    if validating { ProgressView().tint(.white) }
                    Text("Confirmar")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(!isValid || validating)
            .opacity(isValid && !validating ? 1 : 0.5)

            if biometricAvailable {
                Button("Usar \(biometryLabel)") { Task { await runBiometric() } }
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .disabled(validating)
            }

            Button("Cancelar") { cancel() }
                .font(.brand(.subheadline, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .disabled(validating)
        }
    }

    // MARK: - Building blocks

    private func shieldIcon(systemName: String, tone: Color = Theme.accent) -> some View {
        ZStack {
            Circle().fill(tone.opacity(0.14)).frame(width: 64, height: 64)
            Image(systemName: systemName)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(tone)
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Fluxo

    private func start() async {
        if ProcessInfo.processInfo.environment["PAGGO_2FA"] == "otp" {
            biometricAvailable = false
            goToOTP()
            return
        }
        await runBiometric()
    }

    private func runBiometric() async {
        mode = .authenticating
        let result = await biometrics.evaluate(reason: reason)
        if dismissed { return }
        switch result {
        case .success:
            complete()
        case .unavailable:
            biometricAvailable = false
            goToOTP()
        case .failed:
            biometricAvailable = true
            mode = .biometricRetry
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func goToOTP() {
        mode = .otp
        focused = true
        guard !otpSendStarted else { return }
        otpSendStarted = true
        Task { await send() }
    }

    private func complete() {
        guard !dismissed else { return }
        dismissed = true
        onVerified()
        dismiss()
    }

    private func cancel() {
        dismissed = true
        validationTask?.cancel()
        cooldownTask?.cancel()
        onCancel()
        dismiss()
    }

    private func send() async {
        sendState = .sending
        validationError = nil
        do {
            try await auth.sendApprovalCode(email: email)
            if dismissed { return }
            sendState = .sent
            focused = true
            startCooldown()
        } catch {
            if dismissed { return }
            let message = (error as? APIError)?.userMessage ?? "Não foi possível enviar o código."
            sendState = .failed(message)
        }
    }

    private func startCooldown() {
        cooldown = Self.cooldownSeconds
        // Cancela-e-substitui: garante um único contador vivo (sem dois decrementando).
        cooldownTask?.cancel()
        cooldownTask = Task {
            while cooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                if cooldown > 0 { cooldown -= 1 }
            }
        }
    }

    /// Dispara a validação como uma Task retida (cancelável no dismiss), substituindo qualquer
    /// validação anterior em voo.
    private func startConfirm() {
        validationTask?.cancel()
        validationTask = Task { await confirm() }
    }

    private func confirm() async {
        guard isValid, !validating else { return }
        validating = true
        validationError = nil
        do {
            let valid = try await auth.validateApprovalCode(email: email, code: code)
            if Task.isCancelled || dismissed { return }
            validating = false
            if valid {
                complete()
            } else {
                validationError = "Código inválido"
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } catch {
            if Task.isCancelled || dismissed { return }
            validating = false
            validationError = (error as? APIError)?.userMessage ?? "Não foi possível validar o código."
        }
    }
}
