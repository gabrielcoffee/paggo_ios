import SwiftUI

/// Placeholder de carregamento com brilho animado (shimmer). Substitui spinners para que o
/// carregamento pareça mais rápido (o layout já aparece). Respeita Reduce Motion.
struct Skeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var cornerRadius: CGFloat = Radius.sm

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.surfaceHigh)
            .frame(width: width, height: height)
            .shimmer()
    }
}

/// Modificador de shimmer reutilizável (uma faixa clara percorrendo o conteúdo).
extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }

    /// Aplica o efeito a um placeholder genérico (ex.: formas customizadas).
    func skeletonFill() -> some View {
        foregroundStyle(Theme.surfaceHigh).shimmer()
    }
}

private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(0.6)
        } else {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.18), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width * 1.6)
                    }
                )
                .clipped()
                .onAppear {
                    withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

/// Card de skeleton no formato de um PackageCardView (lista de pagamentos / aprovações).
struct PackageCardSkeleton: View {
    var showApprovers: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Skeleton(width: 150, height: 15)
                Spacer()
                Skeleton(width: 70, height: 18, cornerRadius: Radius.pill)
            }
            Skeleton(width: 110, height: 11)
            Skeleton(width: 130, height: 22)
            HStack {
                if showApprovers { Skeleton(width: 90, height: 24, cornerRadius: Radius.pill) }
                Spacer()
                Skeleton(width: 64, height: 11)
            }
        }
        .padding(Spacing.lg)
        .cardSurface(cornerRadius: Radius.lg)
    }
}

/// Lista de skeletons de cards (lista de pagamentos / aprovações).
struct PackageListSkeleton: View {
    var count: Int = 6
    var showApprovers: Bool = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0..<count, id: \.self) { _ in
                PackageCardSkeleton(showApprovers: showApprovers)
            }
        }
    }
}

/// Skeleton de uma seção do detalhe (cabeçalho + linhas).
struct DetailSectionSkeleton: View {
    var lines: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Skeleton(width: 120, height: 11)
            ForEach(0..<lines, id: \.self) { _ in
                HStack(spacing: Spacing.lg) {
                    Skeleton(height: 13)
                    Skeleton(height: 13)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
