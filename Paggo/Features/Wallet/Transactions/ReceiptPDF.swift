import PDFKit
import UIKit

/// Gera um comprovante em PDF (A4) de um pagamento da carteira, para compartilhar nativamente.
/// Espelha o comprovante do apps/wallet-pwa (recebedor, pagador, IDs). Valores em cents.
enum ReceiptPDF {
    private static let pageSize = CGSize(width: 595, height: 842)   // A4 @72dpi
    private static let margin: CGFloat = 40

    static func make(for detail: WalletPaymentDetail) -> URL? {
        let payment = detail.payment
        let receipt = detail.receipt
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            y = drawHeader(at: y)
            y += 8
            y = draw(text: "Comprovante de pagamento", at: y, font: .systemFont(ofSize: 18, weight: .bold))
            y += 4
            y = draw(text: "Paggo Pagamentos LTDA · CNPJ 38.176.589/0001-89",
                     at: y, font: .systemFont(ofSize: 9), color: .secondaryLabel)
            y += 16

            y = drawAmountBlock(payment: payment, at: y)
            y += 12

            y = drawRule(at: y)
            y = drawSection("Recebedor", rows: [
                ("Nome", receipt.creditName),
                ("CPF/CNPJ", receipt.creditTaxId),
                ("Instituição", receipt.creditBankName),
                ("Agência", receipt.creditBranch),
                ("Conta", receipt.creditAccount),
            ], at: y)

            y = drawRule(at: y)
            y = drawSection("Pagador", rows: [
                ("Nome", receipt.debitName),
                ("CPF/CNPJ", receipt.debitTaxId),
                ("Instituição", receipt.debitBankName),
                ("Agência", receipt.debitBranch),
                ("Conta", receipt.debitAccount),
            ], at: y)

            y = drawRule(at: y)
            y = drawSection("Detalhes da transação", rows: transactionRows(payment: payment, receipt: receipt), at: y)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("comprovante-\(payment.id).pdf")
        do { try data.write(to: url, options: .atomic); return url }
        catch { return nil }
    }

    // MARK: Sections

    private static func transactionRows(payment: WalletPayment, receipt: WalletReceipt) -> [(String, String?)] {
        var rows: [(String, String?)] = [
            ("Método", payment.method.label),
            ("Status", payment.status.label),
            ("Data", DateText.full(payment.createdAt)),
            ("Valor", payment.amount.currencyFromCents()),
        ]
        if let e2e = receipt.endToEndId { rows.append(("ID da transação (E2E)", e2e)) }
        if let line = receipt.digitableLine { rows.append(("Linha digitável", line)) }
        if let auth = receipt.authenticationData { rows.append(("Autenticação", auth)) }
        return rows
    }

    // MARK: Primitives

    private static func drawHeader(at y: CGFloat) -> CGFloat {
        draw(text: "PAGGO", at: y, font: .systemFont(ofSize: 22, weight: .heavy),
             color: UIColor(red: 0.76, green: 0.41, blue: 0.24, alpha: 1))
    }

    private static func drawAmountBlock(payment: WalletPayment, at y: CGFloat) -> CGFloat {
        var cursor = draw(text: "VALOR", at: y, font: .systemFont(ofSize: 9, weight: .semibold),
                          color: .tertiaryLabel)
        cursor = draw(text: payment.amount.currencyFromCents(), at: cursor,
                      font: .monospacedDigitSystemFont(ofSize: 28, weight: .bold))
        return cursor
    }

    private static func drawSection(_ title: String, rows: [(String, String?)], at y: CGFloat) -> CGFloat {
        var cursor = draw(text: title.uppercased(), at: y + 6,
                          font: .systemFont(ofSize: 10, weight: .bold), color: .secondaryLabel)
        cursor += 2
        for (label, value) in rows {
            cursor = drawRow(label: label, value: value ?? "—", at: cursor)
        }
        return cursor + 6
    }

    private static func drawRow(label: String, value: String, at y: CGFloat) -> CGFloat {
        let contentWidth = pageSize.width - margin * 2
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.secondaryLabel,
        ]
        (label as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttr)

        let valueAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: UIColor.label,
        ]
        let valueWidth = contentWidth * 0.62
        let valueX = margin + contentWidth - valueWidth
        let rect = CGRect(x: valueX, y: y, width: valueWidth, height: 200)
        let bounding = (value as NSString).boundingRect(
            with: CGSize(width: valueWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin], attributes: valueAttr, context: nil)
        let style = NSMutableParagraphStyle(); style.alignment = .right
        var attrs = valueAttr; attrs[.paragraphStyle] = style
        (value as NSString).draw(in: rect, withAttributes: attrs)
        return y + max(16, bounding.height + 6)
    }

    @discardableResult
    private static func draw(text: String, at y: CGFloat, font: UIFont,
                             color: UIColor = .label) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
        return y + font.lineHeight + 2
    }

    private static func drawRule(at y: CGFloat) -> CGFloat {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y + 4))
        path.addLine(to: CGPoint(x: pageSize.width - margin, y: y + 4))
        UIColor.separator.setStroke(); path.lineWidth = 0.5; path.stroke()
        return y + 12
    }
}
