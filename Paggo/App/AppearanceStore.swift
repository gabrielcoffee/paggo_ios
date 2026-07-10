import SwiftUI
import Observation

/// Preferência de aparência do usuário.
enum AppearanceMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// `nil` segue o tema do dispositivo.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var label: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Escuro"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon.stars"
        }
    }
}

/// Mantém e persiste a preferência de aparência (claro / escuro / sistema).
@MainActor
@Observable
final class AppearanceStore {
    var mode: AppearanceMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey) }
    }

    private static let storageKey = "paggo.appearance"

    init() {
        // Debug: PAGGO_APPEARANCE=light|dark|system força a aparência (verificação de UI).
        if let env = ProcessInfo.processInfo.environment["PAGGO_APPEARANCE"],
           let mode = AppearanceMode(rawValue: env) {
            self.mode = mode
        } else {
            let raw = UserDefaults.standard.string(forKey: Self.storageKey)
            self.mode = raw.flatMap(AppearanceMode.init) ?? .system
        }
    }
}
