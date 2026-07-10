import SwiftUI

// "Detalhes" tab sections, ported 1:1 from the Expo PackageDetails detail components.

// MARK: - Alerts (alerts/PaymentAlerts.tsx)

struct PaymentAlertsView: View {
    let alerts: [PaymentAlert]

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(alerts) { alert in
                HStack(alignment: .top, spacing: Spacing.md) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(alert.variant.badge.color)
                        .frame(width: 3)
                    Image(systemName: alert.variant.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(alert.variant.badge.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(.brand(.subheadline, weight: .semibold))
                            .foregroundStyle(alert.variant.badge.color)
                        Text(alert.description)
                            .font(.brand(.caption))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alert.variant.badge.color.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            }
        }
    }
}

// MARK: - Summary (summary/PaymentSummary.tsx)

struct PaymentSummaryView: View {
    let details: PackageDetails
    /// Summary ainda em voo: a semente cobre status/valor/partes, mas vencimento/multa/juros só
    /// chegam com o summary — skeleton pontual nesses campos em vez de esconder a tela inteira.
    var summaryLoading: Bool = false

    private var hasExtraAmounts: Bool {
        details.fine != nil || details.interest != nil || details.discountOrAddition != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // Hero — status + valor em destaque tipográfico.
            VStack(alignment: .leading, spacing: Spacing.sm) {
                DetailBadge(label: details.status.displayLabel, variant: details.status.badgeVariant)
                VStack(alignment: .leading, spacing: 0) {
                    Text("VALOR")
                        .font(.brand(.caption2, weight: .medium)).tracking(1)
                        .foregroundStyle(Theme.textTertiary)
                    Text(details.paymentAmount.currencyFromCents())
                        .font(.heroNumber)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
            }

            // Fluxo pagador → recebedor.
            HStack(alignment: .top, spacing: Spacing.md) {
                party(label: "Pagador",
                      name: details.payerName ?? details.payerAccountName,
                      detail: details.payerTaxId?.cnpjOrCpfMasked,
                      bank: details.payerBankName)
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 16)
                party(label: "Recebedor",
                      name: details.receiverName,
                      detail: details.receiverTaxId.cnpjOrCpfMasked,
                      bank: nil)
            }

            HStack(alignment: .top, spacing: Spacing.xl) {
                DetailInfoField(caption: "Agendamento", value: DateText.full(details.paymentDate))
                if summaryLoading && details.dueDate == nil {
                    skeletonField(caption: "Vencimento")
                } else {
                    DetailInfoField(caption: "Vencimento", value: details.dueDate.map(DateText.full))
                }
            }

            if hasExtraAmounts {
                HStack(alignment: .top, spacing: Spacing.xl) {
                    if let fine = details.fine {
                        DetailInfoField(caption: "Multa", value: fine.currencyFromCents())
                    }
                    if let interest = details.interest {
                        DetailInfoField(caption: "Juros", value: interest.currencyFromCents())
                    }
                    if let disc = details.discountOrAddition {
                        DetailInfoField(caption: "Desconto/Acréscimo", value: disc.currencyFromCents())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Campo com caption real e valor em skeleton (mesma métrica do DetailInfoField).
    private func skeletonField(caption: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(caption.uppercased())
                .font(.brand(.caption2, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)
            Skeleton(width: 92, height: 13)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func party(label: String, name: String?, detail: String?, bank: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.brand(.caption2, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)
            Text(name?.isEmpty == false ? name!.capitalizedNamePtBr : "—")
                .font(.brand(.callout, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            if let detail, !detail.isEmpty {
                Text(detail).font(.brand(.caption)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
            if let bank, !bank.isEmpty {
                Text(bank).font(.brand(.caption2)).foregroundStyle(Theme.textTertiary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tags (tags/PaymentTags.tsx)

struct PaymentTagsView: View {
    let typeLabel: String?
    let tags: [PackageTag]

    @ViewBuilder var body: some View {
        if typeLabel == nil && tags.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    if let typeLabel {
                        DetailBadge(label: typeLabel, variant: .info)
                    }
                    ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                        let display = PackageTagInfo.display(for: tag)
                        DetailBadge(label: display.displayName, variant: display.variant)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: - Description (details/description/PaymentDescriptionSection.tsx)

struct PaymentDescriptionView: View {
    let description: String?

    var body: some View {
        DetailSection("Descrição", systemImage: "doc.text") {
            Text(description?.isEmpty == false ? description! : "Sem descrição")
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Payment method (details/payment-method/PaymentMethodSection.tsx)

struct PaymentMethodSectionView: View {
    let method: PaymentMethod

    private var info: (label: String, symbol: String) { PaymentMethodDisplay.info(for: method.method) }
    private var bank: PaymentBankInfo? { method.bankAccountDetails }

    var body: some View {
        DetailSection("Método de Pagamento", systemImage: info.symbol) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: info.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text(info.label)
                        .font(.brand(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                methodFields
            }
        }
    }

    @ViewBuilder private var methodFields: some View {
        switch method.method {
        case "PIX":
            DetailInfoField(caption: "Chave Pix", value: bank?.pixKey)
            if let r = method.receiverName { DetailInfoField(caption: "Recebedor", value: r) }
        case "PIX_BY_ACCOUNT", "TED":
            HStack(alignment: .top, spacing: Spacing.lg) {
                DetailInfoField(caption: "Banco", value: BankCodeName.name(for: bank?.bankCode))
                DetailInfoField(caption: "Conta", value: bank?.accountNumber)
            }
            if let name = bank?.name { DetailInfoField(caption: "Titular", value: name) }
            if let taxId = bank?.taxId { DetailInfoField(caption: "CPF/CNPJ", value: taxId) }
            if let type = AccountTypeLabel.label(bank?.accountType) {
                DetailInfoField(caption: "Tipo de Conta", value: type)
            }
        case "PIX_QR":
            DetailInfoField(caption: "EMV", value: bank?.emv)
            if let r = method.receiverName { DetailInfoField(caption: "Recebedor", value: r) }
        case "BANKSLIP":
            if let slip = method.bankslip {
                HStack(alignment: .top, spacing: Spacing.lg) {
                    DetailInfoField(caption: "Valor", value: slip.amountTotal.currencyFromCents())
                    DetailInfoField(caption: "Vencimento", value: DateText.full(slip.dueDate))
                }
                DetailInfoField(caption: "Beneficiário", value: slip.receiverName)
                if let line = slip.digitableLine {
                    DetailInfoField(caption: "Linha Digitável", value: line)
                }
            }
        case "BARCODE":
            if let bar = method.barcodeDocument {
                HStack(alignment: .top, spacing: Spacing.lg) {
                    DetailInfoField(caption: "Valor", value: bar.amountTotal.currencyFromCents())
                    DetailInfoField(caption: "Vencimento", value: DateText.full(bar.dueDate))
                }
                if let r = bar.receiverName { DetailInfoField(caption: "Beneficiário", value: r) }
            }
        default:
            Text("Método de pagamento não definido")
                .font(.brand(.subheadline))
                .italic()
                .foregroundStyle(Theme.textTertiary)
        }
    }
}

// MARK: - Allocations (details/allocations/PaymentAllocationsSection.tsx)

struct PaymentAllocationsSectionView: View {
    let allocations: [PackageAllocation]

    var body: some View {
        DetailSection("Alocação", systemImage: "folder") {
            if allocations.isEmpty {
                Text("Sem alocação definida")
                    .font(.brand(.subheadline)).italic()
                    .foregroundStyle(Theme.textTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allocations.enumerated()), id: \.element.id) { index, alloc in
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack(spacing: Spacing.sm) {
                                if let pct = alloc.allocation {
                                    Text("\(Int(pct.rounded()))%")
                                        .font(.brand(.subheadline, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                }
                                if alloc.calculated == true {
                                    DetailBadge(label: "Calculada", variant: .info)
                                }
                            }
                            if let unit = alloc.unit, !unit.isEmpty {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: "number")
                                        .font(.brand(.caption2, weight: .semibold))
                                        .foregroundStyle(Theme.textTertiary)
                                    Text(unit)
                                        .font(.brand(.caption, weight: .semibold))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            HStack(alignment: .top, spacing: Spacing.lg) {
                                DetailInfoField(caption: "Projeto", value: alloc.project?.name)
                                DetailInfoField(caption: "Centro de Custo", value: alloc.costCenter?.name)
                            }
                            DetailInfoField(caption: "Conta Gerencial", value: alloc.managerialAccount?.name)
                            if let desc = alloc.description {
                                DetailInfoField(caption: "Descrição", value: desc)
                            }
                        }
                        .padding(.vertical, Spacing.md)
                        if index < allocations.count - 1 {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Approvers (details/approvers/PaymentApproversSection.tsx)

struct PaymentApproversSectionView: View {
    let approvers: [PaymentApproverDetail]

    private var groups: [(group: Int, items: [PaymentApproverDetail])] {
        let grouped = Dictionary(grouping: approvers, by: \.group)
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        DetailSection("Liberadores", systemImage: "person.2") {
            if approvers.isEmpty {
                Text("Sem liberadores definidos")
                    .font(.brand(.subheadline)).italic()
                    .foregroundStyle(Theme.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(groups, id: \.group) { group in
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("\(group.group)ª LIBERAÇÃO")
                                .font(.brand(.caption2, weight: .medium))
                                .tracking(0.5)
                                .foregroundStyle(Theme.textTertiary)
                            ForEach(group.items) { approver in
                                approverRow(approver)
                            }
                        }
                    }
                }
            }
        }
    }

    private func approverRow(_ approver: PaymentApproverDetail) -> some View {
        HStack(spacing: Spacing.md) {
            OwnerAvatar(name: approver.name, imageURL: approver.image, size: 36, ring: approver.approved == true)
            VStack(alignment: .leading, spacing: 1) {
                Text(approver.name)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(approver.email)
                    .font(.brand(.caption2))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            statusIcon(approver.approved)
        }
    }

    @ViewBuilder private func statusIcon(_ approved: Bool?) -> some View {
        switch approved {
        case .some(true):
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.positive)
        case .some(false):
            Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.negative)
        case .none:
            Image(systemName: "clock").foregroundStyle(Theme.textTertiary)
        }
    }
}

// MARK: - Delivery / Origem (details/delivery/PaymentDeliverySection.tsx)

struct PaymentDeliverySectionView: View {
    let delivery: DeliveryDocument

    var body: some View {
        DetailSection("Origem", systemImage: "doc.on.doc") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                DetailBadge(label: delivery.type.label, variant: .info)

                if let pr = delivery.paymentRequest {
                    paymentRequest(pr)
                } else if let r = delivery.reimbursement {
                    reimbursement(r)
                } else if let p = delivery.payroll {
                    payroll(p)
                } else if let w = delivery.wallet {
                    wallet(w)
                } else {
                    Text("Pagamento gerado automaticamente")
                        .font(.brand(.subheadline)).italic()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func paymentRequest(_ pr: PaymentRequestDelivery) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DetailInfoField(caption: "Nº Documento", value: pr.documentNumber)
            DetailInfoField(caption: "Descrição", value: pr.description)
            personRow(label: "Solicitante", person: pr.requester)
            if !pr.installments.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("PARCELAS")
                        .font(.brand(.caption2, weight: .medium)).tracking(0.5)
                        .foregroundStyle(Theme.textTertiary)
                    ForEach(pr.installments) { inst in
                        HStack(spacing: Spacing.md) {
                            Text("\(inst.number)ª")
                                .font(.brand(.caption, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 28, alignment: .leading)
                            Text(inst.amount.currencyFromCents())
                                .font(.brand(.subheadline, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(DateText.full(inst.dueDate))
                                .font(.brand(.caption2))
                                .foregroundStyle(Theme.textTertiary)
                            if let status = inst.status {
                                DetailBadge(label: status, variant: .neutral)
                            }
                        }
                        .padding(.vertical, 4)
                        Divider().overlay(Theme.separator)
                    }
                }
            }
        }
    }

    private func reimbursement(_ r: ReimbursementDelivery) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DetailInfoField(caption: "Descrição", value: r.description)
            HStack(alignment: .top, spacing: Spacing.lg) {
                DetailInfoField(caption: "Valor", value: r.amount.currencyFromCents())
                DetailInfoField(caption: "Categoria", value: r.categoryName)
            }
            personRow(label: "Solicitante", person: r.user)
            if r.requestingForAnotherPerson {
                DetailInfoField(caption: "Reembolsado para", value: r.reimbursedUserName)
            }
        }
    }

    private func payroll(_ p: PayrollDelivery) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.lg) {
                DetailInfoField(caption: "Colaborador", value: p.employeeName)
                DetailInfoField(caption: "CPF", value: p.employeeTaxId)
            }
            HStack(alignment: .top, spacing: Spacing.lg) {
                DetailInfoField(caption: "Regime", value: PayrollLabel.regimen(p.regimen))
                DetailInfoField(caption: "Status", value: PayrollLabel.status(p.status))
            }
            HStack(alignment: .top, spacing: Spacing.lg) {
                DetailInfoField(caption: "Salário", value: p.salary.currencyFromCents())
                DetailInfoField(caption: "Competência", value: p.payrollMonth)
            }
        }
    }

    private func wallet(_ w: WalletDelivery) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DetailInfoField(caption: "Carteira", value: w.walletName)
            HStack(alignment: .top, spacing: Spacing.lg) {
                DetailInfoField(caption: "Valor", value: w.amount.currencyFromCents())
                DetailInfoField(caption: "Status", value: WalletLabel.status(w.status))
            }
            personRow(label: "Usuário", person: w.user)
            if let desc = w.description {
                DetailInfoField(caption: "Descrição", value: desc)
            }
        }
    }

    private func personRow(label: String, person: DeliveryPerson) -> some View {
        HStack(spacing: Spacing.md) {
            OwnerAvatar(name: person.name, imageURL: person.image, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.brand(.caption2, weight: .medium)).tracking(0.5)
                    .foregroundStyle(Theme.textTertiary)
                Text(person.name)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer(minLength: 0)
        }
    }
}
