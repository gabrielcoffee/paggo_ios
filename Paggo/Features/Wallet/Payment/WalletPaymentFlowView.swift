import SwiftUI

/// Fluxo de pagamento da Carteira (Pix por chave / copia e cola / QR / boleto).
/// Máquina de estados em `WalletPaymentFlowStore`: entrada → localização → revisão →
/// (duplicado) → PIN → processando → resultado. Apresentado em fullScreenCover.
struct WalletPaymentFlowView: View {
    let entry: WalletPaymentEntry
    var preferScanner = false
    @Environment(WalletStore.self) private var wallet
    @Environment(\.dismiss) private var dismiss

    @State private var location = LocationService()
    @State private var store: WalletPaymentFlowStore?

    var body: some View {
        NavigationStack {
            Group {
                if let store {
                    stepView(store)
                } else {
                    ProgressView().tint(Theme.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .screenBackground()
            .navigationTitle(entry.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store?.step.isResult != true {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancelar") { dismiss() }.tint(Theme.textSecondary)
                    }
                }
            }
        }
        .task { await wallet.load() }
        // Cria o store assim que a carteira ativa estiver disponível (evita corrida com o load inicial).
        .onChange(of: wallet.currentWallet?.id, initial: true) { _, _ in
            if store == nil, let current = wallet.currentWallet {
                let flow = WalletPaymentFlowStore(entry: entry, wallet: current,
                                                  location: location, preferScanner: preferScanner)
                flow.onPaymentFinished = { await wallet.refreshCurrentPayments() }
                store = flow
            }
        }
    }

    @ViewBuilder private func stepView(_ store: WalletPaymentFlowStore) -> some View {
        switch store.step {
        case .input: WalletPaymentInputView(store: store)
        case .locating: WalletPaymentBusyView(message: "Obtendo sua localização…")
        case .review: WalletPaymentReviewView(store: store)
        case .duplicated: WalletPaymentDuplicateView(store: store)
        case .pin:
            WalletPinSheet(
                onConfirm: { pin in await store.confirmPin(pin) },
                onCancel: { store.backToReview() }
            )
        case .processing: WalletPaymentProcessingView()
        case .success, .delayed, .failed:
            WalletPaymentResultView(store: store, onDone: { dismiss() })
        }
    }
}

private extension WalletPaymentStep {
    var isResult: Bool { self == .success || self == .delayed || self == .failed }
}

// MARK: - Busy (locating / processing)

struct WalletPaymentBusyView: View {
    let message: String
    var body: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView().tint(Theme.accent).scaleEffect(1.3)
            Text(message).font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Processando com a animação Lottie do wallet-pwa (loop; spinner com Reduce Motion).
struct WalletPaymentProcessingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.lg) {
            if reduceMotion {
                ProgressView().tint(Theme.accent).scaleEffect(1.3)
            } else {
                BrandLottieView(name: "WalletPaymentLoading", loopMode: .loop)
                    .frame(width: 120, height: 120)
            }
            Text("Processando pagamento…")
                .font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Input

struct WalletPaymentInputView: View {
    @Bindable var store: WalletPaymentFlowStore

    @State private var showScanner = false

    /// Câmera como passo de entrada: QR Pix sempre; boleto quando veio de "Escanear".
    private var scannerIsPrimary: Bool {
        guard WalletScannerView.isSupported, store.errorMessage == nil else { return false }
        switch store.entry {
        case .pixQR: return true
        case .boleto: return store.preferScanner
        default: return false
        }
    }

    var body: some View {
        if scannerIsPrimary {
            WalletScannerView(mode: store.entry == .boleto ? .boletoBarcode : .pixQR) { code in
                store.rawInput = code
                Task { await store.submitInput() }
            }
        } else {
            form
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if store.entry == .pixQR {
                    Text("Câmera indisponível — cole o código Pix abaixo.")
                        .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
                }
                if store.entry.isPix {
                    pixFields
                } else {
                    boletoFields
                }
                if let error = store.errorMessage {
                    locationHelp(error)
                }
            }
            .padding(Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                Button { Task { await store.submitInput() } } label: {
                    Text("Continuar").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(!store.canSubmitInput || store.isSubmitting)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            NavigationStack {
                WalletScannerView(mode: .boletoBarcode) { code in
                    showScanner = false
                    store.rawInput = code
                    Task { await store.submitInput() }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Fechar") { showScanner = false }.tint(.white)
                    }
                }
            }
        }
    }

    @ViewBuilder private var pixFields: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            fieldLabel(store.entry == .pixKey ? "Chave Pix" : "Código Pix (copia e cola)")
            HStack(spacing: Spacing.sm) {
                BrandTextField(store.entry == .pixKey ? "CPF/CNPJ, telefone, e-mail ou aleatória"
                                                      : "Cole o código Pix", text: $store.rawInput)
                if store.entry != .pixKey {
                    Button { paste() } label: { Image(systemName: "doc.on.clipboard") }
                        .buttonStyle(.plain).foregroundStyle(Theme.accent)
                }
            }
        }
        VStack(alignment: .leading, spacing: Spacing.sm) {
            fieldLabel("Valor")
            BrandTextField("0,00", text: $store.amountInput).keyboardType(.decimalPad)
        }
        availableHint
    }

    @ViewBuilder private var boletoFields: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            fieldLabel("Linha digitável")
            HStack(spacing: Spacing.sm) {
                BrandTextField("Digite ou cole a linha digitável", text: $store.rawInput)
                    .keyboardType(.numbersAndPunctuation)
                Button { paste() } label: { Image(systemName: "doc.on.clipboard") }
                    .buttonStyle(.plain).foregroundStyle(Theme.accent)
            }
            Text("O valor será obtido automaticamente do boleto.")
                .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
            if WalletScannerView.isSupported {
                Button {
                    showScanner = true
                } label: {
                    Label("Escanear código de barras", systemImage: "barcode.viewfinder")
                        .font(.brand(.subheadline, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .padding(.top, Spacing.sm)
            }
        }
    }

    private var availableHint: some View {
        Text("Limite disponível: \(store.wallet.availableLimit.currencyFromCents())")
            .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
    }

    private func locationHelp(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(message, systemImage: "location.slash")
                .font(.brand(.caption)).foregroundStyle(Theme.negative)
            if store.locationDenied {
                Button("Abrir Ajustes") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.brand(.caption, weight: .semibold)).tint(Theme.accent)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.negative.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.brand(.caption2, weight: .medium)).tracking(0.6)
            .foregroundStyle(Theme.textTertiary)
    }

    private func paste() {
        if let s = UIPasteboard.general.string { store.rawInput = s }
    }
}

// MARK: - Review

struct WalletPaymentReviewView: View {
    @Bindable var store: WalletPaymentFlowStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                amountHero
                if let recipient = store.recipient { recipientCard(recipient) }
                if let boleto = store.boleto { boletoCard(boleto) }
                descriptionField
                if let error = store.errorMessage {
                    Text(error).font(.brand(.caption)).foregroundStyle(Theme.negative)
                }
            }
            .padding(Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                Button { Task { await store.confirmReview() } } label: {
                    Text("Confirmar pagamento").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(store.exceedsLimit || store.isSubmitting)
            }
        }
    }

    private var amountHero: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("VALOR A PAGAR")
                .font(.brand(.caption2, weight: .medium)).tracking(1).foregroundStyle(Theme.textTertiary)
            if store.isAmountLocked || !editsAmountInReview {
                Text(store.payableAmount.currencyFromCents())
                    .font(.heroNumber).monospacedDigit().foregroundStyle(Theme.textPrimary)
            } else {
                BrandTextField("0,00", text: $store.amountInput).keyboardType(.decimalPad)
            }
            if store.isAmountLocked {
                Text("Valor definido pelo recebedor")
                    .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
            }
            Text("Limite disponível: \(store.wallet.availableLimit.currencyFromCents())")
                .font(.brand(.caption)).foregroundStyle(store.exceedsLimit ? Theme.negative : Theme.textSecondary)
        }
    }

    /// Boleto com `allowChangeValue` permite editar o valor na revisão (entre min/max).
    private var editsAmountInReview: Bool {
        store.bankslip?.allowsChangeValue == true
    }

    private func recipientCard(_ r: PixRecipient) -> some View {
        DetailSection("Recebedor", systemImage: "arrow.down.left.circle") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                DetailInfoField(caption: "Nome", value: r.name)
                DetailInfoField(caption: "CPF/CNPJ", value: r.taxId)
                HStack(alignment: .top, spacing: Spacing.xl) {
                    DetailInfoField(caption: "Instituição", value: r.bankName)
                    DetailInfoField(caption: "Chave (\(r.keyTypeLabel))", value: r.keyValue)
                }
            }
        }
    }

    private func boletoCard(_ b: BoletoInfo) -> some View {
        DetailSection("Boleto", systemImage: "barcode") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                DetailInfoField(caption: "Beneficiário", value: b.assignor)
                HStack(alignment: .top, spacing: Spacing.xl) {
                    DetailInfoField(caption: "Valor original", value: b.originalAmount.currencyFromCents())
                    DetailInfoField(caption: "Vencimento", value: b.dueDate.map(DateText.full) ?? "—")
                }
                // RN-13: composição do valor final quando há encargos/desconto.
                if b.fineAmount > 0 || b.interestAmount > 0 || b.discountAmount > 0 {
                    HStack(alignment: .top, spacing: Spacing.xl) {
                        if b.fineAmount > 0 {
                            DetailInfoField(caption: "Multa", value: b.fineAmount.currencyFromCents())
                        }
                        if b.interestAmount > 0 {
                            DetailInfoField(caption: "Juros", value: b.interestAmount.currencyFromCents())
                        }
                        if b.discountAmount > 0 {
                            DetailInfoField(caption: "Desconto", value: "−" + b.discountAmount.currencyFromCents())
                        }
                    }
                    DetailInfoField(caption: "Valor final", value: b.finalAmount.currencyFromCents())
                }
            }
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("DESCRIÇÃO (OPCIONAL)")
                .font(.brand(.caption2, weight: .medium)).tracking(0.6).foregroundStyle(Theme.textTertiary)
            BrandTextField("Ex.: compra de materiais", text: $store.paymentDescription, axis: .vertical)
        }
    }
}

// MARK: - Duplicate warning

struct WalletPaymentDuplicateView: View {
    @Bindable var store: WalletPaymentFlowStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    TintedIcon(symbol: "exclamationmark.triangle.fill", tint: Theme.warning,
                               size: 44, symbolSize: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Risco de pagamento duplicado")
                            .font(.brand(.headline, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                        Text("Existe um pagamento semelhante a este no fluxo de pagamentos. Valide as informações e verifique se o pagamento atual é devido.")
                            .font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.lg))

                // Comparação lado a lado: o pagamento já existente na plataforma × este (RN-14).
                if let existing = store.duplicatePackage {
                    DetailSection("Pagamento existente", systemImage: "clock.arrow.circlepath") {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            DetailInfoField(caption: "Valor", value: existing.amount.currencyFromCents())
                            DetailInfoField(caption: "Recebedor",
                                            value: existing.receiverName?.capitalizedNamePtBr)
                            HStack(alignment: .top, spacing: Spacing.xl) {
                                DetailInfoField(caption: "Data",
                                                value: existing.paymentDate.map(DateText.full) ?? "—")
                                DetailInfoField(caption: "Método", value: existing.paymentMethod)
                            }
                            if let requestName = existing.requestName {
                                DetailInfoField(caption: "Origem", value: requestName)
                            }
                        }
                    }
                }

                DetailSection("Este pagamento", systemImage: "doc.text") {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        DetailInfoField(caption: "Valor", value: store.payableAmount.currencyFromCents())
                        DetailInfoField(caption: "Recebedor",
                                        value: store.recipient?.name ?? store.boleto?.assignor)
                        HStack(alignment: .top, spacing: Spacing.xl) {
                            DetailInfoField(caption: "Data", value: "Hoje")
                            DetailInfoField(caption: "Método", value: store.entry.title)
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                VStack(spacing: Spacing.sm) {
                    // Ação primária = cancelar (default seguro); pagar mesmo assim é secundária.
                    Button { store.backToReview() } label: {
                        Text("Voltar e revisar").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionStyle())
                    Button { store.confirmDuplicate() } label: {
                        Text("Pagar mesmo assim").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionStyle())
                }
            }
        }
    }
}

// MARK: - Result

struct WalletPaymentResultView: View {
    @Bindable var store: WalletPaymentFlowStore
    let onDone: () -> Void

    @Environment(WalletTabRouter.self) private var router: WalletTabRouter?

    private var spec: (symbol: String, tint: Color, animation: String, title: String, subtitle: String) {
        switch store.step {
        case .delayed:
            return ("clock.badge.exclamationmark", Theme.warning, "WalletPaymentDelayed",
                    "Isso está demorando mais do que o esperado.",
                    "Veja o status do pagamento na tela de Transações. Caso já tenha sido aprovado, você pode fechar esta tela.")
        case .failed:
            return ("xmark.circle.fill", Theme.negative, "WalletPaymentFailed",
                    "Pagamento falhou",
                    "Infelizmente seu pagamento não pôde ser processado nesse momento. Tente novamente mais tarde.")
        default:
            return ("checkmark.circle.fill", Theme.positive, "WalletPaymentSuccess",
                    "Pagamento enviado",
                    "Veja os detalhes do pagamento na tela de Transações.")
        }
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            BrandLottieView(name: spec.animation, loopMode: .playOnce,
                            reducedMotionFallback: (spec.symbol, spec.tint))
                .frame(width: 120, height: 120)
            VStack(spacing: Spacing.sm) {
                Text(spec.title).font(.brand(.title2, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary).multilineTextAlignment(.center)
                Text(spec.subtitle)
                    .font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if store.step != .failed {
                Text(store.payableAmount.currencyFromCents())
                    .font(.heroNumber).monospacedDigit().foregroundStyle(Theme.textPrimary)
                if let name = store.recipient?.name ?? store.boleto?.assignor {
                    Text("para \(name)").font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(Spacing.xl)
        .safeAreaInset(edge: .bottom) {
            resultActions
        }
    }

    /// Fecha o fluxo e pula para a aba Extrato (quando o router existir no environment).
    private func goToTransactions() {
        router?.selection = .extrato
        onDone()
    }

    private var resultActions: some View {
            BottomActionBar {
                VStack(spacing: Spacing.sm) {
                    switch store.step {
                    case .failed:
                        Button { store.backToReview() } label: {
                            Text("Tentar novamente").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionStyle())
                        Button { onDone() } label: { Text("Fechar").frame(maxWidth: .infinity) }
                            .buttonStyle(SecondaryActionStyle())
                    case .delayed:
                        Button { goToTransactions() } label: {
                            Text("Ver transações").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionStyle())
                    default:
                        // Contexto na hora (Ramp-inspired): leva direto ao extrato para
                        // anexar comprovante / alocar custos enquanto o gasto está fresco.
                        Button { goToTransactions() } label: {
                            Text("Adicionar comprovante agora").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionStyle())
                        Button { onDone() } label: { Text("Concluir").frame(maxWidth: .infinity) }
                            .buttonStyle(SecondaryActionStyle())
                    }
                }
            }
    }
}
