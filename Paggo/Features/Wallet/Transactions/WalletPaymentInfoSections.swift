import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Seções de enriquecimento pós-pagamento (espelham o payment-info do wallet-pwa):
/// descrição · anexos · alocações de custo. Salvar resolve as pendências do extrato (RN-20/21).
struct WalletPaymentInfoSections: View {
    @Bindable var store: WalletPaymentDetailStore

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            if store.hasPendencies { pendencyBanner }
            descriptionSection
            attachmentsSection
            allocationsSection
        }
        .task { await store.load() }
    }

    // MARK: Pendências

    private var pendencyBanner: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            TintedIcon(symbol: "exclamationmark.triangle.fill", tint: Theme.warning,
                       size: 36, symbolSize: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pendências a resolver")
                    .font(.brand(.subheadline, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text(pendencyText)
                    .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.lg))
    }

    private var pendencyText: String {
        var parts: [String] = []
        if !store.payment.hasAttachments { parts.append("anexe o comprovante ou nota") }
        if store.payment.allocationPending { parts.append("informe as alocações de custo") }
        return parts.joined(separator: " e ").capitalizedSentence
    }

    // MARK: Descrição

    private var descriptionSection: some View {
        DetailSection("Descrição", systemImage: "text.alignleft") {
            VStack(alignment: .trailing, spacing: Spacing.md) {
                BrandTextField("Ex.: compra de materiais para a obra",
                               text: $store.descriptionDraft, axis: .vertical)
                Button("Salvar descrição") { Task { await store.saveDescription() } }
                    .font(.brand(.subheadline, weight: .medium))
                    .buttonStyle(.plain).foregroundStyle(Theme.accent)
                    .disabled(store.isSaving ||
                              store.descriptionDraft == (store.payment.description ?? ""))
            }
        }
    }

    // MARK: Anexos

    private var attachmentsSection: some View {
        DetailSection("Anexos", systemImage: "paperclip") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(store.attachments) { attachment in
                    HStack(spacing: Spacing.sm) {
                        TintedIcon(symbol: "doc.fill", tint: Theme.neutralIcon, size: 30, symbolSize: 13)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(attachment.fileName)
                                .font(.brand(.subheadline)).foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text(DateText.full(attachment.createdAt))
                                .font(.brand(.caption2)).foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                if store.attachments.isEmpty {
                    Text("Nenhum anexo ainda.")
                        .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
                }
                WalletAttachmentPicker { fileName, data in
                    Task { await store.addAttachment(fileName: fileName, data: data) }
                }
            }
        }
    }

    // MARK: Alocações

    private var allocationsSection: some View {
        DetailSection("Alocações de custo", systemImage: "chart.pie") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach($store.allocationDrafts) { $allocation in
                    allocationRow($allocation)
                }
                HStack {
                    Button {
                        store.addAllocationRow()
                    } label: {
                        Label("Adicionar linha", systemImage: "plus.circle")
                            .font(.brand(.subheadline, weight: .medium))
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.accent)
                    Spacer()
                    Text("Total: \(store.allocationTotal)%")
                        .font(.brand(.subheadline, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(store.allocationTotal == 100 ? Theme.positive : Theme.negative)
                }
                Button {
                    Task { await store.saveAllocations() }
                } label: {
                    Text("Salvar alocações").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(!store.allocationsValid || store.isSaving)
            }
        }
    }

    private func allocationRow(_ allocation: Binding<WalletPaymentAllocation>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                optionPicker(placeholder: "Projeto", options: store.projects,
                             selection: allocation.projectId)
                optionPicker(placeholder: "Conta gerencial", options: store.managerials,
                             selection: allocation.managerialId)
            }
            HStack(spacing: Spacing.sm) {
                percentField(allocation.percentage)
                Spacer()
                if store.allocationDrafts.count > 1 {
                    Button {
                        store.removeAllocation(allocation.wrappedValue.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14)).foregroundStyle(Theme.negative)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Spacing.md)
        .background(Theme.surfaceHigh.opacity(0.4), in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private func optionPicker(placeholder: String, options: [AllocationOption],
                              selection: Binding<String?>) -> some View {
        Menu {
            Button("—") { selection.wrappedValue = nil }
            ForEach(options) { option in
                Button(option.name) { selection.wrappedValue = option.id }
            }
        } label: {
            HStack(spacing: 4) {
                Text(options.first { $0.id == selection.wrappedValue }?.name ?? placeholder)
                    .font(.brand(.caption))
                    .foregroundStyle(selection.wrappedValue == nil ? Theme.textTertiary : Theme.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, Spacing.sm).padding(.vertical, 6)
            .background(Theme.surfaceHigh, in: Capsule())
        }
    }

    private func percentField(_ percentage: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            TextField("0", value: percentage, format: .number)
                .keyboardType(.numberPad)
                .font(.brand(.subheadline, weight: .medium)).monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44)
                .multilineTextAlignment(.trailing)
            Text("%").font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, Spacing.sm).padding(.vertical, 6)
        .background(Theme.surfaceHigh, in: Capsule())
    }
}

// MARK: - Attachment picker (fotos / arquivo)

/// Botões de anexar: galeria de fotos (`PhotosPicker`) ou arquivo PDF (`fileImporter`).
/// No mock o arquivo é salvo localmente pelo repository.
struct WalletAttachmentPicker: View {
    let onPick: (String, Data) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false

    var body: some View {
        HStack(spacing: Spacing.lg) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Foto", systemImage: "photo")
                    .font(.brand(.subheadline, weight: .medium))
            }
            .buttonStyle(.plain).foregroundStyle(Theme.accent)

            Button {
                showFileImporter = true
            } label: {
                Label("Arquivo", systemImage: "folder")
                    .font(.brand(.subheadline, weight: .medium))
            }
            .buttonStyle(.plain).foregroundStyle(Theme.accent)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    onPick("foto-\(Int(Date().timeIntervalSince1970)).jpg", data)
                }
                photoItem = nil
            }
        }
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.pdf, .image]) { result in
            if case .success(let url) = result {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    onPick(url.lastPathComponent, data)
                }
            }
        }
    }
}

private extension String {
    /// Primeira letra maiúscula (frases montadas dinamicamente).
    var capitalizedSentence: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
