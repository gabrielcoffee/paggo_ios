import SwiftUI

/// Tela de login: imagem de fundo em tela cheia + logo Paggo no topo + cartão de vidro flutuante.
/// Dois estados — seleção de provedor (cartão unificado) e usuário salvo (atalho Face ID).
struct LoginView: View {
    @Environment(AuthStore.self) private var auth
    @State private var showEmailSheet = false

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LoginBackdrop()

            VStack(spacing: Spacing.md) {
                contentCard

                if let message = auth.errorMessage {
                    errorLine(message)
                }
            }
            .padding(.horizontal, 56)
            .padding(.bottom, Spacing.xxl)
            .animation(.smooth(duration: 0.35), value: auth.showsSavedUser)
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailLoginSheet()
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
        }
        .task {
            if auth.autoTriggersBiometrics && auth.showsSavedUser {
                await auth.authenticateSavedUser()
            }
        }
        .preferredColorScheme(.dark) // login sempre escuro (sobre a imagem de fundo)
    }

    @ViewBuilder private var contentCard: some View {
        if auth.showsSavedUser {
            savedUserCard
        } else {
            providersCard
        }
    }

    // MARK: - State B: seleção de provedor (cartão unificado, linhas centralizadas)

    private var providersCard: some View {
        VStack(spacing: 0) {
            providerRow(.google)
            rowDivider
            providerRow(.microsoft)
            rowDivider
            providerRow(.email)
        }
        .background(Color.clear.glassEffect(.clear, in: cardShape))
        .overlay(cardShape.stroke(.white.opacity(0.14), lineWidth: 1))
        .clipShape(cardShape)
        .overlay {
            if auth.isAuthenticating {
                ProgressView().tint(.white)
            }
        }
    }

    private var rowDivider: some View {
        Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
    }

    private func providerRow(_ provider: AuthProvider) -> some View {
        Button {
            if provider == .email {
                showEmailSheet = true
            } else {
                Task { await auth.signIn(with: provider) }
            }
        } label: {
            HStack(spacing: Spacing.md) {
                providerIcon(provider)
                Text(provider.actionLabel)
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(auth.isAuthenticating)
    }

    @ViewBuilder private func providerIcon(_ provider: AuthProvider) -> some View {
        switch provider {
        case .google:
            Image("GoogleIcon").resizable().scaledToFit().frame(width: 20, height: 20)
        case .microsoft:
            Image("MicrosoftIcon").resizable().scaledToFit().frame(width: 20, height: 20)
        case .email:
            Image(systemName: "envelope.fill")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 20, height: 20)
        }
    }

    // MARK: - State A: usuário salvo (atalho Face ID)

    private var savedUserCard: some View {
        let user = auth.savedUser
        return VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                OwnerAvatar(name: user?.name ?? "Você", imageURL: user?.image, size: 36, ring: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Bem-vindo de volta")
                        .font(.brand(.caption2, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Olá, \(user?.firstName ?? "")")
                        .font(.brand(.headline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Menu {
                    Button { auth.useAnotherAccount() } label: {
                        Label("Usar outra conta", systemImage: "person.crop.circle.badge.plus")
                    }
                    Button(role: .destructive) { auth.forgetDevice() } label: {
                        Label("Esquecer este dispositivo", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.08), in: Circle())
                }
                // O menu nativo (UIMenu) segue o Dynamic Type — clampar reduz o tamanho da fonte.
                .dynamicTypeSize(.small)
            }

            primaryButton(title: "Entrar como \(user?.firstName ?? "")", systemImage: "faceid") {
                Task { await auth.authenticateSavedUser() }
            }
        }
        .padding(Spacing.lg)
        .background(Color.clear.glassEffect(.clear, in: cardShape))
        .overlay(cardShape.stroke(.white.opacity(0.14), lineWidth: 1))
        .clipShape(cardShape)
        .padding(.horizontal, Spacing.md) // mais estreito que o cartão de provedores
    }

    // MARK: - Compartilhados

    private func primaryButton(title: String, systemImage: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if auth.isAuthenticating {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: systemImage).font(.system(size: 16, weight: .semibold))
                    Text(title).font(.brand(.subheadline, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(auth.isAuthenticating)
        .shadow(color: Theme.accentDeep.opacity(0.45), radius: 14, y: 6)
    }

    private func errorLine(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.brand(.caption, weight: .medium))
            .foregroundStyle(Theme.negative)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .background(.black.opacity(0.4), in: Capsule())
    }
}

#Preview("Provedores") {
    LoginView()
        .environment(AuthStore(repo: MockAuthRepository(), biometrics: MockBiometricAuthenticator()))
        .preferredColorScheme(.dark)
}
