import Foundation
import Observation

/// Central de Avisos: notificações (dono: este domínio) + pendências (derivadas dos outros
/// domínios na hora — nunca cacheadas aqui, pra badge não mentir).
@MainActor
@Observable
final class NoticeStore: SessionResettable {
    private let repo: SpendNotificationRepository

    private(set) var notifications: [AppNotification] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var hasLoaded = false

    init(repo: SpendNotificationRepository = ServiceContainer.shared.spendNotificationRepository) {
        self.repo = repo
        SessionResetRegistry.shared.register(self)
    }

    func reset() {
        notifications = []
        isLoading = false
        loadError = nil
        hasLoaded = false
    }

    var unreadCount: Int { notifications.filter(\.isUnread).count }

    func load(force: Bool = false) async {
        if hasLoaded && !force { return }
        if force { await repo.invalidate() }
        isLoading = !hasLoaded
        loadError = nil
        do {
            notifications = try await repo.notifications()
            hasLoaded = true
        } catch {
            loadError = (error as? SpendError)?.userMessage ?? "Não foi possível carregar os avisos."
        }
        isLoading = false
    }

    func markRead(id: String) async {
        try? await repo.markRead(id: id)
        await load(force: true)
    }

    func markAllRead() async {
        try? await repo.markAllRead()
        await load(force: true)
    }
}
