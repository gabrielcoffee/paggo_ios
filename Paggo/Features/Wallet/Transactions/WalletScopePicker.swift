import SwiftUI

/// Seletor de escopo do extrato, em duas partes na tela:
/// `WalletScopeButton` mora na linha do título (à direita) e abre o `WalletScopeMenu` —
/// dropdown que desce de cima para baixo sobre a lista. Fecha ao selecionar ou tocar fora.
struct WalletScopeButton: View {
    @Binding var isOpen: Bool
    @Environment(WalletStore.self) private var wallet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(WalletScopeMenu.animation(reduceMotion: reduceMotion)) { isOpen.toggle() }
        } label: {
            HStack(spacing: Spacing.sm) {
                currentMini
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(isOpen ? -180 : 0))
            }
            .padding(.horizontal, Spacing.sm).padding(.vertical, 6)
            .background(Theme.surfaceHigh, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var currentMini: some View {
        if wallet.transactionsScope == .all {
            WalletMiniCardGeneric()
        } else {
            WalletMiniCard(style: .at(scopedStyleIndex))
        }
    }

    private var scopedStyleIndex: Int {
        switch wallet.transactionsScope {
        case .current: return wallet.styleIndex(for: wallet.currentWallet)
        case .wallet(let id): return wallet.styleIndex(for: wallet.wallets.first { $0.id == id })
        case .all: return 0
        }
    }
}

/// Painel do seletor — desce do topo (scale anchor .top + fade), sem stagger lateral.
/// A opção selecionada tem fundo mais claro.
struct WalletScopeMenu: View {
    @Binding var isOpen: Bool
    @Environment(WalletStore.self) private var wallet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Animação padrão do abre/fecha (compartilhada com o botão e o tap-catcher).
    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.8)
    }

    /// Transição "de cima para baixo" do painel.
    static let transition: AnyTransition =
        .scale(scale: 0.9, anchor: .top).combined(with: .opacity)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(wallet.wallets.enumerated()), id: \.element.id) { index, item in
                row(mini: WalletMiniCard(style: .at(index)), name: item.name,
                    highlighted: isScoped(to: item.id)) {
                    select(.wallet(item.id))
                }
            }
            Divider().padding(.vertical, Spacing.xs)
            row(mini: WalletMiniCardGeneric(), name: "Todos os cartões",
                highlighted: wallet.transactionsScope == .all) {
                select(.all)
            }
        }
        .padding(Spacing.sm)
        .frame(width: 280, alignment: .leading)   // dropdown compacto, ancorado à direita
        .cardSurface()
    }

    private func row(mini: some View, name: String, highlighted: Bool,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                mini
                Text(name)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
            .background(highlighted ? Theme.surfaceHigh : .clear,
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func isScoped(to id: String) -> Bool {
        switch wallet.transactionsScope {
        case .current: return wallet.currentWallet?.id == id
        case .wallet(let scopedId): return scopedId == id
        case .all: return false
        }
    }

    private func select(_ scope: WalletStore.TransactionsScope) {
        withAnimation(Self.animation(reduceMotion: reduceMotion)) {
            wallet.transactionsScope = scope
            isOpen = false
        }
        if scope == .all { Task { await wallet.ensureAllPaymentsLoaded() } }
    }
}
