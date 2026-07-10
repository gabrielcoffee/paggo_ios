import Foundation

// Cliente das rotas de DETALHE de um pagamento (GET /payments/{id}/*), espelhando os DTOs reais de
// `@paggo/payments-service/*`. Os DTOs aqui são TOLERANTES (campos opcionais) para não quebrar o
// decode caso o backend omita/renomeie um campo — mapeiam para os modelos de exibição existentes.
// São `Codable` (não só `Decodable`) para transitarem pelo cache do `QueryClient`.
struct PaymentDetailsAPI: Sendable {
    let client: APIClient

    func summary(id: String) async throws -> RemoteSummary {
        try await client.send(.get("/payments/\(id)/summary"))
    }
    func tags(id: String) async throws -> RemoteTags {
        try await client.send(.get("/payments/\(id)/tags"))
    }
    func methods(id: String) async throws -> RemoteMethod {
        try await client.send(.get("/payments/\(id)/methods"))
    }
    func allocations(id: String) async throws -> RemoteAllocations {
        try await client.send(.get("/payments/\(id)/allocations"))
    }
    func approvers(id: String) async throws -> RemoteApprovers {
        try await client.send(.get("/payments/\(id)/approvers"))
    }
    func delivery(id: String) async throws -> RemoteDelivery {
        try await client.send(.get("/payments/\(id)/delivery-document"))
    }
    func budget(id: String) async throws -> RemoteBudget {
        try await client.send(.get("/payments/\(id)/budget"))
    }
    func conciliation(id: String) async throws -> RemoteConciliation {
        try await client.send(.get("/payments/\(id)/conciliation"))
    }
    func alerts(id: String) async throws -> RemoteAlerts {
        try await client.send(.get("/payments/\(id)/alerts"))
    }
    func documentEntries(id: String) async throws -> RemoteDocumentEntries {
        try await client.send(.get("/payments/\(id)/document-entries"))
    }
}

// MARK: - Helpers

/// Cents podem chegar como Int ou Double no JSON; normaliza para Int.
private func cents(_ value: Double?) -> Int { value.map { Int($0.rounded()) } ?? 0 }

// MARK: - Summary (GetPaymentSummaryResponseDto)

struct RemoteSummary: Codable, Sendable {
    var status: String?
    var type: String?
    var payerName: String?
    var payerAccountName: String?
    var payerBankName: String?
    var payerTaxId: String?
    var receiverName: String?
    var receiverDocumentNumber: String?
    var paymentAmount: Double?
    var fine: Double?
    var interest: Double?
    var discountOrAddition: Double?
    var dueDate: String?
    var paymentDate: String?
    var description: String?
    var consumesBudget: Bool?
    var external: Bool?
    var canApprove: Bool?
    var hasApproved: Bool?
    var canPayImmediately: Bool?
    var canReset: Bool?
    var canCancel: Bool?
    var canReturnToValidation: Bool?
    var canMarkAsPaid: Bool?
    var canGroup: Bool?
    var groupId: String?
    var receipts: [Receipt]?
    var prDocumentEntries: [PRDocEntry]?

    struct Receipt: Codable, Sendable {
        var id: String
        var baasId: String
        var paymentDate: String?
        var paymentAmount: Double?
    }

    struct PRDocEntry: Codable, Sendable {
        var documentEntry: Doc
        struct Doc: Codable, Sendable {
            var id: String
            var status: String?
            var type: TypeRef?
            var number: String?
            var netAmount: Double?
            var reconciledAmount: Double?
            var counterpartyName: String?
            var counterpartyTaxId: String?
            var documentDate: String?
            struct TypeRef: Codable, Sendable { var name: String? }
        }
    }

    /// Aplica os campos do summary sobre o `PackageDetails` semeado a partir do Package base.
    func apply(to d: inout PackageDetails) {
        if let s = status, let mapped = PackageStatus(rawValue: s) { d.status = mapped }
        if let t = type { d.type = PackageType(rawValue: t) }
        d.payerName = payerName ?? d.payerName
        d.payerAccountName = payerAccountName ?? d.payerAccountName
        d.payerBankName = payerBankName
        d.payerTaxId = payerTaxId ?? d.organization?.taxId
        if let r = receiverName { d.receiverName = r }
        if let rt = receiverDocumentNumber { d.receiverTaxId = rt }
        if let a = paymentAmount { d.paymentAmount = Int(a.rounded()) }
        d.fine = (fine ?? 0) > 0 ? cents(fine) : nil
        d.interest = (interest ?? 0) > 0 ? cents(interest) : nil
        d.discountOrAddition = (discountOrAddition ?? 0) > 0 ? cents(discountOrAddition) : nil
        d.dueDate = dueDate ?? d.dueDate
        if let pd = paymentDate { d.paymentDate = pd }
        if let desc = description, !desc.isEmpty { d.description = desc }
        d.consumesBudget = consumesBudget ?? false
        d.external = external ?? false
        d.canApprove = canApprove ?? false
        d.hasApproved = hasApproved ?? false
        d.canPayImmediately = canPayImmediately ?? false
        d.canReset = canReset ?? false
        d.canCancel = canCancel ?? false
        d.canReturnToValidation = canReturnToValidation ?? false
        d.canMarkAsPaid = canMarkAsPaid ?? false
        d.canGroup = canGroup ?? false
        d.groupId = groupId
        d.receipts = (receipts ?? []).map {
            PaymentReceipt(id: $0.id, baasId: $0.baasId,
                           paymentDate: $0.paymentDate ?? "", paymentAmount: cents($0.paymentAmount))
        }
        // Merge com o que a rota /document-entries pode já ter aplicado (fileUrl + amount):
        // as duas seções chegam em paralelo, então nenhuma pode sobrescrever a outra às cegas.
        let existing = Dictionary(
            (d.packageDocumentEntries ?? []).map { ($0.documentEntry.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var merged = (prDocumentEntries ?? []).map { e in
            let prior = existing[e.documentEntry.id]
            return PackageDocumentEntryRef(
                documentEntry: DocumentEntry(
                    id: e.documentEntry.id,
                    type: .init(name: e.documentEntry.type?.name ?? "—"),
                    number: e.documentEntry.number,
                    status: DocumentEntry.Status(rawValue: e.documentEntry.status ?? "") ?? .identified,
                    counterpartyName: e.documentEntry.counterpartyName ?? "—",
                    counterpartyTaxId: e.documentEntry.counterpartyTaxId ?? "",
                    netAmount: cents(e.documentEntry.netAmount),
                    documentDate: e.documentEntry.documentDate,
                    paymentAmount: nil,
                    reconciledAmount: cents(e.documentEntry.reconciledAmount),
                    fileUrl: prior?.documentEntry.fileUrl
                ),
                amount: prior?.amount ?? 0
            )
        }
        // União por id (espelho do append em RemoteDocumentEntries.apply): entradas que só a
        // rota /document-entries conhece sobrevivem com seus dados, independente da ordem em
        // que as duas seções resolverem. Metadados do summary vencem nos ids compartilhados.
        let summaryIds = Set(merged.map { $0.documentEntry.id })
        merged.append(contentsOf: (d.packageDocumentEntries ?? []).filter {
            !summaryIds.contains($0.documentEntry.id)
        })
        d.packageDocumentEntries = merged
    }
}

// MARK: - Document entries (GetPaymentDocumentEntriesResponseDto)

/// Espelha `payment-document-entries.schema.ts` (payments-service). Diferente do summary, esta
/// rota expõe as URLs de arquivo (`fiscalInvoiceDocumentUrl` / `attachmentUrl`) e o valor usado
/// neste pagamento (`currentPaymentUsageAmount`).
struct RemoteDocumentEntries: Codable, Sendable {
    var supplierCustomerId: String?
    var paymentAmount: Double?
    var documents: [Doc]?

    struct Doc: Codable, Sendable {
        var id: String
        var status: String?
        var direction: String?
        var type: TypeRef?
        var currentPaymentUsageAmount: Double?
        var retentionAmount: Double?
        var reconciledAmount: Double?
        var connectedAmount: Double?
        var counterpartyName: String?
        var counterpartyTaxId: String?
        var amountTotal: Double?
        var number: String?
        var attachmentUrl: String?
        var fiscalInvoiceDocumentUrl: String?
        var documentDate: String?

        struct TypeRef: Codable, Sendable { var id: String?; var name: String? }

        /// Preferência de arquivo (paridade com o blue): NF-e primeiro, anexo como fallback.
        var fileUrl: String? {
            if let fiscal = fiscalInvoiceDocumentUrl, !fiscal.isEmpty { return fiscal }
            return attachmentUrl
        }
    }

    /// Merge-by-id sobre as entradas semeadas pelo summary: enriquece `fileUrl` e corrige o
    /// `amount` (o summary não traz `currentPaymentUsageAmount`). Documentos que ainda não
    /// existirem (summary pendente ou API antiga) são acrescentados.
    func apply(to d: inout PackageDetails) {
        let docs = documents ?? []
        guard !docs.isEmpty else { return }

        var entries = d.packageDocumentEntries ?? []
        for doc in docs {
            if let index = entries.firstIndex(where: { $0.documentEntry.id == doc.id }) {
                entries[index].documentEntry.fileUrl = doc.fileUrl
                if let usage = doc.currentPaymentUsageAmount {
                    entries[index].amount = Int(usage.rounded())
                }
            } else {
                entries.append(PackageDocumentEntryRef(
                    documentEntry: DocumentEntry(
                        id: doc.id,
                        type: .init(name: doc.type?.name ?? "—"),
                        number: doc.number,
                        status: DocumentEntry.Status(rawValue: doc.status ?? "") ?? .identified,
                        counterpartyName: doc.counterpartyName ?? "—",
                        counterpartyTaxId: doc.counterpartyTaxId ?? "",
                        netAmount: cents(doc.amountTotal),
                        documentDate: doc.documentDate,
                        paymentAmount: nil,
                        reconciledAmount: cents(doc.reconciledAmount),
                        fileUrl: doc.fileUrl
                    ),
                    amount: cents(doc.currentPaymentUsageAmount)
                ))
            }
        }
        d.packageDocumentEntries = entries
    }
}

// MARK: - Tags

struct RemoteTags: Codable, Sendable {
    var tags: [Tag]?
    var paymentType: String?
    struct Tag: Codable, Sendable { var type: String; var description: String? }

    func apply(to d: inout PackageDetails) {
        d.tags = (tags ?? []).map { PackageTag(type: $0.type, description: $0.description) }
        if let pt = paymentType { d.type = PackageType(rawValue: pt) ?? d.type }
    }
}

// MARK: - Payment method

struct RemoteMethod: Codable, Sendable {
    var method: String?
    var receiverName: String?
    var bankAccountDetails: BankDetails?
    var bankslip: Slip?
    var barcodeDocument: Slip?

    struct BankDetails: Codable, Sendable {
        var name: String?; var taxId: String?; var bankCode: String?
        var accountNumber: String?; var pixKey: String?; var emv: String?
    }
    struct Slip: Codable, Sendable {
        var amountTotal: Double?; var dueDate: String?; var receiverName: String?; var digitableLine: String?
    }

    func apply(to d: inout PackageDetails) {
        let bank = bankAccountDetails.map { b in
            PaymentBankInfo(pixKey: b.pixKey, emv: b.emv, bankCode: b.bankCode, bankCodeStr: b.bankCode,
                            branchCode: nil, accountNumber: b.accountNumber, name: b.name,
                            taxId: b.taxId, accountType: nil)
        }
        let pm = PaymentMethod(
            method: method ?? "UNSET",
            receiverName: receiverName,
            bankslip: bankslip.map { BankslipDocument(amountTotal: cents($0.amountTotal),
                                                      dueDate: $0.dueDate ?? "", receiverName: $0.receiverName,
                                                      digitableLine: $0.digitableLine) },
            barcodeDocument: barcodeDocument.map { BankslipDocument(amountTotal: cents($0.amountTotal),
                                                                    dueDate: $0.dueDate ?? "", receiverName: $0.receiverName,
                                                                    digitableLine: $0.digitableLine) },
            packageBankAccount: bank.map { .init(bankAccountDetails: $0) }
        )
        d.packagePaymentMethodDocuments = [.init(paymentMethodDocument: pm)]
    }
}

// MARK: - Allocations

struct RemoteAllocations: Codable, Sendable {
    var allocations: [Alloc]?
    struct Alloc: Codable, Sendable {
        var id: String
        var allocation: Double?
        var unit: String?
        var description: String?
        var calculated: Bool?
        var project: Named?
        var costCenter: Named?
        var managerialAccount: Named?
        struct Named: Codable, Sendable { var name: String? }
    }

    func apply(to d: inout PackageDetails) {
        d.allocations = (allocations ?? []).map { a in
            PackageAllocation(
                id: a.id, allocation: a.allocation, calculated: a.calculated, unit: a.unit,
                project: a.project?.name.map { .init(name: $0) },
                costCenter: a.costCenter?.name.map { .init(name: $0) },
                managerialAccount: a.managerialAccount?.name.map { .init(name: $0) },
                description: a.description
            )
        }
    }
}

// MARK: - Approvers

struct RemoteApprovers: Codable, Sendable {
    var approvers: [Approver]?
    struct Approver: Codable, Sendable {
        var id: String; var name: String; var group: Int?; var approved: Bool?
        var image: String?; var email: String?
    }

    func apply(to d: inout PackageDetails) {
        d.detailApprovers = (approvers ?? []).map {
            PaymentApproverDetail(id: $0.id, group: $0.group ?? 1, name: $0.name,
                                  email: $0.email ?? "", image: $0.image, approved: $0.approved)
        }
    }
}

// MARK: - Conciliation

struct RemoteConciliation: Codable, Sendable {
    var financialEntryId: String?
    var reconciled: Bool?
    var config: Config?
    struct Config: Codable, Sendable {
        var enforceValidEntriesBeforePosting: Bool?
        var enforcePostingBeforeConciliation: Bool?
    }

    func apply(to d: inout PackageDetails) {
        d.conciliation = ConciliationData(
            reconciled: reconciled ?? false,
            financialEntryId: financialEntryId,
            enforcePostingBeforeConciliation: config?.enforcePostingBeforeConciliation ?? false,
            enforceValidEntriesBeforeConciliation: config?.enforceValidEntriesBeforePosting ?? false
        )
    }
}

// MARK: - Alerts

struct RemoteAlerts: Codable, Sendable {
    var alerts: [Alert]?
    struct Alert: Codable, Sendable {
        var id: String; var title: String; var description: String?
        var variant: String?; var isActive: Bool?
    }

    func apply(to d: inout PackageDetails) {
        d.alerts = (alerts ?? []).filter { $0.isActive ?? true }.map {
            let variant: AlertVariant
            switch $0.variant {
            case "error": variant = .error
            case "warning": variant = .warning
            default: variant = .info
            }
            return PaymentAlert(id: $0.id, variant: variant, title: $0.title, description: $0.description ?? "")
        }
    }
}

// MARK: - Budget (PaymentBudgetDetailsResponseDto)

struct RemoteBudget: Codable, Sendable {
    var budgetLineConsumptions: [Line]?
    var summary: Summary?
    struct Line: Codable, Sendable {
        var budgetLineId: String?
        var budgetPlanName: String?
        var entityName: String?
        var entityType: String?
        var totalBudgetAmount: Double?
        var totalUsedAmount: Double?
        var packageContributionAmount: Double?
        var remainingAmount: Double?
        var percentageUsed: Double?
        var isOverBudget: Bool?
    }
    struct Summary: Codable, Sendable { var hasOverBudgetLines: Bool? }

    func apply(to d: inout PackageDetails) {
        let lines = (budgetLineConsumptions ?? []).enumerated().map { idx, l in
            BudgetLine(
                id: l.budgetLineId ?? "bl-\(idx)",
                budgetPlanName: l.budgetPlanName ?? "—",
                entityName: l.entityName ?? "—",
                entityType: l.entityType ?? "",
                totalBudgetAmount: cents(l.totalBudgetAmount),
                totalUsedAmount: cents(l.totalUsedAmount),
                packageContributionAmount: cents(l.packageContributionAmount),
                remainingAmount: cents(l.remainingAmount),
                percentageUsed: l.percentageUsed ?? 0,
                isOverBudget: l.isOverBudget ?? false
            )
        }
        d.budget = BudgetData(lines: lines, hasOverBudgetLines: summary?.hasOverBudgetLines ?? lines.contains { $0.isOverBudget })
    }
}

// MARK: - Delivery / Origem (GetPaymentDeliveryDocumentResponseDto)

struct RemoteDelivery: Codable, Sendable {
    var type: String?
    var paymentRequest: PR?
    var reimbursement: Reimb?
    var payroll: Payroll?
    var wallet: Wallet?

    struct PR: Codable, Sendable {
        var documentNumber: String?
        var description: String?
        var requester: Requester?
        var installments: [Inst]?
        struct Inst: Codable, Sendable { var number: Int?; var amount: Double?; var dueDate: String?; var status: String? }
        struct Requester: Codable, Sendable { var name: String?; var image: String? }
    }
    struct Reimb: Codable, Sendable {
        var description: String?; var amount: Double?
        var requestingForAnotherPerson: Bool?
        var user: Person?; var reimbursedUser: Person?
        struct Person: Codable, Sendable { var name: String?; var image: String? }
    }
    struct Payroll: Codable, Sendable {
        var employeeName: String?; var employeeTaxId: String?; var regimen: String?
        var status: String?; var salary: Double?; var payrollMonth: String?
    }
    struct Wallet: Codable, Sendable {
        var amount: Double?; var description: String?; var status: String?
        var receiverName: String?
        var intent: Intent?; var wallet: WalletRef?
        struct Intent: Codable, Sendable { var user: User?; struct User: Codable, Sendable { var name: String?; var image: String? } }
        struct WalletRef: Codable, Sendable { var name: String? }
    }

    func apply(to d: inout PackageDetails) {
        let deliveryType = DeliveryType(rawValue: type ?? "") ?? .paymentRequest
        var doc = DeliveryDocument(type: deliveryType)
        if let pr = paymentRequest {
            doc.paymentRequest = PaymentRequestDelivery(
                documentNumber: pr.documentNumber,
                description: pr.description,
                requester: DeliveryPerson(name: pr.requester?.name ?? "—", image: pr.requester?.image),
                installments: (pr.installments ?? []).map {
                    DeliveryInstallment(number: $0.number ?? 0, amount: cents($0.amount),
                                        dueDate: $0.dueDate ?? "", status: $0.status)
                }
            )
        }
        if let r = reimbursement {
            doc.reimbursement = ReimbursementDelivery(
                description: r.description, amount: cents(r.amount), categoryName: nil,
                user: DeliveryPerson(name: r.user?.name ?? "—", image: r.user?.image),
                requestingForAnotherPerson: r.requestingForAnotherPerson ?? false,
                reimbursedUserName: r.reimbursedUser?.name
            )
        }
        if let p = payroll {
            doc.payroll = PayrollDelivery(
                employeeName: p.employeeName ?? "—", employeeTaxId: p.employeeTaxId ?? "",
                regimen: p.regimen ?? "", status: p.status ?? "", salary: cents(p.salary),
                payrollMonth: p.payrollMonth ?? "—"
            )
        }
        if let w = wallet {
            doc.wallet = WalletDelivery(
                walletName: w.wallet?.name ?? "Carteira", amount: cents(w.amount),
                status: w.status ?? "", user: DeliveryPerson(name: w.intent?.user?.name ?? "—", image: w.intent?.user?.image),
                description: w.description
            )
        }
        d.delivery = doc
    }
}
