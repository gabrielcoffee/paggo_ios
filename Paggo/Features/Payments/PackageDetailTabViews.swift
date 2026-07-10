import SwiftUI

// "Documentos", "Orçamento", "Conciliação" and "Histórico" tab content,
// ported from the Expo PackageDetails documents/budget/conciliation/history components.

// MARK: - Document entries (documents/PaymentDocumentEntries.tsx)

struct PaymentDocumentEntriesView: View {
    let entries: [PackageDocumentEntryRef]

    var body: some View {
        if entries.isEmpty {
            VStack(spacing: Spacing.md) {
                Image(systemName: "doc")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Theme.textTertiary)
                Text("Nenhum documento vinculado")
                    .font(.brand(.subheadline))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxxl)
        } else {
            DetailSection("Documentos Fiscais", systemImage: "doc.text") {
                // LazyVStack (dentro do ScrollView da aba): linhas fora da viewport não disparam
                // o fetch do preview. Identidade por id do documento — as duas seções (summary +
                // /document-entries) chegam em paralelo e podem reordenar o array; keying por
                // offset faria o @State do preview (thumbnail) grudar na posição, não no doc.
                LazyVStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.documentEntry.id) { index, entry in
                        row(entry)
                            .padding(.vertical, Spacing.md)
                        if index < entries.count - 1 {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
            }
        }
    }

    private func row(_ entry: PackageDocumentEntryRef) -> some View {
        let doc = entry.documentEntry
        let net = doc.netAmount
        var segments: [ProgressSegmentSpec] = []
        if net > 0, let reconciled = doc.reconciledAmount, reconciled > 0 {
            segments.append(ProgressSegmentSpec(
                fraction: Double(reconciled) / Double(net),
                color: Theme.positive,
                label: "Conciliado: \(reconciled.currencyFromCents())"
            ))
        }
        if net > 0, entry.amount > 0 {
            segments.append(ProgressSegmentSpec(
                fraction: Double(entry.amount) / Double(net),
                color: Theme.warning,
                label: "Neste pgto: \(entry.amount.currencyFromCents())"
            ))
        }

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            // Preview inline do arquivo (NF-e/anexo) quando a entrada tem URL — entradas sem
            // arquivo mantêm o layout só-metadados; falha de carregamento vira retry compacto.
            DocumentPreview(rawUrl: doc.fileUrl)
                .padding(.bottom, Spacing.xs)
            HStack {
                DetailBadge(label: DocumentEntryStatusInfo.label(for: doc.status),
                            variant: DocumentEntryStatusInfo.badge(for: doc.status))
                Spacer()
                Text("\(DocumentTypeDisplay.label(for: doc.type.name))\(doc.number.map { " #\($0)" } ?? "")")
                    .font(.brand(.caption, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            if !doc.counterpartyName.isEmpty {
                Text("\(doc.counterpartyName) · \(doc.counterpartyTaxId)")
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(doc.netAmount.currencyFromCents())
                    .font(.brand(.title3, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if let date = doc.documentDate {
                    Text(DateText.full(date))
                        .font(.brand(.caption2))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            if !segments.isEmpty {
                MiniProgressBar(segments: segments, height: 6, showLegend: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Attachments (documents/PaymentAttachments.tsx)

struct PaymentAttachmentsView: View {
    let attachments: [AttachmentDocument]

    var body: some View {
        DetailSection("Anexos", systemImage: "paperclip") {
            VStack(spacing: 0) {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, file in
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                        Text(file.name)
                            .font(.brand(.subheadline))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, Spacing.md)
                    if index < attachments.count - 1 {
                        Divider().overlay(Theme.separator)
                    }
                }
            }
        }
    }
}

// MARK: - Budget (details/budget/PaymentBudgetSection.tsx)

struct PaymentBudgetSectionView: View {
    let budget: BudgetData?

    var body: some View {
        DetailSection("Orçamento", systemImage: "chart.pie") {
            if let budget, !budget.lines.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(budget.lines.enumerated()), id: \.element.id) { index, line in
                        lineCard(line)
                            .padding(.vertical, Spacing.md)
                        if index < budget.lines.count - 1 {
                            Divider().overlay(Theme.separator)
                        }
                    }
                    if budget.hasOverBudgetLines {
                        Text("Este pagamento excede o orçamento em uma ou mais linhas")
                            .font(.brand(.caption, weight: .medium))
                            .foregroundStyle(Theme.negative)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.sm)
                            .background(Theme.negative.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                            .padding(.top, Spacing.sm)
                    }
                }
            } else {
                Text("Sem consumo de orçamento")
                    .font(.brand(.subheadline)).italic()
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func lineCard(_ line: BudgetLine) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.entityName)
                        .font(.brand(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("\(BudgetEntityLabel.label(line.entityType)) · \(line.budgetPlanName)")
                        .font(.brand(.caption2))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                if line.isOverBudget {
                    DetailBadge(label: "Excedido", variant: .danger)
                }
            }
            MiniProgressBar(
                segments: [ProgressSegmentSpec(
                    fraction: min(line.percentageUsed / 100, 1),
                    color: line.isOverBudget ? Theme.negative : Theme.positive,
                    label: "\(Int(line.percentageUsed.rounded()))% usado"
                )],
                height: 6
            )
            HStack {
                Text("Usado: \(line.totalUsedAmount.currencyFromCents())")
                    .font(.brand(.caption2)).foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("Total: \(line.totalBudgetAmount.currencyFromCents())")
                    .font(.brand(.caption2)).foregroundStyle(Theme.textTertiary)
            }
            Text("Contribuição: \(line.packageContributionAmount.currencyFromCents())")
                .font(.brand(.caption, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
    }
}

// MARK: - Conciliation (conciliation/PaymentConciliation.tsx)

struct PaymentConciliationView: View {
    let conciliation: ConciliationData?

    var body: some View {
        DetailSection("Conciliação", systemImage: "arrow.triangle.merge") {
            if let c = conciliation {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        Text("Status:")
                            .font(.brand(.subheadline, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        DetailBadge(label: c.reconciled ? "Conciliado" : "Pendente",
                                    variant: c.reconciled ? .success : .neutral)
                    }
                    if c.financialEntryId != nil {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "link").font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                            Text("Lançamento financeiro vinculado")
                                .font(.brand(.subheadline))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("CONFIGURAÇÕES")
                            .font(.brand(.caption2, weight: .medium)).tracking(0.5)
                            .foregroundStyle(Theme.textTertiary)
                        configItem("Exigir escrituração antes da conciliação",
                                   enabled: c.enforcePostingBeforeConciliation)
                        configItem("Exigir lançamentos válidos antes da escrituração",
                                   enabled: c.enforceValidEntriesBeforeConciliation)
                    }
                }
            } else {
                Text("Sem dados de conciliação")
                    .font(.brand(.subheadline)).italic()
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func configItem(_ label: String, enabled: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(enabled ? Theme.positive : Theme.textTertiary)
            Text(label)
                .font(.brand(.caption))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - History / chat (history/PaymentHistory.tsx)

struct PaymentHistoryView: View {
    /// As mensagens (e estados de entrega) vivem no store — sobrevivem à troca de abas,
    /// que destrói esta view e seu @State.
    let detail: PackageDetailStore
    let currentUser: AuthUser?

    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    private var entries: [PackageDetailStore.ChatEntry] { detail.chatEntries }
    private var currentUserId: String { currentUser?.id ?? "current-user" }
    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            if entries.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Theme.textTertiary)
                    Text("Nenhuma mensagem ainda")
                        .font(.brand(.subheadline))
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Spacing.sm) {
                            ForEach(entries) { entry in
                                row(entry).id(entry.id)
                            }
                        }
                        .padding(Spacing.lg)
                    }
                    .onChange(of: entries.count) { _, _ in
                        if let last = entries.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
            }
            inputBar
        }
        .onAppear { detail.seedChatIfNeeded() }
    }

    @ViewBuilder private func row(_ entry: PackageDetailStore.ChatEntry) -> some View {
        if entry.message.isPlatformEvent {
            eventRow(entry.message)
        } else {
            messageRow(entry)
        }
    }

    private func eventColor(_ type: String) -> Color {
        if ChatEvent.success.contains(type) { return Theme.positive }
        if ChatEvent.danger.contains(type) { return Theme.negative }
        return Theme.accent
    }

    private func eventRow(_ message: ChatMessage) -> some View {
        let color = eventColor(message.type)
        return VStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "gearshape.fill").font(.system(size: 11))
                Text(message.text).font(.brand(.caption, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
            Text(timestamp(message.createdAt))
                .font(.brand(.caption2)).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func messageRow(_ entry: PackageDetailStore.ChatEntry) -> some View {
        let message = entry.message
        let isCurrent = message.user?.id == currentUserId
        return HStack(alignment: .bottom, spacing: Spacing.sm) {
            if isCurrent { Spacer(minLength: 40) }
            if !isCurrent {
                OwnerAvatar(name: message.user?.name ?? "?", size: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                if !isCurrent, let name = message.user?.name {
                    Text(name).font(.brand(.caption2, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                }
                Text(message.text)
                    .font(.brand(.footnote))
                    .foregroundStyle(isCurrent ? Color.white : Theme.textPrimary)
                Text(timestamp(message.createdAt))
                    .font(.brand(.caption2))
                    .foregroundStyle(isCurrent ? Color.white.opacity(0.7) : Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                if entry.delivery != .delivered {
                    HStack(spacing: 4) {
                        if entry.delivery == .sending {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(Color.white.opacity(0.7))
                            Text("Enviando…")
                        } else {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text("Falha — toque para reenviar")
                        }
                    }
                    .font(.brand(.caption2))
                    .foregroundStyle(Color.white.opacity(entry.delivery == .failed ? 1 : 0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                isCurrent ? Theme.accent : Theme.surfaceHigh,
                in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            )
            .opacity(entry.delivery == .failed ? 0.85 : 1)
            .frame(maxWidth: 260, alignment: isCurrent ? .trailing : .leading)
            .onTapGesture {
                if entry.delivery == .failed { detail.retryChat(id: entry.id) }
            }
            if !isCurrent { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isCurrent ? .trailing : .leading)
    }

    private var inputBar: some View {
        BottomActionBar(horizontalPadding: Spacing.md, verticalPadding: Spacing.md) {
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField("Escreva uma mensagem...", text: $draft, axis: .vertical)
                    .font(.brand(.subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1...4)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                    .focused($inputFocused)
                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(canSend ? Color.white : Theme.textTertiary)
                        .frame(width: 40, height: 40)
                        .background(canSend ? Theme.accent : Theme.surfaceHigh, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
    }

    /// Eco local imediato + envio real via o store; a bolha mostra "Enviando…" e, em falha,
    /// fica marcada com toque-para-reenviar.
    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let message = ChatMessage(
            text: text,
            createdAt: Date().isoString,
            type: "USER_MESSAGE",
            user: .init(id: currentUserId, name: currentUser?.firstName ?? "Você", email: currentUser?.email, image: nil)
        )
        detail.sendChat(message)
        draft = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func timestamp(_ iso: String) -> String {
        guard let date = DateText.parse(iso) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM HH:mm"
        return f.string(from: date)
    }
}
