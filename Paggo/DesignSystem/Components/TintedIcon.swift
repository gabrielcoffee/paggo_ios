import SwiftUI

/// SF Symbol inside a tinted circle. Circular sibling of the rounded-square `IconBadge`.
struct TintedIcon: View {
    let symbol: String
    var tint: Color = Theme.accent
    var size: CGFloat = 40             // circle diameter
    var symbolSize: CGFloat? = nil     // defaults to round(size * 0.34)
    var symbolWeight: Font.Weight = .medium
    var opacity: Double = 0.14

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: symbolSize ?? (size * 0.34).rounded(), weight: symbolWeight))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(opacity), in: Circle())
    }
}
