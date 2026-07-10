import SwiftUI

/// Linha de aprovadores: avatares sobrepostos (foto ou iniciais reais) + contagem.
/// Payloads antigos (só `userId`, sem dados de usuário) mostram apenas a contagem —
/// nunca avatares placeholder.
struct ApproversRow: View {
    let approvers: [PackageApprover]
    var compact: Bool = false

    private var approversWithUser: [PackageApprover] {
        approvers.filter { $0.user != nil }
    }

    private var countLabel: String {
        approvers.count == 1 ? "1 aprovador" : "\(approvers.count) aprovadores"
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if !approversWithUser.isEmpty {
                HStack(spacing: -10) {
                    ForEach(Array(approversWithUser.prefix(4))) { approver in
                        OwnerAvatar(name: approver.name,
                                    imageURL: approver.user?.image,
                                    size: compact ? 24 : 28,
                                    ring: approver.hasApproved)
                            .overlay(alignment: .bottomTrailing) {
                                if approver.hasApproved {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: compact ? 9 : 11))
                                        .foregroundStyle(Theme.positive)
                                        .background(Circle().fill(Theme.base))
                                }
                            }
                    }
                }
            }
            Text(countLabel)
                .font(.brand(.caption2, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
