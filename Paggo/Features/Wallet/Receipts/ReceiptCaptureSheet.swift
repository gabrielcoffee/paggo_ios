import SwiftUI
import PhotosUI

/// Captura de recibo para uma compra de cartão: foto → OCR no aparelho → casamento no
/// servidor (auto quando só há 1 candidata; senão o usuário escolhe da lista).
struct ReceiptCaptureSheet: View {
    @Environment(CardStore.self) private var cardStore
    @Environment(\.dismiss) private var dismiss

    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var ocr: SmartReceipt.OCR?
    @State private var receipt: SmartReceipt?
    @State private var suggestions: [CardTransaction] = []
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    picker
                    if isProcessing {
                        HStack(spacing: Spacing.md) {
                            ProgressView().tint(Theme.accent)
                            Text("Lendo o recibo no aparelho…")
                                .font(.brand(.subheadline))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.lg)
                        .cardSurface()
                    }
                    if let ocr { ocrCard(ocr) }
                    if let receipt {
                        if receipt.status == .matched {
                            matchedCard
                        } else if !suggestions.isEmpty {
                            suggestionsCard
                        } else {
                            unmatchedCard
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .screenBackground()
            .navigationTitle("Adicionar recibo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task { await process(item) }
            }
        }
    }

    private var picker: some View {
        PhotosPicker(selection: $pickedItem, matching: .images) {
            VStack(spacing: Spacing.sm) {
                if let pickedImage {
                    Image(uiImage: pickedImage)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                } else {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 34)).foregroundStyle(Theme.accent)
                    Text("Escolher foto do recibo")
                        .font(.brand(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("A leitura acontece no seu aparelho — a foto não sai dele nesta etapa.")
                        .font(.brand(.caption))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.xl)
        }
        .cardSurface()
    }

    private func ocrCard(_ ocr: SmartReceipt.OCR) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Leitura do recibo")
            VStack(spacing: Spacing.sm) {
                ocrRow("Estabelecimento", ocr.merchantName ?? "—", ocr.confidence.merchantName)
                ocrRow("Data", ocr.date.map(DateText.full) ?? "—", ocr.confidence.date)
                ocrRow("Valor", ocr.amount?.currencyFromCents() ?? "—", ocr.confidence.amount)
            }
            .padding(Spacing.lg)
            .cardSurface()
        }
    }

    private func ocrRow(_ title: String, _ value: String, _ confidence: Double) -> some View {
        HStack {
            Text(title).font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textPrimary)
            if confidence > 0 {
                Text("\(Int(confidence * 100))%")
                    .font(.brand(.caption2, weight: .semibold))
                    .foregroundStyle(confidence >= 0.8 ? Theme.positive : Theme.warning)
            }
        }
    }

    private var matchedCard: some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: "checkmark.seal.fill", tint: Theme.positive)
            VStack(alignment: .leading, spacing: 2) {
                Text("Recibo casado automaticamente")
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Encontramos exatamente uma compra com esse valor e data.")
                    .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .cardSurface()
    }

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Escolha a compra deste recibo")
            VStack(spacing: 0) {
                ForEach(suggestions) { tx in
                    Button { Task { await match(tx) } } label: {
                        HStack(spacing: Spacing.md) {
                            TintedIcon(symbol: tx.merchant.category.symbol, tint: Theme.neutralIcon)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.merchant.name)
                                    .font(.brand(.subheadline, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(DateText.short(tx.authorizedAt))
                                    .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Text(tx.effectiveAmount.currencyFromCents())
                                .font(.brand(.subheadline, weight: .semibold)).monospacedDigit()
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    if tx.id != suggestions.last?.id { Divider().padding(.leading, 52) }
                }
            }
            .padding(.vertical, Spacing.xs)
            .cardSurface()
        }
    }

    private var unmatchedCard: some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: "questionmark.circle", tint: Theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nenhuma compra compatível")
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("O recibo ficou guardado; ele casa sozinho se a compra aparecer no feed.")
                    .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .cardSurface()
    }

    private func process(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer { isProcessing = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            ToastCenter.shared.show("Não foi possível abrir a foto.", style: .error)
            return
        }
        pickedImage = image
        let reading = await ReceiptOCR.read(image)
        ocr = reading
        do {
            let result = try await ServiceContainer.shared.receiptRepository
                .submit(url: "storage://receipts/local.jpg", ocr: reading)
            receipt = result.receipt
            suggestions = result.suggestions
            if result.receipt.status == .matched {
                await cardStore.load(force: true)
            }
        } catch {
            ToastCenter.shared.show("Não foi possível enviar o recibo.", style: .error)
        }
    }

    private func match(_ tx: CardTransaction) async {
        guard let receipt else { return }
        do {
            self.receipt = try await ServiceContainer.shared.receiptRepository
                .match(receiptId: receipt.id, transactionId: tx.id)
            suggestions = []
            await cardStore.load(force: true)
            ToastCenter.shared.show("Recibo anexado")
        } catch {
            ToastCenter.shared.show("Não foi possível casar o recibo.", style: .error)
        }
    }
}
