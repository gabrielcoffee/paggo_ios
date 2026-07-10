import SwiftUI

/// Initials avatar generated deterministically from a name — no photo assets needed.
struct OwnerAvatar: View {
    let name: String
    /// Foto de perfil opcional; se carregar, substitui as iniciais.
    var imageURL: String? = nil
    var size: CGFloat = 36
    var ring: Bool = false

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let joined = parts.compactMap { $0.first }.map(String.init).joined().uppercased()
        return joined.isEmpty ? "?" : joined
    }

    /// Deterministic, low-saturation hue from the name so people are distinguishable but sober.
    private var tint: Color {
        let hash = abs(name.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
        let hue = Double(hash % 360) / 360
        return Color(hue: hue, saturation: 0.30, brightness: 0.55)
    }

    private var initialsCircle: some View {
        Circle()
            .fill(tint.opacity(0.35))
            .overlay(
                Text(initials)
                    .font(.brand(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.white)
            )
    }

    var body: some View {
        Group {
            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        initialsCircle  // carregando ou falha → iniciais
                    }
                }
            } else {
                initialsCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(ring ? Theme.accent : Color.white.opacity(0.12), lineWidth: ring ? 1.5 : 1))
    }
}
