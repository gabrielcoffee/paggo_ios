import SwiftUI
import Observation

/// Purchase requests state. Mocked feature — no backend. Holds the list,
/// the selected status segment and derived summaries; new requests created in the
/// flow are inserted on top.
@MainActor
@Observable
final class PurchaseRequestsStore: SessionResettable {
    private(set) var requests: [PurchaseRequest] = MockData.purchaseRequests
    var selectedStatus: RequestStatus = .requested

    init() {
        SessionResetRegistry.shared.register(self)
    }

    /// Descarta as solicitações criadas na sessão do usuário atual no signOut, voltando ao seed
    /// mock — sem isso, solicitações de um usuário apareceriam para o próximo login.
    func reset() {
        requests = MockData.purchaseRequests
        selectedStatus = .requested
    }

    var filtered: [PurchaseRequest] {
        requests
            .filter { $0.status == selectedStatus }
            .sorted { $0.dateValue > $1.dateValue }
    }

    var openRequests: [PurchaseRequest] { requests.filter { $0.status.isOpen } }
    var openCount: Int { openRequests.count }
    var openTotalCents: Int { openRequests.reduce(0) { $0 + $1.amountCents } }

    func count(status: RequestStatus) -> Int { requests.filter { $0.status == status }.count }
    func openCount(type: RequestType) -> Int { openRequests.filter { $0.type == type }.count }

    func add(_ request: PurchaseRequest) {
        requests.insert(request, at: 0)
        selectedStatus = .requested
    }
}
