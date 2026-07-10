import Foundation

/// Pagamento agendado/futuro exibido no dashboard (GET /packages/upcoming).
/// Valores monetários em **cents**; `paymentDate` é ISO string (formatada na exibição).
struct UpcomingPayment: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var receiverName: String
    var paymentAmount: Int       // cents
    var paymentDate: String      // ISO
    var status: String
    var organizationName: String?
}
