import Foundation

// Detalhes completos do pacote — ported from package.entity.ts + the per-section DTOs the
// Expo PackageDetails screen consumes (summary, payment-method, allocations, delivery, etc.).

/// Detalhes bancários do recebedor.
struct PaymentBankInfo: Codable, Hashable, Sendable {
    var pixKey: String?
    var emv: String?
    var bankCode: String?
    var bankCodeStr: String?
    var branchCode: String?
    var accountNumber: String?
    var name: String?
    var taxId: String?
    var accountType: String?
}

/// Documento de boleto / guia (barcode).
struct BankslipDocument: Codable, Hashable, Sendable {
    var amountTotal: Int   // cents
    var dueDate: String
    var receiverName: String?
    var digitableLine: String?
}

/// Método de pagamento.
struct PaymentMethod: Codable, Hashable, Sendable {
    var method: String     // "PIX", "PIX_BY_ACCOUNT", "PIX_QR", "BANKSLIP", "BARCODE", "UNSET", ...
    var receiverName: String?
    var bankslip: BankslipDocument?
    var barcodeDocument: BankslipDocument?
    var packageBankAccount: PackageBankAccount?

    struct PackageBankAccount: Codable, Hashable, Sendable {
        var bankAccountDetails: PaymentBankInfo?
    }

    /// Atalho para os detalhes bancários (independe do nível em que vierem).
    var bankAccountDetails: PaymentBankInfo? { packageBankAccount?.bankAccountDetails }
}

/// Alocação do pacote (rateio).
struct PackageAllocation: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var allocation: Double?     // percentual (0–100)
    var calculated: Bool?
    var unit: String?
    var project: Named?
    var costCenter: Named?
    var managerialAccount: Named?
    var description: String?

    struct Named: Codable, Hashable, Sendable { var name: String }
}

/// Mensagem do chat do pacote.
struct ChatMessage: Codable, Hashable, Identifiable, Sendable {
    /// Id real do servidor quando conhecido (mensagens do GET/POST). Ecos otimistas locais e
    /// mensagens embutidas sem id caem para `createdAt + text`.
    var serverId: String? = nil
    var text: String
    var createdAt: String
    var type: String
    var user: ChatUser?

    var id: String { serverId ?? (createdAt + text) }
    var isPlatformEvent: Bool { ChatEvent.isPlatform(type) }

    struct ChatUser: Codable, Hashable, Sendable {
        var id: String
        var name: String
        var email: String?
        var image: String?
    }
}

/// Entrada de documento (nota fiscal etc.).
struct DocumentEntry: Codable, Hashable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable {
        case identified = "IDENTIFIED"
        case recognized = "RECOGNIZED"
        case posted = "POSTED"
    }
    var id: String
    var type: TypeRef
    var number: String?
    var status: Status
    var counterpartyName: String
    var counterpartyTaxId: String
    var netAmount: Int          // cents
    var documentDate: String?
    var paymentAmount: Int?     // cents
    var reconciledAmount: Int?  // cents
    /// URL (chave S3 relativa ou absoluta) do arquivo do documento — resolvida contra o CDN
    /// público. Preferência: `fiscalInvoiceDocumentUrl` > `attachmentUrl` (paridade com o blue).
    var fileUrl: String?

    struct TypeRef: Codable, Hashable, Sendable { var name: String }
}

/// Documento anexado.
struct AttachmentDocument: Codable, Hashable, Identifiable, Sendable {
    var name: String
    var url: String
    var type: String?
    var id: String { url }
}

/// Referência de entrada de documento dentro do pacote.
struct PackageDocumentEntryRef: Codable, Hashable, Sendable {
    var documentEntry: DocumentEntry
    var amount: Int   // cents
}

struct PaymentMethodDocumentRef: Codable, Hashable, Sendable {
    var paymentMethodDocument: PaymentMethod?
}

/// Comprovante de um pagamento efetivado (metadados — o detalhe bancário vem de rota futura).
struct PaymentReceipt: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var baasId: String
    var paymentDate: String
    var paymentAmount: Int   // cents
}

/// Detalhes completos do pacote.
struct PackageDetails: Codable, Identifiable, Hashable, Sendable {
    // Base package fields
    var id: String
    var paymentDate: String
    var paymentAmount: Int
    var receiverName: String
    var receiverTaxId: String
    var status: PackageStatus
    var type: PackageType?
    var supplier: Supplier?
    var organization: Organization?
    var approval: PackageApproval?
    var tags: [PackageTag]?

    // Summary — payer / receiver flow + extra amounts
    var payerName: String?
    var payerAccountName: String?
    var payerTaxId: String?
    var payerBankName: String?
    var fine: Int?                 // cents
    var interest: Int?             // cents
    var discountOrAddition: Int?   // cents

    // Detail-only fields
    var description: String?
    var dueDate: String?
    var packagePaymentMethodDocuments: [PaymentMethodDocumentRef]?
    var allocations: [PackageAllocation]?
    var chat: Chat?
    var attachments: [AttachmentDocument]?
    var packageDocumentEntries: [PackageDocumentEntryRef]?

    // Per-section data (new sections)
    var alerts: [PaymentAlert] = []
    var detailApprovers: [PaymentApproverDetail] = []
    var delivery: DeliveryDocument?
    var budget: BudgetData?
    var conciliation: ConciliationData?

    // Budget gate + footer action flags (from the summary DTO).
    var consumesBudget: Bool = false
    var external: Bool = false              // pago fora da Paggo (baixa manual) — muda o rodapé de "Pago"
    var canApprove: Bool = false
    var hasApproved: Bool = false
    var canPayImmediately: Bool = false
    var canReset: Bool = false
    var canCancel: Bool = false
    var canReturnToValidation: Bool = false
    var canMarkAsPaid: Bool = false
    var canGroup: Bool = false
    var groupId: String?
    var receipts: [PaymentReceipt] = []     // comprovantes (metadados) de pagamentos efetivados

    struct Chat: Codable, Hashable, Sendable { var messages: [ChatMessage] }

    /// Semente a partir do Package da listagem: preenche os campos base e deixa as seções vazias
    /// (preenchidas depois pelos endpoints por-seção no modo live).
    static func seed(from p: Package) -> PackageDetails {
        PackageDetails(
            id: p.id, paymentDate: p.paymentDate, paymentAmount: p.paymentAmount,
            receiverName: p.receiverName, receiverTaxId: p.receiverTaxId, status: p.status,
            type: nil, supplier: p.supplier, organization: p.organization,
            approval: p.approval, tags: p.tags,
            payerName: p.organization?.legalName, payerAccountName: nil,
            payerTaxId: p.organization?.taxId, payerBankName: nil,
            fine: nil, interest: nil, discountOrAddition: nil,
            description: nil, dueDate: nil, packagePaymentMethodDocuments: nil,
            allocations: nil, chat: nil, attachments: nil, packageDocumentEntries: nil,
            delivery: nil, budget: nil, conciliation: nil
        )
    }

    var approvers: [PackageApprover] { approval?.packageApprovalUsers ?? [] }
    var paymentMethod: PaymentMethod? { packagePaymentMethodDocuments?.first?.paymentMethodDocument }

    var paymentTypeLabel: String? { PackageTypeLabel.label(for: type) }
    var documentEntriesCount: Int { packageDocumentEntries?.count ?? 0 }
}
