import SwiftUI

/// A `Menu`-backed select field rendered on the app input surface, with a trailing chevron.
struct MenuSelectField<Item: Hashable>: View {
    let selection: Item
    let options: [Item]
    let title: (Item) -> String
    var onSelect: (Item) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { item in
                Button(title(item)) { onSelect(item) }
            }
        } label: {
            HStack {
                Text(title(selection))
                    .font(.brand(.subheadline))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .inputSurface()
        }
    }
}
