import CoreGraphics

/// Spacing scale (4pt base).
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let xxxl: CGFloat = 40
    /// Espaço entre seções (telas editoriais sem moldura).
    static let section: CGFloat = 34
}

/// Corner radius scale — tightened to match Paggo's design system (base radius ~8px,
/// controls near-square). Cards are noticeably less rounded than typical Material.
enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 7
    static let lg: CGFloat = 9    // cards (less round)
    static let xl: CGFloat = 11   // hero
    static let pill: CGFloat = 999
}
