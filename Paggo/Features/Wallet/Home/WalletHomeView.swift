import SwiftUI

/// Início da Carteira — saudação, pilha de cartões e ações de pagamento (Pix / Pagar).
/// Tocar a pilha expande **inline**: o cartão selecionado fica no topo e os demais deslizam para
/// baixo dele (título vira "Cartões", saudação vira botão de voltar, ações somem). Os cartões
/// nunca saem da hierarquia — a transição é só movimento, por isso é contínua.
struct WalletHomeView: View {
    @Environment(WalletStore.self) private var wallet
    @Environment(BudgetStore.self) private var budgets
    @Environment(AuthStore.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var payLaunch: WalletPayLaunch?
    @State private var optionsKind: WalletPayOptionsSheet.Kind?
    @State private var pendingLaunch: WalletPayLaunch?
    // Debug: PAGGO_WALLET_CARDS=1 abre direto a visão "Cartões" (verificação de UI).
    @State private var isCardsExpanded =
        ProcessInfo.processInfo.environment["PAGGO_WALLET_CARDS"] == "1"

    var body: some View {
        NavigationStack {
            content
                .screenBackground(tint: WalletCardStyle.at(wallet.styleIndex(for: wallet.currentWallet)).accent)
                .animation(.easeInOut(duration: 0.4), value: wallet.currentWallet?.id)
                .toolbar(.hidden, for: .navigationBar)
                .fullScreenCover(item: $payLaunch) { launch in
                    WalletPaymentFlowView(entry: launch.entry, preferScanner: launch.preferScanner)
                }
                // Sheet de opções (Pix / Pagar). A escolha só abre o fluxo DEPOIS do sheet fechar
                // (duas apresentações simultâneas brigam) — daí o pendingLaunch no onDismiss.
                .sheet(item: $optionsKind, onDismiss: {
                    if let pending = pendingLaunch {
                        pendingLaunch = nil
                        payLaunch = pending
                    }
                }) { kind in
                    WalletPayOptionsSheet(kind: kind) { launch in
                        pendingLaunch = launch
                        optionsKind = nil
                    }
                }
                .task {
                    await wallet.load()
                    await budgets.load()
                    // Debug: PAGGO_WALLET_PAY=pixKey|pixCopyPaste|pixQR|boleto abre direto o fluxo.
                    if payLaunch == nil,
                       let raw = ProcessInfo.processInfo.environment["PAGGO_WALLET_PAY"],
                       let entry = WalletPaymentEntry(rawValue: raw) {
                        payLaunch = WalletPayLaunch(entry: entry)
                    }
                }
        }
    }

    @ViewBuilder private var content: some View {
        if wallet.isLoading && !wallet.hasLoaded {
            ProgressView().tint(Theme.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = wallet.loadError, !wallet.hasLoaded {
            errorState(error)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header.padding(.horizontal, Spacing.lg)
                    if wallet.wallets.isEmpty {
                        emptyWalletsCard.padding(.horizontal, Spacing.lg)
                    } else {
                        cardsArea.padding(.horizontal, Spacing.lg)
                    }
                    if !isCardsExpanded {
                        actionGrid
                            .padding(.horizontal, Spacing.lg)
                            .transition(.opacity)
                        budgetsSection
                            .padding(.horizontal, Spacing.lg)
                            .transition(.opacity)
                    }
                }
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxxl)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .refreshable { await wallet.load(force: true) }
        }
    }

    // MARK: Header (título à esquerda como nas outras telas: saudação ⇄ voltar+"Cartões" · perfil · olho)

    @ViewBuilder private var header: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            if isCardsExpanded {
                Button(action: collapse) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(Theme.surfaceHigh, in: Circle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            // Título na mesma serifa/tamanho/posição dos títulos de Pagar e Extrato.
            Group {
                if isCardsExpanded {
                    Text("Cartões").transition(.opacity)
                } else {
                    Text("\(greetingPrefix), \(greetingName)").transition(.opacity)
                }
            }
            .font(.system(size: 32, design: .serif))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Spacer(minLength: Spacing.sm)

            if !isCardsExpanded {
                ProfileMenu().transition(.opacity)
            }

            // Ofusca os valores de todos os cartões (bolinhas) — controle único da página.
            Button { wallet.balanceHidden.toggle() } label: {
                Image(systemName: wallet.balanceHidden ? "eye.slash" : "eye")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(Theme.surfaceHigh, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var greetingName: String {
        (auth.activeUser?.name ?? auth.savedUser?.name)?
            .split(separator: " ").prefix(2).joined(separator: " ") ?? "bem-vindo"
    }

    private var greetingPrefix: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: return "Bom dia"
        case 12..<18: return "Boa tarde"
        default: return "Boa noite"
        }
    }

    // MARK: Cartões (pilha ⇄ leque de topos — os MESMOS views, a transição é só movimento)

    /// Altura de um cartão (aspect 1.72 na largura útil).
    private var cardHeight: CGFloat {
        (UIScreen.main.bounds.width - Spacing.lg * 2) / 1.72
    }

    /// Faixa visível do topo de cada cartão no leque expandido — só a linha do nome + saldo;
    /// o "Saldo" do corpo fica coberto pelo cartão de baixo.
    private let fanPeek: CGFloat = 66
    private let stackPeek: CGFloat = -14

    /// Profundidade do cartão na sequência da pilha: 0 = selecionado (frente/embaixo);
    /// 1, 2… = demais na ordem da lista (atrás/em cima). A MESMA sequência vale no leque.
    private func depth(of index: Int, selectedIndex: Int) -> Int {
        if index == selectedIndex { return 0 }
        return index < selectedIndex ? index + 1 : index
    }

    private var cardsArea: some View {
        let selectedIndex = wallet.styleIndex(for: wallet.currentWallet)
        let count = wallet.wallets.count
        let maxDepth = max(0, count - 1)
        let collapsedHeight = cardHeight + (count > 1 ? 28 : 0)
        // Leque: topos empilhados + o selecionado inteiro embaixo.
        let expandedHeight = CGFloat(maxDepth) * fanPeek + cardHeight

        return ZStack(alignment: .top) {
            ForEach(Array(wallet.wallets.enumerated()), id: \.element.id) { index, item in
                card(item, index: index, selectedIndex: selectedIndex, maxDepth: maxDepth)
            }
        }
        .frame(height: isCardsExpanded ? expandedHeight : collapsedHeight, alignment: .top)
        .padding(.top, count > 1 && !isCardsExpanded ? 28 : 0)
    }

    @ViewBuilder
    private func card(_ item: Wallet, index: Int, selectedIndex: Int, maxDepth: Int) -> some View {
        let isSelected = index == selectedIndex
        let d = depth(of: index, selectedIndex: selectedIndex)

        // Colapsado: selecionado em 0, demais espreitando -14/-28 atrás (clamp em 2).
        // Expandido: maior profundidade no topo (y=0); o selecionado DESCE para o fim do leque —
        // todo mundo apenas desliza para baixo, na mesma ordem visual.
        let yOffset: CGFloat = isCardsExpanded
            ? CGFloat(maxDepth - d) * fanPeek
            : CGFloat(min(d, 2)) * stackPeek
        let scale: CGFloat = isCardsExpanded ? 1 : 1 - CGFloat(min(d, 2)) * 0.05
        // Mais raso (mais abaixo) sempre na frente — MESMA regra nos dois estados (sem flip).
        let z = Double(100 - d)

        WalletCardView(wallet: item, style: .at(index), hidden: wallet.balanceHidden)
            // Saldo no topo direito — visível (fade in) só no leque, onde o corpo fica coberto.
            .overlay(alignment: .topTrailing) {
                Text(wallet.balanceHidden ? "R$ ••••" : item.availableLimit.currencyFromCents())
                    .font(.brand(.callout, weight: .medium)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(Spacing.xl)
                    .opacity(isCardsExpanded ? 1 : 0)
            }
            .scaleEffect(scale)
            .offset(y: yOffset)
            .zIndex(z)
            .onTapGesture {
                if isCardsExpanded {
                    select(index)
                } else if isSelected, wallet.wallets.count > 1 {
                    expand()
                }
            }
            .allowsHitTesting(isCardsExpanded || isSelected)
    }

    // MARK: Payment actions (Pix · Pagar — cada um abre o sheet de opções)

    private var actionGrid: some View {
        HStack(spacing: Spacing.md) {
            actionCard("Pix", kind: .pix) { PixMark(size: 26) }
            actionCard("Pagar", kind: .boleto) {
                Image(systemName: "barcode").font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private func actionCard<Icon: View>(_ title: String, kind: WalletPayOptionsSheet.Kind,
                                        @ViewBuilder icon: () -> Icon) -> some View {
        Button {
            optionsKind = kind
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                icon()
                Spacer(minLength: Spacing.xl)
                Text(title)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 110)
            .padding(Spacing.lg)
            .background(Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Meus orçamentos (faixa com barras 75/90; toque abre o detalhe)

    @ViewBuilder private var budgetsSection: some View {
        if !budgets.overviews.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader("Meus orçamentos") {
                    NavigationLink {
                        BudgetsListView()
                    } label: {
                        Text("Ver todos")
                            .font(.brand(.subheadline, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                }
                VStack(spacing: Spacing.md) {
                    ForEach(budgets.overviews.prefix(2), id: \.membership.id) { pair in
                        NavigationLink {
                            BudgetDetailView(membershipId: pair.membership.id)
                        } label: {
                            BudgetOverviewCard(budget: pair.budget, membership: pair.membership)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyWalletsCard: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "wallet.bifold")
                .font(.system(size: 30)).foregroundStyle(Theme.textTertiary)
            Text("Nenhum cartão disponível")
                .font(.brand(.subheadline, weight: .medium)).foregroundStyle(Theme.textSecondary)
            Text("Solicite acesso a um cartão ao administrador da sua empresa.")
                .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
        .cardSurface()
    }

    // MARK: States + actions

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34)).foregroundStyle(Theme.textTertiary)
            Text(message)
                .font(.brand(.subheadline)).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Tentar novamente") { Task { await wallet.load(force: true) } }
                .buttonStyle(PrimaryActionStyle())
        }
        .padding(Spacing.xl).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Animação do deslize dos cartões (Reduce Motion → transição curta sem molejo).
    private var stackAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.45, dampingFraction: 0.85)
    }

    private func expand() {
        withAnimation(stackAnimation) { isCardsExpanded = true }
    }

    private func collapse() {
        withAnimation(stackAnimation) { isCardsExpanded = false }
    }

    private func select(_ index: Int) {
        guard index < wallet.wallets.count else { return }
        withAnimation(stackAnimation) {
            wallet.selectWallet(wallet.wallets[index].id)
            isCardsExpanded = false
        }
    }
}
