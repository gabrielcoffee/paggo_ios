import SwiftUI
import PhotosUI

/// Novo reembolso: foto do recibo alimenta o formulário via OCR (valor/data preenchem
/// sozinhos), política visível antes de enviar, sucesso com a previsão de pagamento.
struct ReimbursementFormView: View {
    @Environment(ReimbursementStore.self) private var store
    @Environment(BudgetStore.self) private var budgets
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var expenseDate = Date()
    @State private var category: MerchantCategory = .other
    @State private var budgetId: String?
    @State private var descriptionText = ""
    @State private var pickedItem: PhotosPickerItem?
    @State private var receiptImage: UIImage?
    @State private var isReadingReceipt = false
    @State private var policy: ResolvedPolicy?
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var submitted: Reimbursement?

    private var amountCents: Int { WalletPaymentFlowStore.cents(from: amountText) }
    private var receiptRequired: Bool { policy?.requiresReceipt(for: amountCents) ?? true }
    private var canSubmit: Bool {
        amountCents > 0
            && !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty
            && (!receiptRequired || receiptImage != nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let submitted {
                    successView(submitted)
                } else {
                    form
                }
            }
            .navigationTitle(submitted == nil ? "Novo reembolso" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if submitted == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                }
            }
        }
        .task {
            await budgets.load()
            policy = try? await ServiceContainer.shared.policyRepository.resolvedPolicy(budgetId: budgetId)
        }
        .onChange(of: budgetId) { _, new in
            Task {
                policy = try? await ServiceContainer.shared.policyRepository.resolvedPolicy(budgetId: new)
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task { await readReceipt(item) }
        }
    }

    // MARK: Form

    private var form: some View {
        Form {
            Section {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    if let receiptImage {
                        Image(uiImage: receiptImage)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .frame(maxWidth: .infinity)
                    } else {
                        Label(receiptRequired ? "Foto do recibo (obrigatória)"
                                              : "Foto do recibo",
                              systemImage: "doc.viewfinder")
                    }
                }
                if isReadingReceipt {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text("Lendo o recibo…").font(.brand(.caption))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            } footer: {
                if receiptImage != nil {
                    Text("Valor e data foram preenchidos pela leitura do recibo — confira antes de enviar.")
                }
            }

            Section("Despesa") {
                HStack {
                    Text("Valor")
                    Spacer()
                    TextField("R$ 0,00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                }
                DatePicker("Data", selection: $expenseDate, in: ...Date(), displayedComponents: .date)
                Picker("Categoria", selection: $category) {
                    ForEach(MerchantCategory.allCases) { c in
                        Label(c.label, systemImage: c.symbol).tag(c)
                    }
                }
                TextField("Descrição (ex.: almoço com cliente)", text: $descriptionText,
                          axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                Picker("Orçamento", selection: $budgetId) {
                    Text("Sem orçamento").tag(String?.none)
                    ForEach(budgets.overviews, id: \.membership.id) { pair in
                        Text(pair.budget.name).tag(String?.some(pair.budget.id))
                    }
                }
            } footer: {
                Text(budgetId == nil
                     ? "Sem orçamento, qualquer administrador pode aprovar."
                     : "O valor consome seu limite no orçamento quando o gestor aprovar.")
            }

            if let policy {
                Section {
                    if let auto = policy.autoApproveBelow, amountCents > 0, amountCents < auto,
                       receiptImage != nil {
                        Label("Abaixo de \(auto.currencyFromCents()) com recibo: aprova na hora",
                              systemImage: "checkmark.seal")
                            .font(.brand(.caption)).foregroundStyle(Theme.positive)
                    }
                    if policy.exceedsMax(amountCents) {
                        Label("Acima do teto por transação (\(policy.maxPerTransaction?.currencyFromCents() ?? "")) — segue pra aprovação com alerta",
                              systemImage: "exclamationmark.triangle")
                            .font(.brand(.caption)).foregroundStyle(Theme.warning)
                    }
                    if policy.blocks(category) {
                        Label("Categoria bloqueada pela política — segue pra aprovação com alerta",
                              systemImage: "exclamationmark.triangle")
                            .font(.brand(.caption)).foregroundStyle(Theme.warning)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).font(.brand(.subheadline)).foregroundStyle(Theme.negative)
                }
            }

            Section {
                Button(isSubmitting ? "Enviando…" : "Enviar reembolso") { submit() }
                    .disabled(!canSubmit || isSubmitting)
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: Sucesso (expectativa de prazo à vista)

    private func successView(_ item: Reimbursement) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: item.status == .approved ? "checkmark.seal.fill" : "paperplane.fill")
                .font(.system(size: 52))
                .foregroundStyle(item.status == .approved ? Theme.positive : Theme.accent)
            VStack(spacing: Spacing.sm) {
                Text(item.status == .approved ? "Aprovado na hora pela política"
                                              : "Reembolso enviado")
                    .font(.brand(.title3, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(item.status == .approved
                     ? "Pix de \(item.amount.currencyFromCents()) previsto até \(item.estimatedPaymentDate.map(DateText.full) ?? "—"), assim que o financeiro liberar."
                     : "O aprovador vai analisar; você acompanha o andamento em Reembolsos e recebe aviso da decisão.")
                    .font(.brand(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button("Concluir") { dismiss() }
                .buttonStyle(PrimaryActionStyle())
        }
        .padding(Spacing.xl)
        .screenBackground()
    }

    // MARK: Ações

    /// OCR preenche valor/data vazios — o funcionário só confere.
    private func readReceipt(_ item: PhotosPickerItem) async {
        isReadingReceipt = true
        defer { isReadingReceipt = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        receiptImage = image
        let ocr = await ReceiptOCR.read(image)
        if amountText.isEmpty, let cents = ocr.amount {
            amountText = WalletPaymentFlowStore.text(fromCents: cents)
        }
        if let dateText = ocr.date, let date = DateText.parse(dateText), date <= Date() {
            expenseDate = date
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                let item = try await store.submit(ReimbursementDraft(
                    amount: amountCents,
                    expenseDate: String(expenseDate.isoString.prefix(10)),
                    merchantCategory: category,
                    budgetId: budgetId,
                    description: descriptionText.trimmingCharacters(in: .whitespaces),
                    receiptURL: receiptImage != nil ? "storage://receipts/local.jpg" : nil
                ))
                submitted = item
            } catch {
                errorMessage = (error as? SpendError)?.userMessage
                    ?? "Não foi possível enviar o reembolso."
            }
            isSubmitting = false
        }
    }
}
