import SwiftUI

// Building blocks for the package-details screen. Editorial / borderless language: sections are
// delineated by a labelled hairline rule (not boxes), content sits on the screen canvas.

/// Cabeçalho de seção: ícone + rótulo em caixa-alta + régua fina até a borda.
struct DetailSectionHeader: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            Text(title.uppercased())
                .font(.brand(.caption2, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.textSecondary)
            Rectangle()
                .fill(Theme.separator)
                .frame(height: 1)
        }
    }
}

/// Seção sem moldura: cabeçalho com régua + conteúdo direto sobre o fundo.
struct DetailSection<Content: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder var content: Content

    init(_ title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            DetailSectionHeader(title: title, systemImage: systemImage)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Campo rotulado (caption em caixa-alta + valor), com fallback "—".
struct DetailInfoField: View {
    let caption: String
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(caption.uppercased())
                .font(.brand(.caption2, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)
            Text(value?.isEmpty == false ? value! : "—")
                .font(.brand(.subheadline))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Badge pílula com a variante semântica (espelha components/ui/Badge).
struct DetailBadge: View {
    let label: String
    var variant: BadgeVariant = .neutral

    var body: some View {
        Text(label)
            .font(.brand(.caption2, weight: .semibold))
            .foregroundStyle(variant.color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 3)
            .background(variant.color.opacity(0.16), in: Capsule())
            .overlay(Capsule().stroke(variant.color.opacity(0.28), lineWidth: 1))
    }
}

/// Segmento de uma barra de progresso (fração 0–1).
struct ProgressSegmentSpec {
    var fraction: Double
    var color: Color
    var label: String
}

/// Barra de progresso multi-segmento com legenda opcional (espelha ProgressBar.tsx).
struct MiniProgressBar: View {
    let segments: [ProgressSegmentSpec]
    var height: CGFloat = 6
    var showLegend: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.neutralTrack)
                    ForEach(Array(segments.enumerated()).sorted { $0.element.fraction > $1.element.fraction }, id: \.offset) { _, seg in
                        Capsule()
                            .fill(seg.color)
                            .frame(width: geo.size.width * min(max(seg.fraction, 0), 1))
                    }
                }
            }
            .frame(height: height)

            if showLegend {
                HStack(spacing: Spacing.md) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                        HStack(spacing: 4) {
                            Circle().fill(seg.color).frame(width: 7, height: 7)
                            Text(seg.label)
                                .font(.brand(.caption2))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
        }
    }
}

/// Aba do detalhe (chave + título + contador opcional).
struct DetailTab: Identifiable, Equatable {
    let key: String
    let title: String
    var badge: Int?
    var badgeVariant: BadgeVariant = .neutral
    var id: String { key }
}

/// Barra de abas com indicador sublinhado (estilo editorial, sem pílulas).
struct DetailTabBar: View {
    let tabs: [DetailTab]
    @Binding var selection: String
    @Namespace private var ns

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xl) {
                ForEach(tabs) { tab in chip(tab) }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .scrollClipDisabled()
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.separator).frame(height: 1)
        }
    }

    private func chip(_ tab: DetailTab) -> some View {
        let isSelected = tab.key == selection
        let badgeColor: Color = tab.badgeVariant == .danger
            ? Theme.negative
            : (isSelected ? Theme.accent : Theme.textTertiary)
        return Button {
            withAnimation(.snappy) { selection = tab.key }
        } label: {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: 5) {
                    Text(tab.title)
                        .font(.brand(.body, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    if let badge = tab.badge, badge > 0 {
                        Text("\(badge)")
                            .font(.brand(.caption, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(badgeColor)
                    }
                }
                ZStack {
                    if isSelected {
                        Capsule().fill(Theme.accent).frame(height: 3)
                            .matchedGeometryEffect(id: "detailUnderline", in: ns)
                    } else {
                        Color.clear.frame(height: 3)
                    }
                }
            }
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
