import CoreLocation
import Foundation
import Observation

/// Máquina de estados do fluxo de pagamento da Carteira — espelha o apps/wallet-pwa:
/// entrada → decode (DICT / EMV / boleto) → portão de localização → revisão → intent →
/// (duplicado) → PIN → pay → confirmação (evento) → resultado.
/// Todo o transacional passa pelo `WalletRepository` (mock com fixtures de contrato hoje;
/// `LiveWalletRepository` depois, sem mudar esta store).
@MainActor
@Observable
final class WalletPaymentFlowStore {
    let entry: WalletPaymentEntry
    let wallet: Wallet
    /// Scanner como primeiro passo (boleto vindo de "Escanear código de barras").
    let preferScanner: Bool
    private let location: LocationService
    private let repo: WalletRepository

    /// Chamado quando um pagamento termina (sucesso/demorado/falha) para recarregar o extrato.
    var onPaymentFinished: (@MainActor () async -> Void)?

    var step: WalletPaymentStep = .input
    var amountInput: String = ""     // texto digitado no campo Valor
    var paymentDescription: String = ""
    var rawInput: String = ""        // chave / código colado / linha digitável
    var errorMessage: String?
    var locationDenied = false
    var coordinate: CLLocationCoordinate2D?
    private(set) var isSubmitting = false

    // MARK: Dados de contrato (shapes reais — vão no intent)

    private(set) var keyDetails: PixKeyDetails?
    private(set) var qrDetails: QrCodeDetails?
    private(set) var bankslip: BankslipCheck?
    private(set) var intent: WalletPaymentIntent?
    private(set) var duplicatePackage: WalletDuplicatePackage?
    private(set) var paidPayment: WalletPayment?

    // MARK: Projeções de exibição (as views continuam usando PixRecipient/BoletoInfo)

    var recipient: PixRecipient? {
        guard let k = keyDetails else { return nil }
        return PixRecipient(
            name: k.displayName.capitalizedNamePtBr,
            taxId: k.displayTaxId.cnpjOrCpfMasked,
            bankName: k.bankName ?? "—",
            keyValue: k.key ?? rawInput,
            keyTypeLabel: k.type?.label ?? PixKeyNormalizer.typeLabel(k.key ?? rawInput)
        )
    }

    var boleto: BoletoInfo? {
        guard let b = bankslip else { return nil }
        return BoletoInfo(
            assignor: (b.registerData?.recipient ?? b.assignor ?? "—").capitalizedNamePtBr,
            digitableLine: b.digitable,
            dueDate: b.registerData?.payDueDate ?? b.dueDate,
            originalAmount: b.registerData?.originalValue ?? b.value,
            fineAmount: b.registerData?.fineValueCalculated ?? b.fineAmount ?? 0,
            interestAmount: b.registerData?.interestValueCalculated ?? b.interestAmount ?? 0,
            discountAmount: b.registerData?.discountValue ?? 0
        )
    }

    // MARK: Valor

    /// Valor digitado convertido para cents.
    var amount: Int { Self.cents(from: amountInput) }

    /// QR com valor fixo ou boleto sem `allowChangeValue` → valor travado (RN-11/RN-13).
    var isAmountLocked: Bool {
        if let qr = qrDetails, qr.hasFixedAmount { return true }
        if let b = bankslip { return !b.allowsChangeValue }
        return false
    }

    /// Valor a pagar: QR fixo > boleto travado > valor digitado.
    var payableAmount: Int {
        if let qr = qrDetails, qr.hasFixedAmount { return qr.transactionAmount }
        if let b = bankslip, !b.allowsChangeValue { return b.finalAmount }
        return amount
    }

    /// Teto por pagamento na plataforma (R$ 6.000,00), espelha o DTO de intent da wallet-pwa.
    static let maxPayable = 6_000_00

    /// Excede o limite disponível da carteira?
    var exceedsLimit: Bool { payableAmount > wallet.availableLimit }

    var canSubmitInput: Bool {
        let raw = rawInput.trimmingCharacters(in: .whitespaces)
        switch entry {
        case .boleto: return raw.count >= 10
        case .pixKey: return !raw.isEmpty && amount > 0
        case .pixCopyPaste, .pixQR: return !raw.isEmpty
        }
    }

    /// Timeout até a tela "demorado" (RN-16: 30 s; override de demo via env, só em DEBUG).
    static var delayedTimeout: TimeInterval {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["PAGGO_WALLET_DELAYED_SECONDS"],
           let secs = TimeInterval(raw), secs > 0 { return secs }
        #endif
        return 30
    }

    /// Converte o texto do campo em cents sem usar Double (evita erro de ponto flutuante) e de forma
    /// independente de locale: o último separador (`,` ou `.`) é o decimal; o resto são milhares.
    static func cents(from text: String) -> Int {
        let chars = Array(text.filter { $0.isNumber || $0 == "," || $0 == "." })
        guard !chars.isEmpty else { return 0 }
        if let lastSep = chars.lastIndex(where: { $0 == "," || $0 == "." }) {
            let intDigits = String(chars[..<lastSep]).filter(\.isNumber)
            let fracDigits = String((String(chars[(lastSep + 1)...]).filter(\.isNumber) + "00").prefix(2))
            return (Int(intDigits) ?? 0) * 100 + (Int(fracDigits) ?? 0)
        }
        // Sem separador: trata os dígitos como reais inteiros.
        return (Int(String(chars)) ?? 0) * 100
    }

    /// Cents → texto editável no campo Valor ("1004,86").
    static func text(fromCents cents: Int) -> String {
        String(format: "%d,%02d", cents / 100, cents % 100)
    }

    init(entry: WalletPaymentEntry, wallet: Wallet, location: LocationService,
         preferScanner: Bool = false,
         repo: WalletRepository = ServiceContainer.shared.walletRepository) {
        self.entry = entry
        self.wallet = wallet
        self.location = location
        self.preferScanner = preferScanner
        self.repo = repo
        seedDebugStepIfNeeded()
    }

    // MARK: Steps

    /// INPUT → decode via repository (RN-12/RN-13) → portão de localização (RN-10) → REVIEW.
    func submitInput() async {
        guard !isSubmitting else { return }   // evita reentrância (duplo toque em "Continuar")
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil
        let raw = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch entry {
            case .pixKey:
                if PixKeyNormalizer.looksLikeEmv(raw) {
                    errorMessage = "Você informou um código Pix Copia e Cola — use a opção Pix Copia e Cola para este pagamento."
                    return
                }
                guard raw.count > 3 else {
                    errorMessage = "A chave digitada deve ter mais de 3 caracteres."
                    return
                }
                keyDetails = try await repo.dictLookup(walletId: wallet.id,
                                                       pixKey: PixKeyNormalizer.normalize(raw))
            case .pixCopyPaste, .pixQR:
                let result = try await repo.decodeEmv(walletId: wallet.id, emv: raw)
                keyDetails = result.key
                qrDetails = result.qrCode
                if result.qrCode.hasFixedAmount {
                    amountInput = Self.text(fromCents: result.qrCode.transactionAmount)
                }
            case .boleto:
                let check = try await repo.checkBankslip(walletId: wallet.id, digitable: raw)
                guard check.payable else {
                    errorMessage = WalletError.bankslipNotPayable(nil).userMessage
                    return
                }
                bankslip = check
                amountInput = Self.text(fromCents: check.finalAmount)
            }
            await gateLocationThenReview()
        } catch let error as WalletError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Não foi possível obter as informações do pagamento. Tente novamente."
        }
    }

    private func gateLocationThenReview() async {
        step = .locating
        locationDenied = false
        let coord = await location.requireLocation()
        if let coord {
            coordinate = coord
            step = .review
        } else {
            locationDenied = true
            step = .input
            errorMessage = "Precisamos da sua localização para autorizar o pagamento."
        }
    }

    /// REVIEW → cria o intent (RN-11) → DUPLICATED (RN-14) ou autorização.
    func confirmReview() async {
        guard !isSubmitting else { return }
        guard payableAmount > 0 else {
            errorMessage = "Informe um valor antes de continuar."
            return
        }
        if let b = bankslip, b.allowsChangeValue {
            if let min = b.registerData?.minValue ?? b.minValue, payableAmount < min {
                errorMessage = "O valor mínimo deste boleto é \(min.currencyFromCents())."
                return
            }
            if let max = b.registerData?.maxValue ?? b.maxValue, payableAmount > max {
                errorMessage = "O valor máximo deste boleto é \(max.currencyFromCents())."
                return
            }
        }
        if payableAmount > Self.maxPayable {
            errorMessage = "O valor máximo por pagamento é \(Self.maxPayable.currencyFromCents())."
            return
        }
        if exceedsLimit || payableAmount > wallet.maximumLimit {
            errorMessage = "Valor acima do limite disponível do cartão."
            return
        }
        errorMessage = nil

        // RN-10: localização obrigatória antes do intent.
        guard let coord = coordinate else {
            await gateLocationThenReview()
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let draft = WalletPaymentIntentDraft(
                pixKey: keyDetails?.key,
                paymentMethod: paymentMethod,
                amount: payableAmount,
                lat: coord.latitude,
                lng: coord.longitude,
                keyDetails: keyDetails,
                qrCodeDetails: qrDetails,
                digitable: bankslip?.digitable,
                description: paymentDescription.isEmpty ? nil : paymentDescription,
                deviceInfo: ["language": Locale.current.identifier, "platform": "iOS"]
            )
            let created = try await repo.createIntent(walletId: wallet.id, draft: draft)
            intent = created
            if let duplicatedId = created.potentialDuplicatedPackageId {
                duplicatePackage = try? await repo.duplicatePackage(id: duplicatedId)
                step = .duplicated
            } else {
                proceedToAuthorization()
            }
        } catch let error as WalletError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Não foi possível verificar as informações do pagamento. Tente novamente."
        }
    }

    private var paymentMethod: WalletPaymentMethod {
        switch entry {
        case .pixKey: return .key
        case .pixCopyPaste, .pixQR: return .qrCode
        case .boleto: return .barcode
        }
    }

    /// DUPLICATED → autorização (usuário decidiu pagar mesmo assim).
    func confirmDuplicate() { proceedToAuthorization() }

    /// Carteira com PIN → passo de PIN (RN-15); sem PIN → paga direto (igual à wallet-pwa).
    private func proceedToAuthorization() {
        if wallet.hasPin {
            step = .pin
        } else {
            Task { await executePayment() }
        }
    }

    /// Valida o PIN no servidor (RN-15). `false` → o sheet mostra erro e limpa.
    func confirmPin(_ pin: String) async -> Bool {
        do {
            try await repo.validatePin(walletId: wallet.id, pin: pin)
        } catch {
            return false
        }
        await executePayment()
        return true
    }

    /// pay → corrida: evento de confirmação vs timeout (RN-16). `insufficientBalance` → volta à revisão.
    private func executePayment() async {
        guard let intent else {
            step = .review
            errorMessage = "Não foi possível seguir com o pagamento. Tente novamente."
            return
        }
        // RN-10: localização também antes do pay.
        if coordinate == nil {
            let coord = await location.requireLocation()
            guard let coord else {
                locationDenied = true
                step = .input
                errorMessage = "Precisamos da sua localização para autorizar o pagamento."
                return
            }
            coordinate = coord
        }
        step = .processing
        do {
            let payment = try await repo.pay(walletId: wallet.id, intentId: intent.id)
            paidPayment = payment

            let repo = self.repo
            let walletId = wallet.id
            let paymentId = payment.id
            let timeout = Self.delayedTimeout
            // Corrida: quem terminar primeiro decide — evento (sucesso/falha) ou timer (demorado).
            let event = await withTaskGroup(of: WalletPaymentEvent?.self) { group in
                group.addTask {
                    try? await repo.awaitConfirmation(walletId: walletId, paymentId: paymentId)
                }
                group.addTask {
                    try? await Task.sleep(for: .seconds(timeout))
                    return nil
                }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
            if let event {
                step = event.confirmed ? .success : .failed
            } else {
                step = .delayed   // não é falha — o pagamento segue processando (RN-16)
            }
            await onPaymentFinished?()
        } catch let error as WalletError where error == .insufficientBalance {
            step = .review
            errorMessage = error.userMessage
        } catch let error as WalletError {
            step = .review
            errorMessage = error.userMessage
        } catch {
            step = .failed
            await onPaymentFinished?()
        }
    }

    func backToReview() {
        step = .review
        errorMessage = nil
    }

    // MARK: Debug

    /// Debug: PAGGO_WALLET_PAY_STEP=review|duplicated|pin|success|delayed|failed semeia o fluxo
    /// num passo, com dados vindos dos **fixtures de contrato** (verificação de UI).
    private func seedDebugStepIfNeeded() {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment["PAGGO_WALLET_PAY_STEP"] else { return }
        if entry == .boleto {
            rawInput = "34191757283496055252850434570003700000000000000"
            bankslip = try? WalletFixtureLoader.load("bankslip-clean")
            if let b = bankslip { amountInput = Self.text(fromCents: b.finalAmount) }
        } else {
            rawInput = "pix@paggo.ai"
            keyDetails = try? WalletFixtureLoader.load("pix-dict")
            amountInput = "152,90"
        }
        if raw == "duplicated" {
            duplicatePackage = try? WalletFixtureLoader.load("package-duplicate")
        }
        switch raw {
        case "review": step = .review
        case "duplicated": step = .duplicated
        case "pin": step = .pin
        case "success": step = .success
        case "delayed": step = .delayed
        case "failed": step = .failed
        default: break
        }
        #endif
    }
}
