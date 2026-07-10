import Foundation
import UIKit
import Vision

/// Leitura de recibo no próprio aparelho (doc 04 regra 5) — sem serviço externo.
/// Heurísticas: valor = maior quantia monetária; data = primeiro padrão de data;
/// estabelecimento = primeira linha não-numérica. Confiança por campo vem do Vision.
enum ReceiptOCR {
    static func read(_ image: UIImage) async -> SmartReceipt.OCR {
        guard let cgImage = image.cgImage else {
            return SmartReceipt.OCR(merchantName: nil, date: nil, amount: nil,
                                    confidence: .init(merchantName: 0, date: 0, amount: 0))
        }
        let lines: [(text: String, confidence: Double)] = await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let result = observations.compactMap { obs -> (String, Double)? in
                    guard let top = obs.topCandidates(1).first else { return nil }
                    return (top.string, Double(top.confidence))
                }
                continuation.resume(returning: result)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["pt-BR"]
            request.usesLanguageCorrection = true
            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(cgImage: cgImage)
                if (try? handler.perform([request])) == nil {
                    continuation.resume(returning: [])
                }
            }
        }
        return extract(from: lines)
    }

    /// Aplica as heurísticas sobre as linhas reconhecidas.
    static func extract(from lines: [(text: String, confidence: Double)]) -> SmartReceipt.OCR {
        var bestAmount: (cents: Int, confidence: Double)?
        var firstDate: (iso: String, confidence: Double)?
        var merchant: (name: String, confidence: Double)?

        let amountRegex = try? NSRegularExpression(
            pattern: #"(?:R\$\s*)?(\d{1,3}(?:\.\d{3})*|\d+),(\d{2})\b"#)
        let dateRegex = try? NSRegularExpression(
            pattern: #"\b(\d{2})/(\d{2})/(\d{4}|\d{2})\b"#)

        for line in lines {
            let text = line.text
            let range = NSRange(text.startIndex..., in: text)

            if let matches = amountRegex?.matches(in: text, range: range) {
                for match in matches {
                    guard let intRange = Range(match.range(at: 1), in: text),
                          let fracRange = Range(match.range(at: 2), in: text) else { continue }
                    let intPart = text[intRange].replacingOccurrences(of: ".", with: "")
                    let cents = (Int(intPart) ?? 0) * 100 + (Int(text[fracRange]) ?? 0)
                    if cents > (bestAmount?.cents ?? -1) {
                        bestAmount = (cents, line.confidence)
                    }
                }
            }

            if firstDate == nil, let match = dateRegex?.firstMatch(in: text, range: range),
               let dayRange = Range(match.range(at: 1), in: text),
               let monthRange = Range(match.range(at: 2), in: text),
               let yearRange = Range(match.range(at: 3), in: text) {
                var year = String(text[yearRange])
                if year.count == 2 { year = "20\(year)" }
                firstDate = ("\(year)-\(text[monthRange])-\(text[dayRange])", line.confidence)
            }

            if merchant == nil {
                let letters = text.filter(\.isLetter).count
                if letters >= 4 && letters > text.filter(\.isNumber).count {
                    merchant = (text.trimmingCharacters(in: .whitespaces), line.confidence)
                }
            }
        }

        return SmartReceipt.OCR(
            merchantName: merchant?.name,
            date: firstDate?.iso,
            amount: bestAmount?.cents,
            confidence: .init(merchantName: merchant?.confidence ?? 0,
                              date: firstDate?.confidence ?? 0,
                              amount: bestAmount?.confidence ?? 0)
        )
    }
}
