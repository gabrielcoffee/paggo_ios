import Foundation

/// Mock da Carteira Digital — responde com fixtures JSON no shape real dos contratos e mantém
/// estado em memória (pagamento novo entra no extrato, pendência resolve de verdade).
/// O roteiro de demo é determinístico (docs/WALLET-DEMO-SCRIPT.md):
/// - chave contendo "naoexiste" → Chave Pix não encontrada
/// - EMV contendo "fixo" → QR com valor fixo (não editável)
/// - boleto "999…" → não pagável · "23793…" → multa+juros · "2370…" → valor editável · demais → limpo
/// - valor R$ 777,77 → duplicado · R$ 999,99 → saldo insuficiente · R$ 444,44 → falha · R$ 555,55 → demorado
actor MockWalletRepository: WalletRepository {
    private enum Outcome { case success, failed, delayed }

    private var wallets: [Wallet] = []
    private var paymentsByWallet: [String: [WalletPayment]] = [:]
    private var intents: [String: WalletPaymentIntent] = [:]
    private var lastBankslipByWallet: [String: BankslipCheck] = [:]
    private var outcomeByPayment: [String: Outcome] = [:]
    private var attachmentsByPayment: [String: [WalletPaymentAttachment]] = [:]
    private var allocationsByPayment: [String: [WalletPaymentAllocation]] = [:]
    private var seeded = false

    // MARK: Seed & helpers

    private func seedIfNeeded() throws {
        guard !seeded else { return }
        var loaded: [Wallet] = try WalletFixtureLoader.load("wallets")
        // `balance` vem de outro endpoint no contrato; o mock injeta os saldos aqui.
        let balances = ["wal-1": 3_200_00, "wal-2": 280_00, "wal-3": 0]
        for i in loaded.indices { loaded[i].balance = balances[loaded[i].id] ?? 0 }
        wallets = loaded
        paymentsByWallet = WalletMockData.seedPayments
        seeded = true
    }

    private func simulateLatency() async {
        try? await Task.sleep(for: .milliseconds(Int.random(in: 350...800)))
    }

    private func mutatePayment(walletId: String, paymentId: String,
                               _ mutate: (inout WalletPayment) -> Void) {
        guard var list = paymentsByWallet[walletId],
              let idx = list.firstIndex(where: { $0.id == paymentId }) else { return }
        mutate(&list[idx])
        paymentsByWallet[walletId] = list
    }

    // MARK: Exibição

    func wallets() async throws -> [Wallet] {
        await simulateLatency()
        try seedIfNeeded()
        return wallets
    }

    func balance(walletId: String) async throws -> Int {
        await simulateLatency()
        try seedIfNeeded()
        return wallets.first { $0.id == walletId }?.balance ?? 0
    }

    func payments(walletId: String) async throws -> [WalletPayment] {
        await simulateLatency()
        try seedIfNeeded()
        return paymentsByWallet[walletId] ?? []
    }

    func paymentDetail(walletId: String, paymentId: String) async throws -> WalletPaymentDetail {
        await simulateLatency()
        try seedIfNeeded()
        guard let payment = paymentsByWallet[walletId]?.first(where: { $0.id == paymentId }) else {
            throw WalletError.generic("Pagamento não encontrado.")
        }
        let payerName = wallets.first { $0.id == walletId }?.organizationName
        return WalletMockData.detail(for: payment, payerName: payerName)
    }

    // MARK: Pré-intent (decode)

    func dictLookup(walletId: String, pixKey: String) async throws -> PixKeyDetails {
        await simulateLatency()
        if pixKey.lowercased().contains("naoexiste") { throw WalletError.pixKeyNotFound }
        var details: PixKeyDetails = try WalletFixtureLoader.load("pix-dict")
        details.key = pixKey
        return details
    }

    func decodeEmv(walletId: String, emv: String) async throws -> PixDecodeResult {
        await simulateLatency()
        let lowered = emv.lowercased()
        if lowered.contains("invalido") { throw WalletError.invalidQrCode }
        let fixture = lowered.contains("fixo") ? "pix-decode-fixed" : "pix-decode-static"
        return try WalletFixtureLoader.load(fixture)
    }

    func checkBankslip(walletId: String, digitable: String) async throws -> BankslipCheck {
        await simulateLatency()
        let digits = digitable.filter(\.isNumber)
        let fixture: String
        if digits.hasPrefix("999") { fixture = "bankslip-unpayable" }
        else if digits.hasPrefix("23793") { fixture = "bankslip-fine" }
        else if digits.hasPrefix("2370") { fixture = "bankslip-editable" }
        else { fixture = "bankslip-clean" }
        var check: BankslipCheck = try WalletFixtureLoader.load(fixture)
        if digits.count >= 40 { check.digitable = digits }
        lastBankslipByWallet[walletId] = check
        return check
    }

    // MARK: Intent + pagamento

    func createIntent(walletId: String, draft: WalletPaymentIntentDraft) async throws -> WalletPaymentIntent {
        await simulateLatency()
        let forceDuplicate = ProcessInfo.processInfo.environment["PAGGO_WALLET_PAY_DUPLICATE"] == "1"
        let isDuplicate = forceDuplicate || draft.amount == 777_77
        var intent: WalletPaymentIntent =
            try WalletFixtureLoader.load(isDuplicate ? "intent-duplicated" : "intent-plain")
        intent = WalletPaymentIntent(
            id: UUID().uuidString,
            paymentMethod: draft.paymentMethod,
            amount: draft.amount,
            pixKey: draft.pixKey,
            keyDetails: draft.keyDetails,
            qrCodeDetails: draft.qrCodeDetails,
            potentialDuplicatedPackageId: intent.potentialDuplicatedPackageId,
            createdAt: WalletMockData.isoNow()
        )
        intents[intent.id] = intent
        return intent
    }

    func validatePin(walletId: String, pin: String) async throws {
        await simulateLatency()
        try seedIfNeeded()
        let expected = wallets.first { $0.id == walletId }?
            .walletUsers.compactMap(\.pin).first { !$0.isEmpty }
        guard expected == nil || expected == pin else { throw WalletError.invalidPin }
    }

    func pay(walletId: String, intentId: String) async throws -> WalletPayment {
        await simulateLatency()
        try seedIfNeeded()
        guard let intent = intents[intentId] else {
            throw WalletError.generic("Intent não encontrado.")
        }
        let amount = intent.amount ?? 0
        if amount == 999_99 { throw WalletError.insufficientBalance }

        let outcome: Outcome
        switch ProcessInfo.processInfo.environment["PAGGO_WALLET_PAY_RESULT"] {
        case "failed": outcome = .failed
        case "delayed": outcome = .delayed
        default:
            if amount == 444_44 { outcome = .failed }
            else if amount == 555_55 { outcome = .delayed }
            else { outcome = .success }
        }

        let bankslip = intent.paymentMethod == .barcode ? lastBankslipByWallet[walletId] : nil
        let receiverName = [intent.keyDetails?.displayName,
                            bankslip?.registerData?.recipient,
                            bankslip?.assignor]
            .compactMap { $0 }.first { !$0.isEmpty }?.capitalizedNamePtBr ?? "Recebedor"
        let receiverTaxId = [intent.keyDetails?.displayTaxId,
                             bankslip?.registerData?.documentRecipient]
            .compactMap { $0 }.first { !$0.isEmpty } ?? ""

        let payment = WalletPayment(
            id: "wp-\(UUID().uuidString.prefix(8))",
            amount: amount,
            receiverName: receiverName,
            receiverTaxId: receiverTaxId,
            method: intent.paymentMethod ?? .key,
            status: .processing,
            createdAt: WalletMockData.isoNow(),
            released: false,
            hasAttachments: false,
            allocationPending: true,
            intentId: intent.id
        )
        paymentsByWallet[walletId, default: []].insert(payment, at: 0)
        outcomeByPayment[payment.id] = outcome

        // Consome o limite e o saldo lastro da carteira (efeito visível na demo).
        if let idx = wallets.firstIndex(where: { $0.id == walletId }) {
            wallets[idx].limit = max(0, wallets[idx].limit - amount)
            wallets[idx].balance = max(0, wallets[idx].balance - amount)
        }
        return payment
    }

    func awaitConfirmation(walletId: String, paymentId: String) async throws -> WalletPaymentEvent {
        let outcome = outcomeByPayment[paymentId] ?? .success
        switch outcome {
        case .delayed:
            // Sem evento — o timeout de 30 s da store vence e mostra a tela "demorado" (RN-16).
            try await Task.sleep(for: .seconds(3_600))
            return WalletPaymentEvent(id: paymentId, confirmed: true, packageId: nil)
        case .success:
            try? await Task.sleep(for: .seconds(1.6))
            mutatePayment(walletId: walletId, paymentId: paymentId) {
                $0.status = .confirmed
                $0.released = true
            }
            return WalletPaymentEvent(id: paymentId, confirmed: true, packageId: "pkg-\(paymentId)")
        case .failed:
            try? await Task.sleep(for: .seconds(1.6))
            mutatePayment(walletId: walletId, paymentId: paymentId) { $0.status = .failed }
            return WalletPaymentEvent(id: paymentId, confirmed: false, packageId: nil)
        }
    }

    func duplicatePackage(id: String) async throws -> WalletDuplicatePackage {
        await simulateLatency()
        return try WalletFixtureLoader.load("package-duplicate")
    }

    // MARK: Enriquecimento pós-pagamento

    func updateDescription(walletId: String, paymentId: String, description: String) async throws {
        await simulateLatency()
        mutatePayment(walletId: walletId, paymentId: paymentId) { $0.description = description }
    }

    func attachments(walletId: String, paymentId: String) async throws -> [WalletPaymentAttachment] {
        await simulateLatency()
        return attachmentsByPayment[paymentId] ?? []
    }

    func addAttachment(walletId: String, paymentId: String, fileName: String,
                       data: Data) async throws -> WalletPaymentAttachment {
        await simulateLatency()
        let dir = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask,
                 appropriateFor: nil, create: true)
            .appendingPathComponent("WalletMockAttachments", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let url = dir.appendingPathComponent("\(id)-\(fileName)")
        try data.write(to: url)

        let attachment = WalletPaymentAttachment(id: id, fileName: fileName,
                                                 createdAt: WalletMockData.isoNow(), localURL: url)
        attachmentsByPayment[paymentId, default: []].append(attachment)
        mutatePayment(walletId: walletId, paymentId: paymentId) { $0.hasAttachments = true }
        return attachment
    }

    func allocations(walletId: String, paymentId: String) async throws -> [WalletPaymentAllocation] {
        await simulateLatency()
        return allocationsByPayment[paymentId] ?? []
    }

    func setAllocations(walletId: String, paymentId: String,
                        _ allocations: [WalletPaymentAllocation]) async throws {
        await simulateLatency()
        allocationsByPayment[paymentId] = allocations
        let total = allocations.reduce(0) { $0 + $1.percentage }
        mutatePayment(walletId: walletId, paymentId: paymentId) { $0.allocationPending = total != 100 }
    }

    func projects() async throws -> [AllocationOption] {
        await simulateLatency()
        return try WalletFixtureLoader.load("configs-projects")
    }

    func managerials() async throws -> [AllocationOption] {
        await simulateLatency()
        return try WalletFixtureLoader.load("configs-managerials")
    }

    func invalidate() async {}
}
