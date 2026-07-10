import Foundation

/// Cliente da rota de transferência (POST /treasury/v2/execute-transfer). Para mover dinheiro entre
/// contas do grupo usamos o tipo INTERNAL (espelha o SimpleTransfer "entre contas do Grupo" do web).
struct TransferAPI: Sendable {
    let client: APIClient

    @discardableResult
    func executeInternalTransfer(
        originId: String, destinationId: String, amountCents: Int, description: String
    ) async throws -> TransferResult {
        let body = ExecuteTransferRequest(
            transferType: "INTERNAL",
            originBankingAccountId: originId,
            destinationBankingAccountId: destinationId,
            amount: amountCents,
            description: description
        )
        return try await client.send(.post("/treasury/v2/execute-transfer", body: body))
    }
}

struct ExecuteTransferRequest: Encodable, Sendable {
    let transferType: String
    let originBankingAccountId: String
    let destinationBankingAccountId: String
    let amount: Int            // cents
    let description: String
}

/// Resposta tolerante (campos opcionais) de execute-transfer.
struct TransferResult: Decodable, Sendable {
    let status: String?
    let bankTransferId: String?
    let message: String?

    var isConfirmed: Bool { (status ?? "").uppercased() == "CONFIRMED" }
}
