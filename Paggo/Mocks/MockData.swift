import Foundation

// Deterministic mock data mirroring apps/paggo-mobile-app/src/mocks/*.
// Money is in cents. Dates are ISO strings derived from "today" so the data always looks current.

enum MockData {
    // MARK: - Deterministic pseudo-random helper

    /// Small LCG so the mock looks varied but is stable across launches (good for screenshots).
    private struct Seeded {
        private var state: UInt64
        init(_ seed: UInt64) { state = seed &* 2862933555777941757 &+ 3037000493 }
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
        mutating func int(_ range: ClosedRange<Int>) -> Int {
            let span = UInt64(range.upperBound - range.lowerBound + 1)
            return range.lowerBound + Int(next() % span)
        }
    }

    private static func iso(daysFromNow days: Int) -> String {
        Date().adding(days: days).isoString
    }

    // MARK: - Reference lists (ported from packages.mock.ts)

    private static let supplierNames = [
        "Tech Solutions LTDA", "Construções ABC S.A.", "Consultoria XYZ",
        "Serviços Integrados ME", "Indústria Nacional S.A.", "Transportes Rápidos LTDA",
        "Materiais & Cia", "Digital Services Corp", "Fornecedora Central", "Logística Express",
    ]

    private static let organizations = [
        Organization(taxId: "12.345.678/0001-90", legalName: "Empresa Alpha S.A.", abbreviation: "ALPHA"),
        Organization(taxId: "98.765.432/0001-10", legalName: "Grupo Beta LTDA", abbreviation: "BETA"),
        Organization(taxId: "55.555.555/0001-55", legalName: "Corporação Gamma", abbreviation: "GAMMA"),
    ]

    private static let taxIds = [
        "12.345.678/0001-90", "045.678.912-34", "98.765.432/0001-10",
        "23.456.789/0001-12", "321.654.987-00", "55.555.555/0001-55",
        "11.222.333/0001-44", "789.456.123-21", "33.444.555/0001-66", "654.321.987-09",
    ]

    // MARK: - Packages

    private static func tags(for status: PackageStatus, rng: inout Seeded) -> [PackageTag] {
        var out: [PackageTag] = []
        switch status {
        case .paymentFailed: out.append(PackageTag(type: "PAYMENT_ERROR", description: "Erro no pagamento"))
        case .pendingBankInfo: out.append(PackageTag(type: "MISSING_BANK_INFO", description: "Dados bancários pendentes"))
        case .refunded: out.append(PackageTag(type: "ERP_CONFIRMATION_FAILED", description: nil))
        case .readyForApproval where rng.int(0...2) == 0: out.append(PackageTag(type: "EXCEEDS_BUDGET", description: nil))
        default: break
        }
        if rng.int(0...4) == 0 { out.append(PackageTag(type: "HIGH_VALUE", description: "Alto valor")) }
        if rng.int(0...6) == 0 { out.append(PackageTag(type: "URGENT", description: nil)) }
        return out
    }

    private static func approval(for status: PackageStatus, index: Int) -> PackageApproval? {
        guard status == .waitingApproval else { return nil }
        // First approver is the current user (so the Approvals screen has actionable items).
        return PackageApproval(packageApprovalUsers: [
            PackageApprover(userId: "current-user", approved: false,
                            user: .init(id: "current-user", name: "Você", image: nil)),
            PackageApprover(userId: "user_2", approved: index % 2 == 0,
                            user: .init(id: "user_2", name: "Maria Santos", image: nil)),
            PackageApprover(userId: "user_3", approved: index % 3 == 0,
                            user: .init(id: "user_3", name: "João Silva", image: nil)),
        ])
    }

    private static func makePackage(_ id: Int, status: PackageStatus) -> Package {
        var rng = Seeded(UInt64(id) &* 97 &+ 13)
        let supplierName = supplierNames[rng.int(0...(supplierNames.count - 1))]
        let org = organizations[rng.int(0...(organizations.count - 1))]
        let receiverTaxId = taxIds[rng.int(0...(taxIds.count - 1))]
        // 500,00 → 75.000,00 (cents)
        let amount = rng.int(50_000...7_500_000)
        let dayOffset = status == .paid ? -rng.int(1...30) : rng.int(0...30)
        return Package(
            id: "pkg_\(String(format: "%06d", id))",
            paymentDate: iso(daysFromNow: dayOffset),
            paymentAmount: amount,
            receiverName: supplierName,
            receiverTaxId: receiverTaxId,
            status: status,
            supplier: Supplier(taxName: supplierName),
            organization: org,
            approval: approval(for: status, index: id),
            tags: tags(for: status, rng: &rng)
        )
    }

    private static func packages(_ statuses: [PackageStatus], count: Int, startId: Int) -> [Package] {
        (0..<count).map { i in
            let status = statuses[i % statuses.count]
            return makePackage(startId + i, status: status)
        }
        .sorted { $0.paymentDate > $1.paymentDate }
    }

    /// Pacotes pré-gerados por tab (espelha MOCK_PACKAGES_BY_TAB).
    static let packagesByTab: [PackageTab: [Package]] = [
        .provisioned: packages([.provisioned, .reserve], count: 12, startId: 100),
        .pending: packages([.paymentFailed, .pendingBankInfo, .refunded], count: 5, startId: 200),
        .validation: packages([.readyForApproval], count: 8, startId: 300),
        .approval: packages([.waitingApproval], count: 15, startId: 400),
        .scheduled: packages([.approved, .processing], count: 23, startId: 500),
        .paid: packages([.paid], count: 20, startId: 600),
    ]

    /// Totais por tab (count + total em cents) — espelha MOCK_TOTALS.
    static let totals = PackageTotals(
        previstos: .init(count: 12, total: 15_678_050),
        pendencias: .init(count: 5, total: 4_523_000),
        validacao: .init(count: 8, total: 8_950_075),
        liberacao: .init(count: 15, total: 23_456_790),
        agendados: .init(count: 23, total: 56_789_025),
        pagos: .init(count: 142, total: 234_567_800)
    )

    // MARK: - Package details (espelha generateMockPackageDetails + per-section DTOs)

    static func details(for pkg: Package) -> PackageDetails {
        var rng = Seeded(UInt64(abs(pkg.id.hashValue)))

        // Payment method — cycles through every variant so all branches are exercised.
        let methods = ["PIX", "PIX_BY_ACCOUNT", "PIX_QR", "BANKSLIP", "BARCODE"]
        let method = methods[rng.int(0...(methods.count - 1))]
        let usesBankAccount = method == "PIX" || method == "PIX_BY_ACCOUNT" || method == "PIX_QR"
        let bankInfo = PaymentBankInfo(
            pixKey: method == "PIX" ? pkg.receiverTaxId : nil,
            emv: method == "PIX_QR" ? "00020126360014BR.GOV.BCB.PIX0114\(pkg.receiverTaxId)5204000053039865802BR6009SAO PAULO62070503***6304A1B2" : nil,
            bankCode: "341", bankCodeStr: "00000341", branchCode: "1234",
            accountNumber: "12345-6", name: pkg.receiverName, taxId: pkg.receiverTaxId, accountType: "CHECKING"
        )
        let paymentMethod = PaymentMethod(
            method: method,
            receiverName: pkg.receiverName,
            bankslip: method == "BANKSLIP"
                ? BankslipDocument(amountTotal: pkg.paymentAmount, dueDate: iso(daysFromNow: 10),
                                   receiverName: pkg.receiverName,
                                   digitableLine: "34191.79001 01043.510047 91020.150008 9 91230000\(String(format: "%07d", pkg.paymentAmount % 10_000_000))")
                : nil,
            barcodeDocument: method == "BARCODE"
                ? BankslipDocument(amountTotal: pkg.paymentAmount, dueDate: iso(daysFromNow: 10),
                                   receiverName: pkg.receiverName, digitableLine: nil)
                : nil,
            packageBankAccount: usesBankAccount ? .init(bankAccountDetails: bankInfo) : nil
        )

        // Origem (delivery) — type drives which sub-document the screen renders.
        let (packageType, delivery) = deliveryDocument(typeIndex: rng.int(0...3), pkg: pkg, rng: &rng)

        // Footer flags + budget gate.
        let waiting = pkg.status == .waitingApproval
        let approvedNow = pkg.status == .approved
        let scheduled = pkg.status == .approved || pkg.status == .processing
        let paid = pkg.status == .paid
        let pendingBank = pkg.status == .pendingBankInfo
        let isExternal = pendingBank || (paid && rng.int(0...1) == 0)   // exercita "Pago externamente"
        let receipts: [PaymentReceipt] = paid
            ? [PaymentReceipt(id: "rcp-\(pkg.id)", baasId: "baas-\(pkg.id)",
                              paymentDate: pkg.paymentDate, paymentAmount: pkg.paymentAmount)]
            : []
        let consumesBudget = rng.int(0...1) == 0
        let hasExtra = rng.int(0...2) == 0

        return PackageDetails(
            id: pkg.id,
            paymentDate: pkg.paymentDate,
            paymentAmount: pkg.paymentAmount,
            receiverName: pkg.receiverName,
            receiverTaxId: pkg.receiverTaxId,
            status: pkg.status,
            type: packageType,
            supplier: pkg.supplier,
            organization: pkg.organization,
            approval: pkg.approval ?? approval(for: pkg.status, index: 1),
            tags: pkg.tags,
            payerName: pkg.organization?.legalName,
            payerAccountName: "Conta Principal",
            payerTaxId: pkg.organization?.taxId,
            payerBankName: "Itaú Unibanco",
            fine: hasExtra ? 1_500 : nil,
            interest: hasExtra ? 2_300 : nil,
            discountOrAddition: hasExtra ? 5_000 : nil,
            description: "Pagamento referente a serviços prestados por \(pkg.receiverName).",
            dueDate: iso(daysFromNow: 5),
            packagePaymentMethodDocuments: [.init(paymentMethodDocument: paymentMethod)],
            allocations: [
                PackageAllocation(id: "al-\(pkg.id)-1", allocation: 60, calculated: false, unit: "Matriz",
                                  project: .init(name: "Projeto Principal"),
                                  costCenter: .init(name: "Centro de Custo A"),
                                  managerialAccount: .init(name: "Despesas Operacionais"),
                                  description: "Rateio principal da obra"),
                PackageAllocation(id: "al-\(pkg.id)-2", allocation: 40, calculated: true, unit: "Filial",
                                  project: .init(name: "Projeto Secundário"),
                                  costCenter: .init(name: "Centro de Custo B"),
                                  managerialAccount: .init(name: "Despesas Administrativas"),
                                  description: nil),
            ],
            chat: .init(messages: [
                ChatMessage(text: "Pagamento criado",
                            createdAt: iso(daysFromNow: -5), type: "PACKAGE_CREATED",
                            user: .init(id: "system", name: "Sistema", email: nil, image: nil)),
                ChatMessage(text: "Documentação anexada ao pagamento.",
                            createdAt: iso(daysFromNow: -3), type: "TEXT",
                            user: .init(id: "user-1", name: "João Silva", email: "joao@empresa.com", image: nil)),
                ChatMessage(text: "Enviado para liberação",
                            createdAt: iso(daysFromNow: -2), type: "SENT_FOR_APPROVAL",
                            user: .init(id: "system", name: "Sistema", email: nil, image: nil)),
                ChatMessage(text: "Por favor, verificar os valores antes de liberar.",
                            createdAt: iso(daysFromNow: -1), type: "TEXT",
                            user: .init(id: "user-2", name: "Maria Santos", email: "maria@empresa.com", image: nil)),
            ]),
            attachments: [
                AttachmentDocument(name: "Nota Fiscal.pdf", url: "/documents/nf-123.pdf", type: "application/pdf"),
                AttachmentDocument(name: "Comprovante.pdf", url: "/documents/comprovante-456.pdf", type: "application/pdf"),
            ],
            packageDocumentEntries: documentEntries(for: pkg),
            alerts: alerts(for: pkg, consumesBudget: consumesBudget),
            detailApprovers: detailApprovers(for: pkg.status),
            delivery: delivery,
            budget: consumesBudget ? budgetData(for: pkg, rng: &rng) : nil,
            conciliation: ConciliationData(
                reconciled: pkg.status == .paid,
                financialEntryId: pkg.status == .paid ? "fin-\(pkg.id)" : nil,
                enforcePostingBeforeConciliation: true,
                enforceValidEntriesBeforeConciliation: false
            ),
            consumesBudget: consumesBudget,
            external: isExternal,
            canApprove: waiting,
            hasApproved: false,
            canPayImmediately: approvedNow,
            canReset: false,
            canCancel: scheduled || waiting || pendingBank,
            canReturnToValidation: waiting || approvedNow,
            canMarkAsPaid: pendingBank && isExternal,
            canGroup: paid && !isExternal,
            groupId: (paid && !isExternal) ? "grp-\(pkg.id)" : nil,
            receipts: receipts
        )
    }

    private static func documentEntries(for pkg: Package) -> [PackageDocumentEntryRef] {
        [
            PackageDocumentEntryRef(
                documentEntry: DocumentEntry(
                    id: "doc-\(pkg.id)-1", type: .init(name: "FISCAL_INVOICE_SERVICE"),
                    number: "00012345", status: .posted,
                    counterpartyName: pkg.receiverName, counterpartyTaxId: pkg.receiverTaxId,
                    netAmount: pkg.paymentAmount, documentDate: iso(daysFromNow: -10),
                    paymentAmount: pkg.paymentAmount,
                    reconciledAmount: Int(Double(pkg.paymentAmount) * 0.7)
                ),
                amount: Int(Double(pkg.paymentAmount) * 0.6)
            ),
            PackageDocumentEntryRef(
                documentEntry: DocumentEntry(
                    id: "doc-\(pkg.id)-2", type: .init(name: "FISCAL_INVOICE_PRODUCT"),
                    number: "00067890", status: .identified,
                    counterpartyName: pkg.receiverName, counterpartyTaxId: pkg.receiverTaxId,
                    netAmount: Int(Double(pkg.paymentAmount) * 0.4), documentDate: iso(daysFromNow: -6),
                    paymentAmount: nil, reconciledAmount: 0
                ),
                amount: Int(Double(pkg.paymentAmount) * 0.4)
            ),
        ]
    }

    private static func alerts(for pkg: Package, consumesBudget: Bool) -> [PaymentAlert] {
        var out: [PaymentAlert] = []
        if pkg.status == .pendingBankInfo {
            out.append(PaymentAlert(id: "al-bank", variant: .error,
                                    title: "Dados bancários ausentes",
                                    description: "Cadastre os dados bancários do recebedor para liberar o pagamento."))
        }
        if (pkg.tags ?? []).contains(where: { $0.type == "HIGH_VALUE" }) {
            out.append(PaymentAlert(id: "al-high", variant: .warning,
                                    title: "Pagamento de alto valor",
                                    description: "Confira os valores e o recebedor antes de liberar."))
        }
        return out
    }

    private static func detailApprovers(for status: PackageStatus) -> [PaymentApproverDetail] {
        let allApproved = status == .approved || status == .paid || status == .processing
        return [
            PaymentApproverDetail(id: "ap-1", group: 1, name: "Você", email: "voce@empresa.com.br",
                                  image: nil, approved: allApproved ? true : nil),
            PaymentApproverDetail(id: "ap-2", group: 1, name: "Maria Santos", email: "maria@empresa.com.br",
                                  image: nil, approved: true),
            PaymentApproverDetail(id: "ap-3", group: 2, name: "João Silva", email: "joao@empresa.com.br",
                                  image: nil, approved: allApproved ? true : (status == .paymentFailed ? false : nil)),
        ]
    }

    private static func deliveryDocument(typeIndex: Int, pkg: Package, rng: inout Seeded)
        -> (PackageType, DeliveryDocument) {
        switch typeIndex {
        case 1:
            return (.reimbursement, DeliveryDocument(type: .reimbursement, reimbursement: ReimbursementDelivery(
                description: "Reembolso de despesas de viagem",
                amount: pkg.paymentAmount, categoryName: "Viagens",
                user: DeliveryPerson(name: "Carlos Pereira"),
                requestingForAnotherPerson: rng.int(0...1) == 0,
                reimbursedUserName: "Ana Lima")))
        case 2:
            return (.payrollCLT, DeliveryDocument(type: .payrollCLT, payroll: PayrollDelivery(
                employeeName: pkg.receiverName, employeeTaxId: pkg.receiverTaxId,
                regimen: "CLT", status: "SENT", salary: pkg.paymentAmount, payrollMonth: "06/2026")))
        case 3:
            return (.walletPayment, DeliveryDocument(type: .walletPayment, wallet: WalletDelivery(
                walletName: "Carteira Corporativa", amount: pkg.paymentAmount, status: "CONFIRMED",
                user: DeliveryPerson(name: "Beatriz Souza"),
                description: "Pagamento via carteira digital")))
        default:
            return (.paymentRequest, DeliveryDocument(type: .paymentRequest, paymentRequest: PaymentRequestDelivery(
                documentNumber: "SOL-\(String(format: "%05d", abs(pkg.id.hashValue) % 100_000))",
                description: "Solicitação de pagamento a fornecedor",
                requester: DeliveryPerson(name: "Pedro Almeida"),
                installments: [
                    DeliveryInstallment(number: 1, amount: pkg.paymentAmount / 2, dueDate: iso(daysFromNow: 5), status: "Pago"),
                    DeliveryInstallment(number: 2, amount: pkg.paymentAmount - pkg.paymentAmount / 2, dueDate: iso(daysFromNow: 35), status: "Pendente"),
                ])))
        }
    }

    private static func budgetData(for pkg: Package, rng: inout Seeded) -> BudgetData {
        let over = rng.int(0...2) == 0
        let total1 = 5_000_000, used1 = over ? 5_200_000 : 3_000_000
        let total2 = 8_000_000, used2 = 4_100_000
        let lines = [
            BudgetLine(id: "bl-\(pkg.id)-1", budgetPlanName: "Orçamento 2026",
                       entityName: "Despesas Operacionais", entityType: "managerialAccount",
                       totalBudgetAmount: total1, totalUsedAmount: used1,
                       packageContributionAmount: pkg.paymentAmount,
                       remainingAmount: total1 - used1,
                       percentageUsed: Double(used1) / Double(total1) * 100, isOverBudget: used1 > total1),
            BudgetLine(id: "bl-\(pkg.id)-2", budgetPlanName: "Orçamento 2026",
                       entityName: "Centro de Custo A", entityType: "costCenter",
                       totalBudgetAmount: total2, totalUsedAmount: used2,
                       packageContributionAmount: pkg.paymentAmount / 2,
                       remainingAmount: total2 - used2,
                       percentageUsed: Double(used2) / Double(total2) * 100, isOverBudget: false),
        ]
        return BudgetData(lines: lines, hasOverBudgetLines: lines.contains(where: \.isOverBudget))
    }

    // MARK: - Bank accounts (espelha bank-accounts.mock.ts)

    private struct BankSpec { let code: String; let name: String; let short: String }
    private static let banks: [BankSpec] = [
        .init(code: "341", name: "Itaú Unibanco S.A.", short: "Itaú"),
        .init(code: "237", name: "Banco Bradesco S.A.", short: "Bradesco"),
        .init(code: "001", name: "Banco do Brasil S.A.", short: "Banco do Brasil"),
        .init(code: "260", name: "Nu Pagamentos S.A.", short: "Nubank"),
        .init(code: "077", name: "Banco Inter S.A.", short: "Inter"),
        .init(code: "104", name: "Caixa Econômica Federal", short: "Caixa"),
        .init(code: "208", name: "Banco BTG Pactual S.A.", short: "BTG Pactual"),
    ]

    private static let accountNames = [
        "Conta Principal", "Folha de Pagamento", "Fornecedores",
        "Reserva Operacional", "Conta Obras", "Tributos", "Recebíveis",
    ]

    static let accounts: [BankAccount] = {
        banks.enumerated().map { index, bank in
            var rng = Seeded(UInt64(index) &* 131 &+ 7)
            let balance = rng.int(1_500_000...32_000_000)   // R$ 15k → R$ 320k
            let predicted = rng.int(200_000...4_500_000)
            let types: [BankAccountType] = [.checking, .savings, .payment]
            return BankAccount(
                id: "acc-\(String(format: "%03d", index + 1))",
                bankCode: bank.code,
                bankCodeStr: String(format: "%08d", Int(bank.code) ?? 0),
                branchCode: "\(rng.int(1000...9999))",
                accountNumber: "\(rng.int(10000...99999))",
                accountDigit: "\(rng.int(0...9))",
                accountType: types[index % types.count],
                name: accountNames[index % accountNames.count],
                taxId: organizations[index % organizations.count].taxId,
                pixKey: nil,
                isExternal: index >= banks.count - 1,
                organizationId: "org-\(index % organizations.count + 1)",
                organizationName: organizations[index % organizations.count].legalName,
                balance: balance,
                availableBalance: balance - rng.int(0...500_000),
                predictedExpenses: predicted,
                bank: BankInfo(code: bank.code, name: bank.name, shortName: bank.short, iconUrl: nil)
            )
        }
    }()

    static let accountListResponse: BankAccountListResponse = {
        let total = accounts.reduce(0) { $0 + $1.balance }
        let start = Date().adding(days: -30).isoString
        let end = Date().isoString
        return BankAccountListResponse(
            data: accounts,
            total: accounts.count,
            totalBalance: total,
            movements: MovementsSummary(
                period: .init(start: start, end: end),
                income: .init(total: 18_450_000, count: 34),
                expense: .init(total: 12_780_000, count: 58)
            )
        )
    }()

    /// Histórico de saldo total consolidado — um ponto por dia no intervalo, com leve drift
    /// (smooth, espelha o formato real do endpoint). Determinístico por intervalo.
    static func balanceHistory(range: BalanceHistoryRange) -> [BalanceHistoryPoint] {
        let total = accountListResponse.totalBalance
        let days: Int
        switch range {
        case .last30: days = 30
        case .last60: days = 60
        case .thisMonth: days = Calendar.current.component(.day, from: Date())
        case .thisYear: days = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 180
        }
        var rng = Seeded(UInt64(424242 &+ days))
        var value = max(2_000_000, total - rng.int(0...3_000_000))
        return (0...days).map { i in
            // random walk → smooth continuous line, ending near the current total
            let step = rng.int(-1_200_000...1_400_000)
            value = max(500_000, value + step)
            let balance = i == days ? total : value
            return BalanceHistoryPoint(date: Date().adding(days: -(days - i)).isoString, balance: balance)
        }
    }

    /// Transações recentes (para a conta selecionada / dashboard).
    static func recentTransactions(for accountId: String, count: Int = 8) -> [BankTransaction] {
        var rng = Seeded(UInt64(abs(accountId.hashValue)))
        let categories: [BankTransactionCategory] = [.pixOut, .pixIn, .tedOut, .payment, .transferIn, .fee, .deposit]
        let counterparties = supplierNames
        var running = rng.int(5_000_000...20_000_000)
        return (0..<count).map { i in
            let category = categories[rng.int(0...(categories.count - 1))]
            let credit = [BankTransactionCategory.pixIn, .transferIn, .deposit, .refund].contains(category)
            let amount = rng.int(50_000...3_500_000)
            running += credit ? amount : -amount
            return BankTransaction(
                id: "tx-\(accountId)-\(i)",
                accountId: accountId,
                type: credit ? .credit : .debit,
                category: category,
                amount: amount,
                balanceAfter: max(0, running),
                description: credit ? "Recebimento" : "Pagamento a fornecedor",
                counterpartyName: counterparties[rng.int(0...(counterparties.count - 1))],
                counterpartyTaxId: taxIds[rng.int(0...(taxIds.count - 1))],
                date: iso(daysFromNow: -i)
            )
        }
    }

    /// Transações recentes consolidadas (todas as contas), mais recentes primeiro — mirror do
    /// endpoint consolidado. Filtrável por `accountId` para o extrato do detalhe da conta.
    static let consolidatedRecentTransactions: [BankTransaction] = {
        accounts.flatMap { recentTransactions(for: $0.id, count: 8) }
            .sorted { $0.date > $1.date }
    }()

    /// Próximos pagamentos agendados — já ordenados ascendente pela data (espelha /packages/upcoming).
    static let upcomingPayments: [UpcomingPayment] = {
        var rng = Seeded(987_654)
        return (0..<7).map { i in
            let org = organizations[i % organizations.count]
            return UpcomingPayment(
                id: "up-\(i)",
                receiverName: supplierNames[rng.int(0...(supplierNames.count - 1))],
                paymentAmount: rng.int(80_000...2_800_000),
                paymentDate: iso(daysFromNow: (i + 1) * 3),
                status: "SCHEDULED",
                organizationName: org.legalName
            )
        }
    }()

    // MARK: - Purchase requests

    static let costCenters = [
        "Operações", "Marketing", "Tecnologia", "Administrativo",
        "Obras", "Comercial", "Recursos Humanos",
    ]

    static let requesters = ["Igor Saraiva", "Thomas Lima", "Ana Costa", "Bruno Dias", "Carla Mota"]

    /// Existing requests — distributed across types and statuses (mock for display).
    static let purchaseRequests: [PurchaseRequest] = {
        let titles: [(RequestType, String)] = [
            (.purchase, "Notebooks Dell Latitude"),
            (.payment, "Fornecedor de cimento"),
            (.reimbursement, "Viagem cliente — SP"),
            (.purchase, "Licenças de software"),
            (.payment, "Energia elétrica — Obra 2"),
            (.purchase, "Material de escritório"),
            (.reimbursement, "Almoço com cliente"),
            (.purchase, "Mobiliário sala reunião"),
            (.payment, "Internet fibra — Matriz"),
            (.reimbursement, "Uber — visitas técnicas"),
            (.purchase, "Equipamentos de segurança"),
            (.payment, "Manutenção predial"),
        ]
        let statuses: [RequestStatus] = [.requested, .pending, .approved]
        return titles.enumerated().map { index, item in
            var rng = Seeded(UInt64(index) &* 977 &+ 13)
            return PurchaseRequest(
                id: "req-\(String(format: "%03d", index + 1))",
                type: item.0,
                title: item.1,
                requester: requesters[index % requesters.count],
                costCenter: costCenters[index % costCenters.count],
                amountCents: rng.int(35_000...4_800_000),
                status: statuses[index % statuses.count],
                date: iso(daysFromNow: -(index * 2 + 1)),
                itemCount: item.0 == .purchase ? rng.int(1...6) : 1
            )
        }
    }()

    /// Projects/sites that can consume the requisition (mirrors the prototype).
    static let projects: [Project] = [
        Project(name: "Residencial Aurora — Torre 2", cnpj: "12.345.678/0001-90",
                address: "Rua das Acácias, 120 — Vila Madalena, São Paulo/SP"),
        Project(name: "Comercial Horizonte Offices", cnpj: "50.618.964/0001-76",
                address: "Av. Brigadeiro Faria Lima, 2800 — Itaim Bibi, São Paulo/SP"),
        Project(name: "Condomínio Vila Verde — Fase 1", cnpj: "40.733.212/0001-45",
                address: "Estrada do Campo Limpo, 5400 — Campo Limpo, São Paulo/SP"),
    ]

    /// Purchase catalog (construction materials/services/equipment).
    static let catalog: [CatalogItem] = [
        CatalogItem(name: "Cimento CP-II 50kg", code: "CIM-001", category: "Material", unit: "saco", unitCents: 3_590),
        CatalogItem(name: "Vergalhão CA-50 10mm 12m", code: "ACO-010", category: "Material", unit: "barra", unitCents: 5_480),
        CatalogItem(name: "Vergalhão CA-50 8mm 12m", code: "ACO-008", category: "Material", unit: "barra", unitCents: 3_920),
        CatalogItem(name: "Areia média lavada", code: "ARE-001", category: "Material", unit: "m³", unitCents: 14_500),
        CatalogItem(name: "Brita 1", code: "BRI-001", category: "Material", unit: "m³", unitCents: 13_800),
        CatalogItem(name: "Bloco cerâmico 9x19x39", code: "BLO-009", category: "Material", unit: "un", unitCents: 289),
        CatalogItem(name: "Bloco de concreto estrutural 14x19x39", code: "BLO-014", category: "Material", unit: "un", unitCents: 465),
        CatalogItem(name: "Argamassa de assentamento 20kg", code: "ARG-001", category: "Material", unit: "saco", unitCents: 1_450),
        CatalogItem(name: "Argamassa colante AC-II 20kg", code: "ARG-002", category: "Material", unit: "saco", unitCents: 2_790),
        CatalogItem(name: "Locação de betoneira 400L", code: "SER-001", category: "Serviço", unit: "diária", unitCents: 12_000),
        CatalogItem(name: "Mão de obra — pedreiro", code: "SER-010", category: "Serviço", unit: "diária", unitCents: 25_000),
        CatalogItem(name: "Andaime tubular (módulo)", code: "EQP-001", category: "Equipamento", unit: "un", unitCents: 8_900),
        CatalogItem(name: "Escora metálica 3m", code: "EQP-004", category: "Equipamento", unit: "un", unitCents: 4_200),
    ]
}
