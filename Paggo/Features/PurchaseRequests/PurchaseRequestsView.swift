import SwiftUI

/// Purchase requests — overview of requests (Payment / Reimbursement / Purchase): open summary,
/// breakdown by type, status toggle and the list. The "+" button opens the type selector + creation.
struct PurchaseRequestsView: View {
    @Environment(PurchaseRequestsStore.self) private var store
    @Environment(AuthStore.self) private var auth
    @State private var showCreate = false
    @State private var revealedForSession = false

    /// Paggo staff (email `@paggo.ai`) may bypass the "coming soon" gate for the session.
    private var isPaggoUser: Bool {
        let email = (auth.activeUser ?? auth.savedUser)?.email.lowercased()
        return email?.hasSuffix("@paggo.ai") == true
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    summaryHero
                    typeSummary
                    sectionSeparator
                    statusSegment
                    requestsList
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .screenBackground()
            .blur(radius: revealedForSession ? 0 : 16)
            .allowsHitTesting(revealedForSession)
            .accessibilityHidden(!revealedForSession)
            .overlay {
                if !revealedForSession {
                    gateOverlay
                }
            }
            .navigationTitle("Solicitações")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!revealedForSession)
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateRequestSheet { store.add($0) }
            }
            .task {
                // Debug: PAGGO_NEW_REQUEST=compra opens the creation selector (UI verification).
                if ProcessInfo.processInfo.environment["PAGGO_NEW_REQUEST"] == "compra" {
                    showCreate = true
                }
            }
        }
    }

    // MARK: Open summary

    private var summaryHero: some View {
        VStack(spacing: Spacing.sm) {
            Text("Em aberto")
                .font(.brand(.subheadline, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Text(store.openTotalCents.currencyFromCents())
                .font(.heroNumber)
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(store.openCount) solicitações aguardando")
                .font(.brand(.caption))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.md)
    }

    // MARK: Breakdown by type (open)

    private var typeSummary: some View {
        HStack(spacing: 0) {
            ForEach(Array(RequestType.allCases.enumerated()), id: \.element.id) { index, type in
                typeColumn(type)
                if index < RequestType.allCases.count - 1 {
                    Divider().frame(height: 46).overlay(Theme.separator)
                }
            }
        }
    }

    private func typeColumn(_ type: RequestType) -> some View {
        VStack(spacing: Spacing.xs) {
            TintedIcon(symbol: type.icon, tint: type.tint, size: 30, symbolSize: 13)
            Text("\(store.openCount(type: type))")
                .font(.brand(.title3, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text(type.label)
                .font(.brand(.caption2))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Status segment

    private var statusSegment: some View {
        @Bindable var store = store
        return SegmentedControl(selection: $store.selectedStatus, options: RequestStatus.allCases,
                                label: { $0.segmentLabel })
    }

    // MARK: List

    private var requestsList: some View {
        let items = store.filtered
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            if items.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, req in
                        RequestRow(request: req)
                        if index < items.count - 1 {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("Nenhuma solicitação \(store.selectedStatus.label.lowercased())")
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxxl)
    }

    private var sectionSeparator: some View { Divider().overlay(Theme.separator) }

    // MARK: Coming-soon gate

    private var gateOverlay: some View {
        ZStack {
            Theme.base.opacity(0.2)
                .ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                Image(systemName: "hourglass")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.accent)
                Text("Disponível em Breve")
                    .font(.brand(.title3, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Esta seção estará disponível em breve.")
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                if isPaggoUser {
                    Button {
                        withAnimation(.smooth) { revealedForSession = true }
                    } label: {
                        Text("Ver mesmo assim (apenas Paggo)")
                            .padding(.horizontal, Spacing.lg)
                    }
                    .buttonStyle(PrimaryActionStyle())
                    .padding(.top, Spacing.xs)
                }
            }
            .padding(Spacing.xl)
        }
    }

}

/// Creation sheet: first the type selector (Payment/Reimbursement/Purchase); on selection,
/// swaps the content to the matching flow (avoids the popover→sheet presentation conflict).
struct CreateRequestSheet: View {
    var onComplete: (PurchaseRequest) -> Void
    @State private var chosen: RequestType?

    var body: some View {
        if let chosen {
            NewRequestFlow(type: chosen, onComplete: onComplete)
        } else {
            chooser
        }
    }

    private var chooser: some View {
        SheetScaffold(title: "Nova solicitação", closePlacement: .topBarLeading,
                      detents: [.medium, .large]) {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    Text("O que você quer solicitar?")
                        .font(.brand(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(RequestType.allCases) { type in
                        Button { chosen = type } label: { typeCard(type) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }

    private func typeCard(_ type: RequestType) -> some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: type.icon, tint: type.tint, size: 44, symbolSize: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(type.label)
                    .font(.brand(.body, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(type.blurb)
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }
}

/// A single request row in the list.
struct RequestRow: View {
    let request: PurchaseRequest

    var body: some View {
        HStack(spacing: Spacing.md) {
            TintedIcon(symbol: request.type.icon, tint: request.type.tint, size: 38, symbolSize: 15)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.title)
                    .font(.brand(.body, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(request.requester) · \(request.costCenter)")
                    .font(.brand(.caption))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.md)
            VStack(alignment: .trailing, spacing: 2) {
                Text(request.amountCents.currencyFromCents())
                    .font(.brand(.body, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(DateText.withMonth(request.date))
                    .font(.brand(.caption2))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }
}
