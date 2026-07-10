import SwiftUI
import Observation

/// Modo de uso do app: plataforma completa (pagamentos/aprovações) ou Carteira Digital (wallet).
/// Trocável pelo popover do avatar (abaixo da aparência).
enum AppMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case app
    case wallet

    var id: String { rawValue }

    var label: String {
        switch self {
        case .app: return "Plataforma"
        case .wallet: return "Carteira"
        }
    }

    var symbol: String {
        switch self {
        case .app: return "square.grid.2x2"
        case .wallet: return "wallet.bifold"
        }
    }
}

/// Mantém e persiste o modo (plataforma / carteira).
@MainActor
@Observable
final class AppModeStore {
    var mode: AppMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey) }
    }

    private static let storageKey = "paggo.appMode"

    init() {
        // Debug: PAGGO_MODE=app|wallet força o modo (verificação de UI).
        if let env = ProcessInfo.processInfo.environment["PAGGO_MODE"],
           let mode = AppMode(rawValue: env) {
            self.mode = mode
        } else {
            let raw = UserDefaults.standard.string(forKey: Self.storageKey)
            self.mode = raw.flatMap(AppMode.init) ?? .app
        }
    }
}
