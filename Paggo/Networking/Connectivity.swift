import SwiftUI
import Network

/// Monitora a conectividade (NWPathMonitor) e expõe `isOnline` de forma observável.
/// Usado pela camada de dados para fallback offline e para disparar o flush do Outbox.
@MainActor
@Observable
final class Connectivity {
    static let shared = Connectivity()

    private(set) var isOnline = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ai.paggo.connectivity")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: queue)
    }
}
