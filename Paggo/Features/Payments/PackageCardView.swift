import SwiftUI

/// Linha de pagamento na listagem — estilo editorial, sem card de borda arredondada. Nome em
/// destaque (Title Case), valor num peso fino e generoso, metadados discretos e a data legível.
/// A separação entre linhas (hairline) fica a cargo da lista.
///
/// O conteúdo é recuado por `horizontalInset`, mas o quadro externo (fundo de seleção + área de
/// toque) ocupa a largura toda — assim o realce de seleção sangra até as bordas do dispositivo
/// enquanto o conteúdo permanece alinhado à lista.
///
/// Quais campos aparecem é controlado por `PaymentCardPrefsStore.shared` (lido no `body`, portanto
/// os cartões atualizam reativamente quando as preferências mudam).
struct PackageCardView: View {
    let package: Package
    var isSelecting: Bool = false
    var isSelected: Bool = false
    var showApprovers: Bool = false
    var horizontalInset: CGFloat = 0
    /// Força a exibição das etiquetas independentemente da preferência global (a tela de Aprovações
    /// sempre mostra os sinais de risco, mesmo que a lista de Pagamentos os esconda).
    var showTagsOverride: Bool? = nil

    private var tags: [PackageTag] { package.tags ?? [] }

    /// Nome da organização pagadora: abreviação (se não vazia) senão razão social.
    private var payerOrgName: String? {
        if let abbr = package.organization?.abbreviation, !abbr.isEmpty { return abbr }
        return package.organization?.legalName
    }

    /// Nome do pagador para o bloco "Pagador → Contraparte": prefere o campo novo `payerName`,
    /// cai para o nome da organização quando o backend defasado ainda não envia `payerName`.
    private var payerDisplayName: String? {
        if let name = package.payerName, !name.isEmpty { return name }
        return payerOrgName
    }

    /// Documento do recebedor formatado como CNPJ/CPF (idempotente). É o subtítulo compacto do
    /// recebedor no layout sem "Pagador" (quando ligado, o bloco Pagador → Contraparte assume).
    private var receiverDocMasked: String { package.receiverTaxId.cnpjOrCpfMasked }

    /// Data de agendamento (dd/MM/yy) com o sufixo `+N` de dias úteis quando cai em fim de semana ou
    /// feriado bancário — paridade com `formatPaymentDate` do web.
    @ViewBuilder private var paymentDateView: some View {
        let pd = BusinessDay.paymentDate(fromISO: package.paymentDate)
        HStack(spacing: 3) {
            Text(pd.text)
                .font(.brand(.callout, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
            if let plus = pd.plusDays {
                Text("+\(plus)")
                    .font(.brand(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.warning)
            }
        }
    }

    /// Valor no peso editorial (22 light).
    private var amountView: some View {
        Text(package.paymentAmount.currencyFromCents())
            .font(.brand(size: 22, weight: .light))
            .monospacedDigit()
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
    }

    var body: some View {
        // Acesso ao singleton @Observable dentro do body registra a dependência de observação.
        let prefs = PaymentCardPrefsStore.shared
        let showPayer = prefs.showPayer
        let showTags = showTagsOverride ?? prefs.showTags

        HStack(alignment: .center, spacing: Spacing.md) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                if showTags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                                TagBadge(tag: tag)
                            }
                        }
                    }
                    .scrollClipDisabled()
                }

                if showPayer {
                    payerCounterpartyBlock
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        amountView
                        Spacer(minLength: Spacing.sm)
                        paymentDateView
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Text(package.receiverName.capitalizedNamePtBr)
                            .font(.brand(.callout, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: Spacing.sm)
                        amountView
                    }

                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Text(receiverDocMasked)
                            .font(.brand(.caption))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                        Spacer(minLength: Spacing.sm)
                        paymentDateView
                    }
                }

                extraFieldLines(prefs: prefs)

                if showApprovers, !package.approvers.isEmpty {
                    ApproversRow(approvers: package.approvers, compact: true)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, horizontalInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Theme.accent.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
    }

    // MARK: Pagador → Contraparte

    /// Bloco de duas colunas com uma seta central: à esquerda o pagador (marca Paggo + conta/CNPJ),
    /// à direita a contraparte (recebedor + CNPJ/CPF). Degrada peça a peça quando os campos novos
    /// (`payerAccount`/`payerTaxId`) ainda não vêm do backend.
    private var payerCounterpartyBlock: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            partyColumn(
                label: "PAGADOR",
                name: (payerDisplayName ?? "—").capitalizedNamePtBr,
                mark: paggoMark,
                detail: payerDetail,
                alignment: .leading
            )

            Image(systemName: "arrow.right")
                .font(.brand(.caption, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 14)

            partyColumn(
                label: "CONTRAPARTE",
                name: package.receiverName.capitalizedNamePtBr,
                mark: nil,
                detail: receiverDocMasked,
                alignment: .trailing
            )
        }
    }

    /// Marca Paggo em miniatura (logo embarcado), para identificar a conta pagadora.
    private var paggoMark: AnyView {
        AnyView(
            Image("bank-paggo")
                .resizable()
                .scaledToFill()
                .frame(width: 14, height: 14)
                .background(.white)
                .clipShape(Circle())
        )
    }

    /// Linha de detalhe do pagador: "(conta) · (CNPJ/CPF)", só com as peças disponíveis.
    private var payerDetail: String {
        var pieces: [String] = []
        if let acc = package.payerAccount, !acc.isEmpty { pieces.append(acc) }
        if let doc = package.payerTaxId, !doc.isEmpty { pieces.append(doc.cnpjOrCpfMasked) }
        return pieces.joined(separator: " · ")
    }

    @ViewBuilder
    private func partyColumn(
        label: String,
        name: String,
        mark: AnyView?,
        detail: String,
        alignment: HorizontalAlignment
    ) -> some View {
        let textAlign: TextAlignment = alignment == .trailing ? .trailing : .leading
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.brand(.caption2, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Theme.textTertiary)
            Text(name)
                .font(.brand(.subheadline, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(textAlign)
                .lineLimit(2)
            if !detail.isEmpty {
                HStack(spacing: Spacing.xs) {
                    if alignment == .leading, let mark { mark }
                    Text(detail)
                        .font(.brand(.caption2))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(textAlign)
                        .lineLimit(1)
                    if alignment == .trailing, let mark { mark }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
    }

    // MARK: Linhas extras (Conta Gerencial / Centro de Custo / Documento)

    @ViewBuilder
    private func extraFieldLines(prefs: PaymentCardPrefsStore) -> some View {
        // Número da alocação — só quando presente e ao menos um dos campos de rateio está ligado.
        let allocationNumber: String? = {
            guard prefs.showManagerialAccount || prefs.showCostCenter,
                let v = package.allocationNumber, !v.isEmpty
            else { return nil }
            return v
        }()
        let managerial: (String, Int)? = {
            guard prefs.showManagerialAccount,
                let v = package.managerialAccount, !v.isEmpty
            else { return nil }
            return (v, max(0, package.managerialAccountCount - 1))
        }()
        let costCenter: (String, Int)? = {
            guard prefs.showCostCenter,
                let v = package.costCenter, !v.isEmpty
            else { return nil }
            return (v, max(0, package.costCenterCount - 1))
        }()
        let document: (String, Int)? = {
            guard prefs.showDocument else { return nil }
            let type = package.documentType ?? ""
            let number = package.documentNumber ?? ""
            let text = [type, number].filter { !$0.isEmpty }.joined(separator: " ")
            guard !text.isEmpty else { return nil }
            return (text, max(0, package.documentCount - 1))
        }()

        if allocationNumber != nil || managerial != nil || costCenter != nil || document != nil {
            VStack(alignment: .leading, spacing: 2) {
                if let a = allocationNumber {
                    extraLine(symbol: "number", label: "Alocação", value: a, extra: 0)
                }
                if let m = managerial {
                    extraLine(
                        symbol: "chart.bar.doc.horizontal", label: "Conta Gerencial",
                        value: m.0, extra: m.1)
                }
                if let c = costCenter {
                    extraLine(
                        symbol: "square.grid.2x2", label: "Centro de Custo",
                        value: c.0, extra: c.1)
                }
                if let d = document {
                    extraLine(symbol: "doc.text", label: "Documento", value: d.0, extra: d.1)
                }
            }
            .padding(.top, 1)
        }
    }

    private func extraLine(symbol: String, label: String, value: String, extra: Int) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: symbol)
                .font(.brand(.caption2))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 14)
            Text("\(label) · \(value)")
                .font(.brand(.caption2))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            if extra > 0 {
                Text("+\(extra)")
                    .font(.brand(.caption2, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}
