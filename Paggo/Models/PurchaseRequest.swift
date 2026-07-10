import SwiftUI

/// Type of request the user can create.
enum RequestType: String, CaseIterable, Identifiable, Sendable {
    case payment = "Pagamento"
    case reimbursement = "Reembolso"
    case purchase = "Compra"

    var id: String { rawValue }
    var label: String { rawValue }

    var icon: String {
        switch self {
        case .payment: return "creditcard.fill"
        case .reimbursement: return "arrow.uturn.backward"
        case .purchase: return "cart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .payment: return Theme.accent
        case .reimbursement: return Theme.info
        case .purchase: return Theme.positive
        }
    }

    var blurb: String {
        switch self {
        case .payment: return "Pagar boleto, Pix ou transferência"
        case .reimbursement: return "Reembolsar uma despesa já paga"
        case .purchase: return "Solicitar a compra de itens ou serviços"
        }
    }
}

/// Request status — also used as the filter segment in the list.
enum RequestStatus: String, CaseIterable, Identifiable, Sendable {
    case requested = "Solicitadas"
    case pending = "Pendentes"
    case approved = "Aprovadas"

    var id: String { rawValue }
    var segmentLabel: String { rawValue }

    /// Singular form (shown in chips/rows).
    var label: String {
        switch self {
        case .requested: return "Solicitada"
        case .pending: return "Pendente"
        case .approved: return "Aprovada"
        }
    }

    var dotColor: Color {
        switch self {
        case .requested: return Theme.info
        case .pending: return Theme.warning
        case .approved: return Theme.positive
        }
    }

    /// Open = not yet approved.
    var isOpen: Bool { self != .approved }
}

/// A request (of any type) shown in the list.
struct PurchaseRequest: Identifiable, Sendable, Hashable {
    let id: String
    var type: RequestType
    var title: String
    var requester: String
    var costCenter: String
    var amountCents: Int
    var status: RequestStatus
    var date: String        // ISO
    var itemCount: Int

    var dateValue: Date { DateText.parse(date) ?? Date() }
}

/// Project/site that consumes the requisition (mirrors the prototype).
struct Project: Identifiable, Sendable, Hashable {
    let id = UUID()
    var name: String
    var cnpj: String
    var address: String
}

/// Purchase catalog item (material/service/equipment).
struct CatalogItem: Identifiable, Sendable, Hashable {
    let id = UUID()
    var name: String
    var code: String
    var category: String   // "Material" | "Serviço" | "Equipamento"
    var unit: String       // "saco" | "barra" | "m³" | "un" | "diária"
    var unitCents: Int
    var priceLabel: String { "\(unitCents.currencyFromCents())/\(unit)" }
}

/// Line item (catalog item + quantity) used in the purchase requisition.
struct RequestItem: Identifiable, Sendable, Hashable {
    let id = UUID()
    var name: String
    var code: String
    var category: String
    var unit: String
    var quantity: Int
    var unitCents: Int
    var subtotalCents: Int { quantity * unitCents }

    init(from item: CatalogItem, quantity: Int) {
        self.name = item.name
        self.code = item.code
        self.category = item.category
        self.unit = item.unit
        self.quantity = quantity
        self.unitCents = item.unitCents
    }
}
