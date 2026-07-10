import Foundation

// Ported from apps/paggo-mobile-app/src/domain/entities/package.entity.ts
// All monetary values are in **cents** (Int).

/// Status possíveis de um pacote de pagamento.
enum PackageStatus: String, Codable, CaseIterable, Sendable {
    case provisioned = "PROVISIONED"
    case reserve = "RESERVE"
    case pendingBankInfo = "PENDING_BANK_INFO"
    case paymentFailed = "PAYMENT_FAILED"
    case refunded = "REFUNDED"
    case readyForApproval = "READY_FOR_APPROVAL"
    case waitingApproval = "WAITING_APPROVAL"
    case approved = "APPROVED"
    case paymentFailedReview = "PAYMENT_FAILED_REVIEW"
    case processing = "PROCESSING"
    case paid = "PAID"
    case cancelled = "CANCELLED"
    case notPayable = "NOT_PAYABLE"
}

/// Tipos de pacote.
enum PackageType: String, Codable, CaseIterable, Sendable {
    case paymentRequest = "PAYMENT_REQUEST"
    case walletPayment = "WALLET_PAYMENT"
    case reimbursement = "REIMBURSEMENT"
    case payrollCLT = "PAYROLL_CLT"
    case payrollPJ = "PAYROLL_PJ"
}

/// Organização (empresa pagadora).
struct Organization: Codable, Hashable, Sendable {
    var taxId: String
    var legalName: String
    var abbreviation: String?
}

/// Tag de pacote (alertas / classificações).
struct PackageTag: Codable, Hashable, Sendable {
    var type: String
    var description: String?
}

/// Aprovador do pacote.
struct PackageApprover: Codable, Hashable, Identifiable, Sendable {
    var userId: String
    var approved: Bool?
    var user: ApproverUser?

    var id: String { userId }

    struct ApproverUser: Codable, Hashable, Sendable {
        var id: String
        var name: String
        var image: String?
    }

    var name: String { user?.name ?? "Aprovador" }
    var hasApproved: Bool { approved ?? false }
}

/// Aprovação do pacote (lista de aprovadores).
struct PackageApproval: Codable, Hashable, Sendable {
    var packageApprovalUsers: [PackageApprover]
}

extension PackageApproval {
    /// Aprovadores decodificados de forma tolerante: um aprovador malformado é descartado em vez de
    /// zerar a aprovação inteira do pacote. Na extensão para preservar o init memberwise sintetizado.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        packageApprovalUsers =
            (try? c.decode(LossyArray<PackageApprover>.self, forKey: .packageApprovalUsers))?.values ?? []
    }
}

/// Fornecedor.
struct Supplier: Codable, Hashable, Sendable {
    var taxName: String?
}

/// Pacote na listagem.
struct Package: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var paymentDate: String           // ISO date
    var paymentAmount: Int            // cents
    var receiverName: String
    var receiverTaxId: String
    var status: PackageStatus
    var supplier: Supplier?
    var organization: Organization?
    var approval: PackageApproval?
    var tags: [PackageTag]?

    // Campos OPCIONAIS adicionados pelo /packages estendido (aditivos, podem faltar em prod defasado).
    // Decodificados de forma tolerante; `nil` → o pedaço correspondente some da UI.
    var payerName: String?
    var payerAccount: String?
    var payerTaxId: String?
    var costCenter: String?
    var costCenterCount: Int = 0
    var managerialAccount: String?
    var managerialAccountCount: Int = 0
    var documentNumber: String?
    var documentType: String?
    var documentCount: Int = 0
    /// Número da alocação (= `unit` da primeira alocação, deduplicado) — aditivo do /packages
    /// estendido; `nil` quando o backend defasado ainda não o envia.
    var allocationNumber: String?

    var approvers: [PackageApprover] { approval?.packageApprovalUsers ?? [] }
}

/// Decodificação DEFENSIVA (limite de confiança): um campo nulo/ausente/de tipo inesperado num
/// pacote não deve derrubar a lista inteira. Campos escalares caem para um default; status
/// desconhecido cai para `.provisioned`; relações e tags malformadas viram nil/parciais. Combinado
/// com `LossyArray<Package>` no fetch, um pacote irrecuperável é apenas descartado. Fica numa
/// extensão para preservar o init memberwise sintetizado (usado pelos mocks).
extension Package {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        paymentDate = (try? c.decode(String.self, forKey: .paymentDate)) ?? ""
        paymentAmount = (try? c.decode(Int.self, forKey: .paymentAmount)) ?? 0
        receiverName = (try? c.decode(String.self, forKey: .receiverName)) ?? ""
        receiverTaxId = (try? c.decode(String.self, forKey: .receiverTaxId)) ?? ""
        if let raw = try? c.decode(String.self, forKey: .status), let parsed = PackageStatus(rawValue: raw) {
            status = parsed
        } else {
            status = .provisioned
        }
        supplier = try? c.decode(Supplier.self, forKey: .supplier)
        organization = try? c.decode(Organization.self, forKey: .organization)
        approval = try? c.decode(PackageApproval.self, forKey: .approval)
        tags = (try? c.decode(LossyArray<PackageTag>.self, forKey: .tags))?.values

        payerName = try? c.decode(String.self, forKey: .payerName)
        payerAccount = try? c.decode(String.self, forKey: .payerAccount)
        payerTaxId = try? c.decode(String.self, forKey: .payerTaxId)
        costCenter = try? c.decode(String.self, forKey: .costCenter)
        costCenterCount = (try? c.decode(Int.self, forKey: .costCenterCount)) ?? 0
        managerialAccount = try? c.decode(String.self, forKey: .managerialAccount)
        managerialAccountCount = (try? c.decode(Int.self, forKey: .managerialAccountCount)) ?? 0
        documentNumber = try? c.decode(String.self, forKey: .documentNumber)
        documentType = try? c.decode(String.self, forKey: .documentType)
        documentCount = (try? c.decode(Int.self, forKey: .documentCount)) ?? 0
        allocationNumber = try? c.decode(String.self, forKey: .allocationNumber)
    }
}

/// Totais por tab (count + total em cents).
struct PackageTotals: Codable, Sendable {
    struct Bucket: Codable, Sendable {
        var count: Int
        var total: Int   // cents
    }
    var previstos: Bucket?
    var pendencias: Bucket?
    var validacao: Bucket?
    var liberacao: Bucket?
    var agendados: Bucket?
    var pagos: Bucket?
}
