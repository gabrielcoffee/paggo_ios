import Foundation
import Observation

/// Preferências de notificação push do usuário. Persistidas apenas no dispositivo
/// (`UserDefaults`) — o backend de push é intencionalmente mockado por enquanto;
/// quando o mobile-api expuser registro de preferências, este store sincroniza lá.
@MainActor
@Observable
final class NotificationPrefsStore {
    static let shared = NotificationPrefsStore()

    struct Prefs: Codable, Equatable, Sendable {
        var approvalRequested = true
        var paymentSent = true
        var paymentReceived = true
        var paymentFailed = true
    }

    var prefs: Prefs {
        didSet { persist() }
    }

    private static let storageKey = "paggo.notificationPrefs"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(Prefs.self, from: data) {
            self.prefs = decoded
        } else {
            self.prefs = Prefs()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
