import SwiftUI

/// Login por e-mail em dois passos (OTP): envia o código e valida. No backend real isso vira
/// código → custom token Firebase → /auth/login; no mock qualquer código de 6 caracteres entra.
/// O código é alfanumérico de 6 caracteres (A–Z sem I/O + 2–9, ex.: "K7PM2W"), então o campo é
/// ascii + caixa-alta filtrando o charset — um numberPad não digita códigos reais.
struct EmailLoginSheet: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    /// Charset do código: maiúsculas exceto I/O + dígitos 2–9.
    private static let allowed = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let cooldownSeconds = 60

    private enum Step { case email, code }
    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var sending = false
    @State private var sendError: String?
    @State private var cooldown = 0
    @State private var cooldownTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    private var emailValid: Bool { email.contains("@") && email.contains(".") }
    private var codeValid: Bool { code.count == 6 }
    private var message: String? { sendError ?? auth.errorMessage }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                if step == .email { emailStep } else { codeStep }
                if let message {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.brand(.caption, weight: .medium))
                        .foregroundStyle(Theme.negative)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
            }
            .padding(Spacing.xl)
            .screenBackground()
            .navigationTitle(step == .email ? "Entrar com e-mail" : "Código de verificação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Cancelar") { cancel() } }
                if step == .code {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Voltar") { step = .email; code = ""; sendError = nil; focused = true }
                    }
                }
            }
            .onAppear { focused = true }
            .onDisappear { cooldownTask?.cancel() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Passo 1 — e-mail

    private var emailStep: some View {
        VStack(spacing: Spacing.lg) {
            field(placeholder: "voce@empresa.com.br", text: $email, systemImage: "envelope")
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .submitLabel(.go)
                .onSubmit { if emailValid { Task { await sendCode() } } }

            primaryButton(title: "Enviar código", enabled: emailValid, loading: sending) {
                Task { await sendCode() }
            }
        }
    }

    // MARK: Passo 2 — código

    private var codeStep: some View {
        VStack(spacing: Spacing.lg) {
            Text("Enviamos um código de 6 caracteres para \(email).")
                .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            field(placeholder: "K7PM2W", text: $code, systemImage: "number")
                .keyboardType(.asciiCapable)
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit { if codeValid { Task { await submit() } } }
                .onChange(of: code) { _, new in
                    let filtered = String(new.uppercased().filter { Self.allowed.contains($0) }.prefix(6))
                    if filtered != code { code = filtered }
                    if sendError != nil { sendError = nil }
                }

            primaryButton(title: "Entrar", enabled: codeValid, loading: auth.isAuthenticating) {
                Task { await submit() }
            }

            Button(cooldown > 0 ? "Reenviar em \(cooldown)s" : "Reenviar código") {
                Task { await sendCode() }
            }
            .font(.brand(.subheadline, weight: cooldown > 0 ? .medium : .semibold))
            .foregroundStyle(cooldown > 0 ? Theme.textTertiary : Theme.accent)
            .disabled(cooldown > 0 || sending)
        }
    }

    // MARK: Componentes

    private func primaryButton(title: String, enabled: Bool, loading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if loading { ProgressView().tint(.white) }
                Text(title)
            }
            .font(.brand(.body, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(enabled && !loading ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || loading)
    }

    private func field(placeholder: String, text: Binding<String>, systemImage: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            TextField(placeholder, text: text)
                .font(.brand(.body))
                .foregroundStyle(Theme.textPrimary)
                .focused($focused)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, Spacing.lg)
        .background(Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    // MARK: Ações

    private func sendCode() async {
        sending = true
        sendError = nil
        do {
            try await auth.requestEmailCode(email)
            step = .code
            code = ""
            focused = true
            startCooldown()
        } catch {
            sendError = (error as? APIError)?.userMessage ?? "Não foi possível enviar o código."
        }
        sending = false
    }

    private func submit() async {
        await auth.submitEmailCode(email: email, code: code)
        if auth.errorMessage == nil { dismiss() }
    }

    private func startCooldown() {
        cooldown = Self.cooldownSeconds
        cooldownTask?.cancel()
        cooldownTask = Task {
            while cooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                if cooldown > 0 { cooldown -= 1 }
            }
        }
    }

    private func cancel() {
        cooldownTask?.cancel()
        dismiss()
    }
}
