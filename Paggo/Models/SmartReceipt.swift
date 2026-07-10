import Foundation

// Contrato do doc 04 (receipts.json). OCR roda on-device (Vision); matching: transações do
// mesmo usuário, valor ±5%, data ±3 dias, sem recibo — exatamente 1 candidata casa sozinha.

/// Recibo fotografado, com leitura OCR e casamento com transação.
struct SmartReceipt: Codable, Hashable, Sendable, Identifiable {
    enum Status: String, Codable, Sendable { case processing, unmatched, matched }

    struct OCR: Codable, Hashable, Sendable {
        struct Confidence: Codable, Hashable, Sendable {
            var merchantName: Double
            var date: Double
            var amount: Double
        }
        var merchantName: String?
        var date: String?
        var amount: Int?
        var confidence: Confidence
    }

    struct Match: Codable, Hashable, Sendable {
        var type: String              // cardTransaction | payment
        var id: String
        var method: String            // auto | manual
    }

    let id: String
    var uploadedBy: PersonRef
    var url: String
    var ocr: OCR?                     // null enquanto processa
    var match: Match?                 // null = sem casamento
    var status: Status
    var createdAt: String
    var updatedAt: String
}
