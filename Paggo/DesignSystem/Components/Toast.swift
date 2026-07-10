import SwiftUI
import UIKit
import Observation

/// Estilo do toast — define ícone, cor e duração.
enum ToastStyle: Equatable, Sendable {
    case success, error, info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return Theme.positive
        case .error: return Theme.negative
        case .info: return Theme.textSecondary
        }
    }

    /// Erros ficam mais tempo visíveis — são a mensagem que o usuário não pode perder.
    var duration: Duration {
        self == .error ? .seconds(4) : .seconds(2.2)
    }
}

/// Evento de toast — cada `show` gera um id novo, o que reinicia o timer de dismiss do host.
struct ToastEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    let message: String
    let style: ToastStyle
}

/// Centro global de toasts. Um único host (janela dedicada, ver `ToastWindowManager`) exibe o
/// evento corrente — o toast sobrevive a trocas de tab, pops de navegação, sheets e alerts;
/// um novo `show` substitui o visível.
@MainActor
@Observable
final class ToastCenter {
    static let shared = ToastCenter()

    private(set) var current: ToastEvent?

    func show(_ message: String, style: ToastStyle = .success) {
        current = ToastEvent(id: UUID(), message: message, style: style)
    }

    func dismiss(_ id: UUID) {
        if current?.id == id { current = nil }
    }
}

/// Transient toast pinned near the bottom; auto-dismisses.
struct ToastView: View {
    let text: String
    var icon: String = "checkmark.circle.fill"
    var tint: Color = Theme.positive

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text)
                .font(.brand(.subheadline, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Theme.surfaceHigh, in: Capsule())
        .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
    }
}

/// Raiz da janela de toasts — observa o `ToastCenter` e exibe o evento corrente acima da safe
/// area inferior, alto o bastante para não colidir com o tab bar nem com os clusters de ação
/// flutuantes. O timer de dismiss é atrelado ao id do evento (`.task(id:)`): um toast novo
/// cancela o timer antigo e reinicia o seu próprio, com duração por estilo.
struct ToastOverlayView: View {
    let center: ToastCenter
    let appearance: AppearanceStore

    /// Folga acima da safe area inferior REAL da janela — limpa o tab bar (~49pt) + cluster
    /// flutuante (cápsula de 44pt + Spacing.sm de padding) com um respiro de Spacing.md.
    private static let chromeClearance: CGFloat = 49 + 44 + Spacing.sm + Spacing.md

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.clear
                if let event = center.current {
                    ToastView(text: event.message, icon: event.style.icon, tint: event.style.tint)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, proxy.safeAreaInsets.bottom + Self.chromeClearance)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(event.id)
                        .task(id: event.id) {
                            try? await Task.sleep(for: event.style.duration)
                            guard !Task.isCancelled else { return }
                            withAnimation(.snappy) { center.dismiss(event.id) }
                        }
                }
            }
            .animation(.snappy, value: center.current)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .preferredColorScheme(appearance.mode.colorScheme)
    }
}

/// Janela dedicada de toasts (nível acima de `.alert`): renderiza SOBRE pushes, tabs, sheets,
/// covers e alerts — um overlay no `RootView` perde para as camadas de apresentação do UIKit
/// (ex.: toast disparado enquanto um sheet fecha ficava escondido embaixo dele). A janela não
/// recebe toques (`isUserInteractionEnabled = false`), então tudo abaixo continua interativo.
@MainActor
final class ToastWindowManager {
    static let shared = ToastWindowManager()
    private var window: UIWindow?

    private init() {
        // Cena desconectada (janela fechada no iPad, sistema sob pressão de memória): derruba a
        // janela presa à cena morta na hora — o próximo `scenePhase == .active` reinstala na cena
        // viva. Sem isso os toasts (único canal de erro das mutações) morreriam em silêncio.
        NotificationCenter.default.addObserver(
            forName: UIScene.didDisconnectNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                let manager = ToastWindowManager.shared
                guard let scene = manager.window?.windowScene else {
                    if manager.window != nil { manager.teardown() }
                    return
                }
                if !UIApplication.shared.connectedScenes.contains(scene) { manager.teardown() }
            }
        }
    }

    /// (Re)instala a janela na cena ativa — chamado do `PaggoApp` a cada `scenePhase == .active`.
    /// Re-resolve a cena alvo SEMPRE: uma reconexão cria uma `UIWindowScene` nova, e no iPad
    /// multi-janela a cena em primeiro plano muda — a janela de toasts segue a cena ativa em vez
    /// de ficar presa à primeira cena do processo. Recriar o host mantém o override de aparência
    /// em sincronia (o `AppearanceStore` observável segue sendo a mesma instância).
    func install(appearance: AppearanceStore) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let target = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            teardown()
            return
        }
        if let window, window.windowScene === target { return }
        teardown()
        let host = UIHostingController(rootView: ToastOverlayView(center: .shared, appearance: appearance))
        host.view.backgroundColor = .clear
        let toastWindow = UIWindow(windowScene: target)
        toastWindow.windowLevel = .alert + 1
        toastWindow.isUserInteractionEnabled = false
        toastWindow.backgroundColor = .clear
        toastWindow.rootViewController = host
        toastWindow.isHidden = false
        window = toastWindow
    }

    private func teardown() {
        window?.isHidden = true
        window?.windowScene = nil
        window = nil
    }
}
