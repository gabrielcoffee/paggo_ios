import SwiftUI

/// Folha de ordenação: campo + direção.
struct SortSheet: View {
    @Binding var field: SortField
    @Binding var direction: SortDirection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    GlassCard(padding: Spacing.sm) {
                        VStack(spacing: 0) {
                            ForEach(Array(SortField.allCases.enumerated()), id: \.element.id) { index, option in
                                Button {
                                    withAnimation(.snappy) { field = option }
                                } label: {
                                    HStack {
                                        Text(option.rawValue)
                                            .font(.brand(.subheadline, weight: .medium))
                                            .foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                        if field == option {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(Theme.accent)
                                        }
                                    }
                                    .padding(Spacing.md)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if index < SortField.allCases.count - 1 {
                                    Divider().overlay(Theme.separator)
                                }
                            }
                        }
                    }

                    Picker("Direção", selection: $direction) {
                        Text("Crescente").tag(SortDirection.ascending)
                        Text("Decrescente").tag(SortDirection.descending)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }
            .screenBackground()
            .navigationTitle("Ordenar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pronto") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
