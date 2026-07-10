import SwiftUI

/// Gatilho do drawer de perfil. Botão com label customizável que apresenta o
/// `ProfileDrawer` como bottom sheet de vidro (Liquid Glass, detents medium/large).
/// Compartilhado pelo avatar (toolbars) e pela saudação (WalletHome).
struct ProfileMenu<Label: View>: View {
    @State private var showDrawer = false
    private let label: Label

    init(@ViewBuilder label: () -> Label) {
        self.label = label()
    }

    var body: some View {
        Button {
            showDrawer = true
        } label: {
            label
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDrawer) {
            ProfileDrawer()
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
    }
}

/// Label padrão: avatar do usuário (modo Plataforma / abas internas da carteira).
struct ProfileAvatarLabel: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        OwnerAvatar(name: auth.activeUser?.name ?? auth.savedUser?.name ?? "Você",
                    imageURL: auth.activeUser?.image ?? auth.savedUser?.image, size: 30)
    }
}

extension ProfileMenu where Label == ProfileAvatarLabel {
    init() {
        self.init { ProfileAvatarLabel() }
    }
}
