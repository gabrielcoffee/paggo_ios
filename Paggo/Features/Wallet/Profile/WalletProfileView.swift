import SwiftUI

/// Aba Perfil do modo Carteira: conta, chave Pix de reembolso, aparência e sessão.
/// A troca de modo (Plataforma/Carteira) continua no ProfileDrawer, aberto daqui.
struct WalletProfileView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppearanceStore.self) private var appearance
    @State private var showsDrawer = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Spacing.md) {
                        OwnerAvatar(name: auth.activeUser?.name ?? "—",
                                    imageURL: auth.activeUser?.image, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.activeUser?.name ?? "—")
                                .font(.brand(.headline, weight: .semibold))
                            Text(auth.activeUser?.email ?? "")
                                .font(.brand(.caption))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }

                Section("Reembolsos") {
                    HStack {
                        TintedIcon(symbol: "qrcode", tint: Theme.info)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chave Pix de recebimento")
                                .font(.brand(.subheadline, weight: .semibold))
                            Text("CPF · 113.036.437-23")
                                .font(.brand(.caption))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                Section("Aparência") {
                    Picker("Tema", selection: appearanceBinding) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .font(.brand(.subheadline))
                }

                Section {
                    Button {
                        showsDrawer = true
                    } label: {
                        Label("Conta e modo do app", systemImage: "arrow.left.arrow.right")
                            .font(.brand(.subheadline, weight: .semibold))
                    }
                    Button(role: .destructive) {
                        auth.signOut()
                    } label: {
                        Label("Sair", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.brand(.subheadline, weight: .semibold))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Perfil")
            .sheet(isPresented: $showsDrawer) { ProfileDrawer() }
        }
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(get: { appearance.mode }, set: { appearance.mode = $0 })
    }
}
