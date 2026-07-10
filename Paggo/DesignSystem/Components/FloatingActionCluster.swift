import SwiftUI
import UIKit

/// Ação de um `FloatingActionCluster` — cápsula ou item de menu.
struct FloatingClusterAction: Identifiable {
    let id: String
    let label: String
    let symbol: String
    var tone: Color = Theme.accent
    /// Papel destrutivo (aparece em vermelho quando renderizada dentro do `Menu`).
    var isDestructive = false
    var enabled = true
    /// Motivo de indisponibilidade — a ação fica "tocável": tocar mostra o motivo num toast.
    var disabledReason: String?
    /// Verbo exibido dentro da cápsula durante a execução (ex.: "Enviando…").
    var inFlightLabel: String?
    /// Cor fixa do rótulo sobre a cápsula tintada (prominent). Quando definida, sobrepõe a
    /// resolução por luminância — ex.: branco em "Liberar" (verde positivo), onde o corte de
    /// luminância escolheria texto escuro no dark mode.
    var onTintLabel: Color?
    var run: () -> Void = {}
}

/// Cluster de ações flutuante em Liquid Glass — 1 a 3 cápsulas dentro de um
/// `GlassEffectContainer`, para uso em `.safeAreaInset(edge: .bottom)`.
///
/// - Direita: ação primária, cápsula tintada (`.glassEffect(.regular.tint(tone).interactive())`).
/// - Meio (opcional): ação secundária, cápsula de vidro regular com rótulo na cor do tom.
/// - Esquerda (opcional): cápsula compacta (ellipsis) abrindo um `Menu` de ações secundárias —
///   suporta papel destrutivo e itens desabilitados-com-motivo (tocar mostra o motivo em toast).
///
/// Feedback de execução: quando `inFlightID` corresponde a uma ação, a cápsula dela mostra
/// spinner + verbo ("Enviando…") e o cluster inteiro esmaece — mas toques NUNCA são engolidos:
/// tocar durante a execução (ou com `blocked`, mutação vinda de outra tela) mostra o toast
/// "Aguarde a ação anterior terminar.". `glassEffectID` dentro do container faz o cluster
/// morfar suavemente quando o conjunto de ações muda.
struct FloatingActionCluster: View {
    var primary: FloatingClusterAction
    var secondary: FloatingClusterAction?
    var menuActions: [FloatingClusterAction] = []
    /// Id da ação em execução nesta tela (spinner na cápsula correspondente).
    var inFlightID: String?
    /// Mutação em andamento vinda de outra tela — esmaece e responde toques com toast.
    var blocked = false

    @Namespace private var glassNamespace
    @Environment(\.colorScheme) private var colorScheme

    /// Alvo de toque mínimo (HIG) — as cápsulas nunca ficam abaixo disso.
    private static let minTapHeight: CGFloat = 56

    private var isBusy: Bool { inFlightID != nil || blocked }

    var body: some View {
        GlassEffectContainer(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                if !menuActions.isEmpty { menuCapsule }
                Spacer(minLength: 0)
                if let secondary { capsule(secondary, prominent: false) }
                capsule(primary, prominent: true)
            }
        }
        .opacity(isBusy ? 0.75 : 1)
        .animation(.snappy, value: inFlightID)
        .animation(.snappy, value: primary.id)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Cápsulas

    private func capsule(_ action: FloatingClusterAction, prominent: Bool) -> some View {
        let isActing = inFlightID == action.id
        return Button {
            handleTap(action)
        } label: {
            HStack(spacing: Spacing.sm) {
                if isActing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foreground(for: action, prominent: prominent))
                } else {
                    Image(systemName: action.symbol)
                }
                Text(isActing ? (action.inFlightLabel ?? action.label) : action.label)
            }
            .font(.brand(.body, weight: .semibold))
            .foregroundStyle(foreground(for: action, prominent: prominent))
            .frame(minHeight: Self.minTapHeight - 2 * Spacing.md)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(
            prominent && action.enabled
                ? .regular.tint(action.tone.opacity(0.85)).interactive()
                : .regular.interactive(),
            in: .capsule
        )
        .glassEffectID(action.id, in: glassNamespace)
        // Só desabilita de verdade quando não há motivo a comunicar — toques com motivo ou
        // durante execução continuam vivos para dar feedback (toast) em vez de silêncio.
        .disabled(!action.enabled && action.disabledReason == nil)
    }

    private var menuCapsule: some View {
        Menu {
            ForEach(menuActions) { action in
                Button(role: action.isDestructive ? .destructive : nil) {
                    handleTap(action)
                } label: {
                    Label(action.label, systemImage: action.symbol)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.brand(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 28, height: Self.minTapHeight - 2 * Spacing.md)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID("cluster.menu", in: glassNamespace)
        .accessibilityLabel("Mais ações")
    }

    private func foreground(for action: FloatingClusterAction, prominent: Bool) -> Color {
        guard action.enabled else { return Theme.textTertiary }
        guard prominent else { return action.tone }
        return action.onTintLabel ?? onTintForeground(for: action.tone)
    }

    /// Rótulo sobre cápsula tintada, resolvido pela luminância do tom no esquema atual: tons
    /// médios/claros (ex.: `Theme.warning` gold no dark mode) recebem texto escuro; tons escuros,
    /// branco — como o iOS faz em botões prominent amarelos. O corte em 0.30 é a luminância em
    /// que branco deixa de atingir 3:1 (WCAG, texto grande/bold) sobre o tom.
    private func onTintForeground(for tone: Color) -> Color {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let resolved = UIColor(tone).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard resolved.getRed(&r, green: &g, blue: &b, alpha: &a) else { return .white }
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        return luminance > 0.3 ? Color(hex: "#1A1A1E") : .white
    }

    // MARK: - Toques

    private func handleTap(_ action: FloatingClusterAction) {
        if isBusy {
            ToastCenter.shared.show("Aguarde a ação anterior terminar.", style: .info)
        } else if action.enabled {
            action.run()
        } else if let reason = action.disabledReason {
            ToastCenter.shared.show(reason, style: .info)
        }
    }
}
