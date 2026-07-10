import SwiftUI

/// Paggo brand typography. App face is "ABC Camera Plain" (bundled) — o mesmo neo-grotesco do
/// design web. Pesos são instâncias estáticas (400/500/600/700) da fonte variável. Todo texto do
/// app passa por `Font.brand`. Títulos da nav bar usam serifa (ver `App/PaggoApp.swift`).
extension Font {
    /// Brand font at a Dynamic-Type text style.
    static func brand(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom(Self.brandName(weight), size: Self.brandSize(style), relativeTo: style)
    }

    /// Brand font at a fixed point size (for large display numbers).
    static func brand(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(Self.brandName(weight), size: size)
    }

    /// Peso → família ABC Camera Plain. A fonte não desce abaixo de 400, então pesos mais finos que
    /// Regular (light/thin) caem para Regular. Referencia pelo *PostScript name* de cada instância.
    private static func brandName(_ weight: Font.Weight) -> String {
        switch weight {
        case .black, .heavy, .bold: return "ABCCameraPlain-Bold"
        case .semibold: return "ABCCameraPlain-SemiBold"
        case .medium: return "ABCCameraPlain-Medium"
        default: return "ABCCameraPlain-Regular"
        }
    }

    private static func brandSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 32
        case .title: return 27
        case .title2: return 21
        case .title3: return 19
        case .headline, .body, .callout: return 16
        case .subheadline: return 14
        case .footnote: return 12
        case .caption: return 11
        case .caption2: return 10
        default: return 16
        }
    }

    // MARK: Named tokens (thin/elegant display numbers)
    static let displayNumber = Font.brand(size: 46, weight: .light)
    static let heroNumber = Font.brand(size: 36, weight: .light)
    static let titleNumber = Font.brand(size: 21, weight: .regular)
    static let screenTitle = Font.brand(.largeTitle, weight: .medium)
    static let sectionTitle = Font.brand(.headline, weight: .medium)
    static let cardTitle = Font.brand(.subheadline, weight: .medium)
    static let label = Font.brand(.footnote, weight: .medium)
}

extension Text {
    func screenTitleStyle() -> some View {
        self.font(.screenTitle).foregroundStyle(Theme.textPrimary)
    }
    func sectionTitleStyle() -> some View {
        self.font(.sectionTitle).foregroundStyle(Theme.textPrimary)
    }
    func secondaryLabel() -> some View {
        self.font(.label).foregroundStyle(Theme.textSecondary)
    }
}
