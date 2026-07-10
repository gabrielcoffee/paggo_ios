import Foundation

// Enriquecimento pós-pagamento — espelha o módulo payment-info do wallet-pwa
// (descrição, anexos S3, alocações de custo). Valores em cents; percentuais inteiros (soma 100).

/// Opção de alocação (`GET /configs/projects` · `GET /configs/managerials`).
struct AllocationOption: Codable, Hashable, Sendable, Identifiable {
    let id: String
    var name: String
}

/// Uma linha de alocação de custo de um pagamento.
struct WalletPaymentAllocation: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var projectId: String?
    var managerialId: String?
    var percentage: Int       // 0–100; a soma das linhas deve dar 100

    init(id: String = UUID().uuidString, projectId: String? = nil,
         managerialId: String? = nil, percentage: Int = 0) {
        self.id = id
        self.projectId = projectId
        self.managerialId = managerialId
        self.percentage = percentage
    }
}

/// Anexo de um pagamento (comprovante/nota). No mock o arquivo fica local; no live é URL S3.
struct WalletPaymentAttachment: Codable, Hashable, Sendable, Identifiable {
    let id: String
    var fileName: String
    var createdAt: String     // ISO-8601
    var localURL: URL?
}
