import SwiftUI

/// Section title row. Supports a prominent bold title with an inline chevron (tappable) — the
/// pattern used on the home screen — plus an optional subtitle and trailing accessory.
struct SectionHeader<Accessory: View>: View {
    let title: String
    var subtitle: String?
    var chevron: Bool = false
    var prominent: Bool = false
    var onTap: (() -> Void)?
    @ViewBuilder var accessory: Accessory

    init(_ title: String,
         subtitle: String? = nil,
         chevron: Bool = false,
         prominent: Bool = false,
         onTap: (() -> Void)? = nil,
         @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.chevron = chevron
        self.prominent = prominent
        self.onTap = onTap
        self.accessory = accessory()
    }

    private var titleFont: Font {
        (prominent || chevron) ? .brand(size: 18, weight: .medium) : .sectionTitle
    }

    private var titleRow: some View {
        HStack(spacing: 5) {
            Text(title).font(titleFont).foregroundStyle(Theme.textPrimary)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let onTap {
                    Button(action: onTap) { titleRow }.buttonStyle(.plain)
                } else {
                    titleRow
                }
                if let subtitle {
                    Text(subtitle).font(.label).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            accessory
        }
    }
}
