import SwiftUI

/// Routes creation by type: Purchase opens the multi-step flow (mirrors the requisition prototype);
/// the others use a simple form.
struct NewRequestFlow: View {
    let type: RequestType
    var onComplete: (PurchaseRequest) -> Void

    var body: some View {
        switch type {
        case .purchase:
            PurchaseRequestWizard(onComplete: onComplete)
        case .payment, .reimbursement:
            SimpleRequestForm(type: type, onComplete: onComplete)
        }
    }
}

private enum ReqKind: String, CaseIterable, Identifiable {
    case purchaseOrder = "Ordem de compra", contract = "Contrato"
    var id: String { rawValue }
}

// MARK: - Purchase requisition (Project → Items → Delivery → Review)

struct PurchaseRequestWizard: View {
    var onComplete: (PurchaseRequest) -> Void
    @Environment(\.dismiss) private var dismiss

    private enum Step: Int, CaseIterable {
        case project, items, delivery, review
        var nav: String {
            switch self {
            case .project: return "Projeto"
            case .items: return "Itens"
            case .delivery: return "Entrega"
            case .review: return "Revisão"
            }
        }
        var title: String {
            switch self {
            case .project: return "Selecione o projeto que irá consumir os itens da requisição"
            case .items: return "Selecione os itens que farão parte dessa requisição de compra"
            case .delivery: return "Para onde e quando entregar?"
            case .review: return "Confira e envie a requisição"
            }
        }
        var subtitle: String {
            switch self {
            case .project: return "O consumo dos itens será registrado e apropriado neste projeto."
            case .items: return "Adicione os itens e as quantidades desta requisição."
            case .delivery: return "Defina tipo, data e local de entrega."
            case .review: return "Revise os itens, valores e a aprovação."
            }
        }
    }

    @State private var step: Step = .project
    @State private var submitted = false

    // Project
    @State private var project: Project?
    @State private var projectQuery = ""
    // Items
    @State private var items: [RequestItem] = []
    @State private var showCatalog = false
    // Delivery
    @State private var reqKind: ReqKind = .purchaseOrder
    @State private var deliveryDate = Date().adding(days: 7)
    @State private var urgent = false
    @State private var comment = ""

    private var totalCents: Int { items.reduce(0) { $0 + $1.subtotalCents } }

    private var canProceed: Bool {
        switch step {
        case .project: return project != nil
        case .items: return !items.isEmpty
        case .delivery, .review: return true
        }
    }

    var body: some View {
        SheetScaffold(title: step.nav, closePlacement: .topBarLeading) {
            Group {
                if submitted { successState } else { wizard }
            }
            .sheet(isPresented: $showCatalog) {
                CatalogSheet(items: $items)
            }
        }
    }

    private var wizard: some View {
        VStack(spacing: 0) {
            progressHeader
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    switch step {
                    case .project: projectStep
                    case .items: itemsStep
                    case .delivery: deliveryStep
                    case .review: reviewStep
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            actionBar
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Theme.accent : Theme.surfaceHigh)
                        .frame(height: 4)
                        .animation(.snappy, value: step)
                }
            }
            Text(step.title)
                .font(.brand(size: 20, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(step.subtitle)
                .font(.brand(.caption))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    // MARK: Step 1 — Project

    private var filteredProjects: [Project] {
        let q = projectQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return MockData.projects }
        return MockData.projects.filter {
            $0.name.lowercased().contains(q) || $0.cnpj.contains(q)
        }
    }

    private var projectStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            BrandTextField("Busque o projeto (nome ou CNPJ)", text: $projectQuery)
            ForEach(filteredProjects) { p in
                Button { withAnimation(.snappy) { project = p } } label: {
                    projectCard(p, selected: project?.id == p.id)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func projectCard(_ p: Project, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(p.name).font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textPrimary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.accent)
                }
            }
            Text(p.cnpj).font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
                Text(p.address).font(.brand(.caption2)).foregroundStyle(Theme.textTertiary).lineLimit(2)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(selected ? Theme.accent : Theme.stroke, lineWidth: selected ? 1.5 : 1)
        )
    }

    // MARK: Step 2 — Items

    private var itemsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if items.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 30, weight: .light)).foregroundStyle(Theme.textTertiary)
                    Text("Nenhum item adicionado")
                        .font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textSecondary)
                    Text("Adicione os materiais, serviços ou equipamentos necessários para a frente de obra.")
                        .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, Spacing.xl)
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        itemRow(item)
                        Divider().overlay(Theme.separator)
                    }
                }
            }

            Button { showCatalog = true } label: {
                Label("Adicionar item", systemImage: "plus")
                    .font(.brand(.subheadline, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .stroke(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textPrimary)

            HStack {
                Text("Total estimado").font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(totalCents.currencyFromCents())
                    .font(.brand(.title3, weight: .semibold))
                    .monospacedDigit().foregroundStyle(Theme.textPrimary)
            }
            .padding(.top, Spacing.sm)
        }
    }

    private func itemRow(_ item: RequestItem) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textPrimary)
                Text("\(item.code) · \(item.quantity) \(item.unit) × \(item.unitCents.currencyFromCents())")
                    .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(item.subtotalCents.currencyFromCents())
                .font(.brand(.subheadline, weight: .medium)).monospacedDigit().foregroundStyle(Theme.textPrimary)
            Button { items.removeAll { $0.id == item.id } } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Spacing.md)
    }

    // MARK: Step 3 — Delivery

    private var deliveryStep: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            field("Tipo de requisição") {
                SegmentedControl(selection: $reqKind, options: ReqKind.allCases, label: { $0.rawValue })
            }
            field("Data de entrega") {
                DatePicker("", selection: $deliveryDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Theme.accent)
            }
            field("Local de entrega") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 12)).foregroundStyle(Theme.accent)
                        Text(project?.name ?? "—").font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textPrimary)
                    }
                    Text("Endereço do Projeto")
                        .font(.brand(.caption2, weight: .medium)).foregroundStyle(Theme.info)
                        .padding(.horizontal, Spacing.sm).padding(.vertical, 3)
                        .background(Theme.info.opacity(0.14), in: Capsule())
                    Text(project?.address ?? "")
                        .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .inputSurface()
            }
            Toggle(isOn: $urgent) {
                Text("Marcar como urgente").font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textPrimary)
            }
            .tint(Theme.accent)
            field("Comentário (opcional)") {
                BrandTextField("Ex.: entregar pela manhã, falar com o mestre de obra…", text: $comment, axis: .vertical)
            }
        }
    }

    // MARK: Step 4 — Review

    private func exceedsBudget(_ item: RequestItem) -> Bool { item.subtotalCents > 50_000 }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Items + budget flags
            VStack(spacing: 0) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name).font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(item.subtotalCents.currencyFromCents())
                                .font(.brand(.subheadline, weight: .medium)).monospacedDigit().foregroundStyle(Theme.textPrimary)
                        }
                        HStack(spacing: Spacing.sm) {
                            Text("\(item.quantity) \(item.unit) · \(item.category)")
                                .font(.brand(.caption2)).foregroundStyle(Theme.textTertiary)
                            if exceedsBudget(item) {
                                Text("Excede orçamento")
                                    .font(.brand(.caption2, weight: .medium)).foregroundStyle(Theme.warning)
                                    .padding(.horizontal, Spacing.sm).padding(.vertical, 2)
                                    .background(Theme.warning.opacity(0.14), in: Capsule())
                            }
                        }
                    }
                    .padding(.vertical, Spacing.md)
                    Divider().overlay(Theme.separator)
                }
                HStack {
                    Text("Total estimado").font(.brand(.body, weight: .medium)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(totalCents.currencyFromCents())
                        .font(.brand(.title3, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.textPrimary)
                }
                .padding(.top, Spacing.md)
            }

            sectionSeparator
            summaryRow("Projeto", project?.name ?? "—")
            summaryRow("Tipo", reqKind.rawValue)
            summaryRow("Data de entrega", DateText.full(deliveryDate.isoString))
            summaryRow("Endereço de entrega", project?.address ?? "—")
            if urgent { summaryRow("Prioridade", "Urgente") }

            sectionSeparator
            approvalSection
        }
    }

    private var approvalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.shield").font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                Text("Aprovação").font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textPrimary)
                Spacer()
                HStack(spacing: -8) {
                    approverAvatar("BR", Theme.accent)
                    approverAvatar("BP", Theme.info)
                }
            }
            HStack {
                Text("Gestor direto").font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.positive)
                    Text("Bruno Ruotolo").font(.brand(.caption, weight: .medium)).foregroundStyle(Theme.positive)
                }
            }
            HStack {
                Text("Conta gerencial").font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("Pendente").font(.brand(.caption, weight: .medium)).foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(Spacing.md)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }

    private func approverAvatar(_ initials: String, _ color: Color) -> some View {
        Text(initials)
            .font(.brand(.caption2, weight: .semibold)).foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(color, in: Circle())
            .overlay(Circle().stroke(Theme.base, lineWidth: 2))
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(label).font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
            Spacer(minLength: Spacing.md)
            Text(value)
                .font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing).lineLimit(3)
        }
        .padding(.vertical, Spacing.sm)
    }

    private var sectionSeparator: some View { Divider().overlay(Theme.separator).padding(.vertical, Spacing.xs) }

    // MARK: Action bar

    private var actionBar: some View {
        BottomActionBar {
            HStack(spacing: Spacing.md) {
                if step == .review {
                    Button { submit() } label: { Text("Salvar rascunho").frame(maxWidth: .infinity) }
                        .buttonStyle(.glass)
                } else if step != .project {
                    Button {
                        withAnimation(.snappy) { step = Step(rawValue: step.rawValue - 1) ?? .project }
                    } label: { Text("Voltar").frame(maxWidth: .infinity) }
                    .buttonStyle(.glass)
                }
                Button {
                    if step == .review { submit() }
                    else { withAnimation(.snappy) { step = Step(rawValue: step.rawValue + 1) ?? .review } }
                } label: { Text(step == .review ? "Enviar" : "Avançar").frame(maxWidth: .infinity) }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .disabled(!canProceed)
            }
            .controlSize(.large)
        }
    }

    private func submit() {
        let title = items.count <= 1
            ? (items.first?.name ?? "Requisição de compra")
            : "\(items[0].name) +\(items.count - 1)"
        let request = PurchaseRequest(
            id: "req-\(UUID().uuidString.prefix(6))",
            type: .purchase,
            title: title,
            requester: "Você",
            costCenter: project?.name ?? "—",
            amountCents: totalCents,
            status: .requested,
            date: Date().isoString,
            itemCount: items.count
        )
        onComplete(request)
        withAnimation(.snappy) { submitted = true }
    }

    private var successState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(Theme.positive)
            Text("Requisição enviada").font(.brand(.title3, weight: .medium)).foregroundStyle(Theme.textPrimary)
            Text("\(items.count) \(items.count == 1 ? "item" : "itens") • \(totalCents.currencyFromCents())")
                .font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            Spacer()
            Button { dismiss() } label: { Text("Concluir").frame(maxWidth: .infinity) }
                .buttonStyle(.glassProminent).tint(Theme.accent).controlSize(.large)
                .padding(.horizontal, Spacing.lg)
        }
        .padding(Spacing.lg).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label).font(.brand(.caption, weight: .medium)).foregroundStyle(Theme.textSecondary)
            content()
        }
    }
}

// MARK: - Catalog (add-item sheet)

struct CatalogSheet: View {
    @Binding var items: [RequestItem]
    @State private var query = ""
    @State private var detail: CatalogItem?
    @State private var qty = 1

    private var filtered: [CatalogItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return MockData.catalog }
        return MockData.catalog.filter { $0.name.lowercased().contains(q) || $0.code.lowercased().contains(q) }
    }
    private var grouped: [(String, [CatalogItem])] {
        ["Material", "Serviço", "Equipamento"].compactMap { cat in
            let xs = filtered.filter { $0.category == cat }
            return xs.isEmpty ? nil : (cat, xs)
        }
    }
    private func isAdded(_ item: CatalogItem) -> Bool { items.contains { $0.code == item.code } }
    private func currentQty(_ item: CatalogItem) -> Int { items.first { $0.code == item.code }?.quantity ?? 1 }

    var body: some View {
        SheetScaffold(title: "Adicionar item", detents: [.large]) {
            Group {
                if let detail { detailView(detail) } else { searchList }
            }
        }
    }

    private var searchList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(grouped, id: \.0) { cat, xs in
                    Text(cat)
                        .font(.brand(.caption, weight: .medium)).foregroundStyle(Theme.textSecondary)
                        .padding(.top, Spacing.md).padding(.bottom, Spacing.xs)
                    ForEach(xs) { item in
                        Button { qty = currentQty(item); detail = item } label: { row(item) }
                            .buttonStyle(.plain)
                        Divider().overlay(Theme.separator)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxl)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Buscar por nome ou código")
    }

    private func row(_ item: CatalogItem) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textPrimary)
                Text("\(item.code) · \(item.unit) · \(item.unitCents.currencyFromCents())")
                    .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if isAdded(item) {
                Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.positive)
            }
        }
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }

    private func detailView(_ item: CatalogItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Button { detail = nil } label: {
                Label("Voltar para a busca", systemImage: "chevron.left")
                    .font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.brand(.body, weight: .medium)).foregroundStyle(Theme.textPrimary)
                Text("\(item.code) · \(item.category) · \(item.priceLabel)")
                    .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(Theme.stroke, lineWidth: 1))

            HStack(spacing: Spacing.md) {
                stepButton("minus") { if qty > 1 { qty -= 1 } }
                Text("\(qty)")
                    .font(.brand(.body, weight: .medium)).monospacedDigit().foregroundStyle(Theme.textPrimary)
                    .frame(minWidth: 44)
                stepButton("plus") { qty += 1 }
                Spacer()
                Text(item.unit)
                    .font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Spacing.md).padding(.vertical, 8)
                    .background(Theme.surfaceHigh, in: Capsule())
            }

            HStack {
                Text("Subtotal").font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text((item.unitCents * qty).currencyFromCents())
                    .font(.brand(.body, weight: .medium)).monospacedDigit().foregroundStyle(Theme.textPrimary)
            }

            Spacer()

            Button {
                items.removeAll { $0.code == item.code }
                items.append(RequestItem(from: item, quantity: qty))
                detail = nil
            } label: {
                Text(isAdded(item) ? "Atualizar item" : "Adicionar à requisição").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
            .controlSize(.large)
        }
        .padding(Spacing.lg)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simple form (Payment / Reimbursement)

struct SimpleRequestForm: View {
    let type: RequestType
    var onComplete: (PurchaseRequest) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amountText = ""
    @State private var costCenter = MockData.costCenters.first ?? "Operações"
    @State private var justification = ""
    @State private var submitted = false

    private var amountCents: Int {
        let normalized = amountText.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        return Int((Double(normalized) ?? 0) * 100)
    }
    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && amountCents > 0
    }

    var body: some View {
        SheetScaffold(title: "Nova solicitação", closePlacement: .topBarLeading) {
            Group {
                if submitted { successState } else { form }
            }
        }
    }

    private var form: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack(spacing: Spacing.md) {
                        TintedIcon(symbol: type.icon, tint: type.tint, symbolSize: 16)
                        Text("Solicitação de \(type.label)")
                            .font(.brand(.body, weight: .medium)).foregroundStyle(Theme.textPrimary)
                    }
                    labeled("Descrição") { BrandTextField("Ex.: \(type.blurb)", text: $title) }
                    labeled("Valor (R$)") {
                        BrandTextField("0,00", text: $amountText).keyboardType(.decimalPad)
                    }
                    labeled("Centro de custo") {
                        MenuSelectField(selection: costCenter, options: MockData.costCenters,
                                        title: { $0 }, onSelect: { costCenter = $0 })
                            .dynamicTypeSize(.small)
                    }
                    labeled("Justificativa (opcional)") {
                        BrandTextField("Detalhe a solicitação", text: $justification, axis: .vertical)
                    }
                }
                .padding(.horizontal, Spacing.lg).padding(.top, Spacing.lg).padding(.bottom, Spacing.xxxl)
            }
            BottomActionBar {
                Button { submit() } label: { Text("Enviar solicitação").frame(maxWidth: .infinity) }
                    .buttonStyle(.glassProminent).tint(Theme.accent).controlSize(.large)
                    .disabled(!canSubmit)
            }
        }
    }

    private func submit() {
        let request = PurchaseRequest(
            id: "req-\(UUID().uuidString.prefix(6))",
            type: type,
            title: title.trimmingCharacters(in: .whitespaces),
            requester: "Você",
            costCenter: costCenter,
            amountCents: amountCents,
            status: .requested,
            date: Date().isoString,
            itemCount: 1
        )
        onComplete(request)
        withAnimation(.snappy) { submitted = true }
    }

    private var successState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(Theme.positive)
            Text("Solicitação enviada").font(.brand(.title3, weight: .medium)).foregroundStyle(Theme.textPrimary)
            Text("\(type.label) • \(amountCents.currencyFromCents())")
                .font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
            Spacer()
            Button { dismiss() } label: { Text("Concluir").frame(maxWidth: .infinity) }
                .buttonStyle(.glassProminent).tint(Theme.accent).controlSize(.large)
                .padding(.horizontal, Spacing.lg)
        }
        .padding(Spacing.lg).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label).font(.brand(.caption, weight: .medium)).foregroundStyle(Theme.textSecondary)
            content()
        }
    }
}

// MARK: - Shared inputs

/// Text field using the app input style.
struct BrandTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal

    init(_ placeholder: String, text: Binding<String>, axis: Axis = .horizontal) {
        self.placeholder = placeholder
        self._text = text
        self.axis = axis
    }

    var body: some View {
        let f = TextField(placeholder, text: $text, axis: axis)
            .font(.brand(.subheadline))
            .foregroundStyle(Theme.textPrimary)
        return Group {
            if axis == .vertical { f.lineLimit(3...6) } else { f.lineLimit(1) }
        }
        .inputSurface()
    }
}

extension View {
    /// Standard input background (rounded field with a subtle border).
    func inputSurface() -> some View {
        self
            .padding(.horizontal, Spacing.md).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}
