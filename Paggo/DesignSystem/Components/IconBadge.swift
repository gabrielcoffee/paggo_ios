import SwiftUI

/// Rounded-square icon tile with an SF Symbol. Neutral tint by default.
struct IconBadge: View {
    let symbol: String
    var color: Color = Theme.neutralIcon
    var size: CGFloat = 42

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(color.opacity(0.16))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(color)
            )
    }
}
