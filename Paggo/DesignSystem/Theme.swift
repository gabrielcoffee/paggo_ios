import SwiftUI

/// Central color & gradient tokens. Every token is an **adaptive** color (light/dark pair) so the
/// whole app follows the user's appearance setting automatically — no per-view changes needed.
/// Swap the accent here to rebrand.
enum Theme {
    // MARK: Adaptive helpers
    /// Builds a dynamic color from a light + dark variant (resolved per trait at render time).
    private static func adaptive(_ light: Color, _ dark: Color) -> Color {
        let l = UIColor(light)
        let d = UIColor(dark)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? d : l })
    }

    private static func hex(_ light: String, _ dark: String) -> Color {
        adaptive(Color(hex: light), Color(hex: dark))
    }

    // MARK: Surfaces (Paggo zinc dark · soft off-white light)
    static let base = hex("#F5F5F7", "#0C0C0E")          // app background
    static let surface = hex("#FFFFFF", "#18181B")       // elevated card
    static let surfaceHigh = hex("#ECECEF", "#232327")   // higher elevation / inputs
    static let stroke = adaptive(.black.opacity(0.10), .white.opacity(0.08))
    static let separator = adaptive(.black.opacity(0.08), .white.opacity(0.07))

    // MARK: Brand accent (Paggo rust / terracotta — deepened in light for contrast)
    static let accent = hex("#B0572C", "#C2693E")        // brand terracotta
    static let accentDeep = hex("#8A4220", "#9A4A22")    // branded default rust
    static let accentSoft = hex("#C77E54", "#D99B73")    // brick-500 light terracotta

    // MARK: Semantics (deepened in light mode for legibility on white)
    static let positive = hex("#1E9E55", "#34B36A")      // success — inflow / approved
    static let negative = hex("#CB3D2E", "#E0564A")      // danger — outflow / failed
    static let warning = hex("#A9780C", "#D2A02E")       // gold
    static let info = hex("#2F6FBF", "#4F8BD9")          // blue — informational tags
    static let textPrimary = adaptive(Color(hex: "#1A1A1E"), .white)
    static let textSecondary = adaptive(.black.opacity(0.58), .white.opacity(0.60))
    static let textTertiary = adaptive(.black.opacity(0.42), .white.opacity(0.34))

    // MARK: Neutral styling (monochrome — no per-category hues)
    static let neutralIcon = hex("#6B6B73", "#C2C0CC")
    static let neutralFill = adaptive(.black.opacity(0.55), .white.opacity(0.72))   // default progress fill
    static let neutralTrack = adaptive(.black.opacity(0.08), .white.opacity(0.07))

    /// Monochrome (very lightly violet-tinted) ramp for separating chart series.
    static func shade(_ index: Int, of count: Int) -> Color {
        guard count > 1 else {
            return adaptive(Color(hue: 0.70, saturation: 0.10, brightness: 0.50),
                            Color(hue: 0.70, saturation: 0.08, brightness: 0.80))
        }
        let t = Double(index) / Double(count - 1)
        return adaptive(Color(hue: 0.70, saturation: 0.10, brightness: 0.55 - t * 0.30),
                        Color(hue: 0.70, saturation: 0.08, brightness: 0.88 - t * 0.52))
    }

    // MARK: Gradients (built from the adaptive tokens — resolve per scheme)
    /// Hero header gradient bleeding from accent into the base — the Revolut vibe.
    static let heroGradient = LinearGradient(
        colors: [accentDeep.opacity(0.55), base.opacity(0.0)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let accentGradient = LinearGradient(
        colors: [accentSoft, accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Very subtle top glow — sober; tint padrão = accent, telas da Carteira passam a cor do cartão.
    static func aurora(tint: Color? = nil) -> RadialGradient {
        let c = tint ?? accent
        return RadialGradient(
            colors: [c.opacity(0.16), c.opacity(0.05), .clear],
            center: .top,
            startRadius: 8,
            endRadius: 460
        )
    }

    /// Very subtle top glow — sober, restrained use of accent.
    static let auroraGradient = aurora()

    static func categoryGradient(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .top, endPoint: .bottom)
    }
}
