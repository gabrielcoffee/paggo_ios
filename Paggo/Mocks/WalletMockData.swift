import Foundation

/// Seed do extrato + helpers do mock da Carteira. As carteiras e os shapes transacionais vêm de
/// fixtures JSON (`Resources/WalletFixtures/`, ver MockWalletRepository); aqui fica só o que não
/// tem sample de contrato: a variedade do extrato e a síntese do comprovante.
enum WalletMockData {
    /// Extrato inicial por carteira (o MockWalletRepository muta a partir daqui).
    static let seedPayments: [String: [WalletPayment]] = [
        "wal-1": [
            WalletPayment(id: "wp-1", amount: 152_90, receiverName: "Materiais & Cia LTDA",
                          receiverTaxId: "12.345.678/0001-90", method: .qrCode, status: .confirmed,
                          createdAt: iso(daysAgo: 0, hour: 9, minute: 12), released: true,
                          hasAttachments: true, allocationPending: false),
            WalletPayment(id: "wp-2", amount: 89_00, receiverName: "Padaria do Zé",
                          receiverTaxId: "987.654.321-00", method: .key, status: .confirmed,
                          createdAt: iso(daysAgo: 0, hour: 8, minute: 3), released: true,
                          hasAttachments: false, allocationPending: true),
            WalletPayment(id: "wp-3", amount: 1_240_00, receiverName: "Concreto Forte S.A.",
                          receiverTaxId: "45.678.901/0001-23", method: .barcode, status: .confirmed,
                          createdAt: iso(daysAgo: 1, hour: 16, minute: 40), released: true,
                          hasAttachments: true, allocationPending: false),
            WalletPayment(id: "wp-4", amount: 35_50, receiverName: "Posto Avenida",
                          receiverTaxId: "23.456.789/0001-12", method: .qrCode, status: .failed,
                          createdAt: iso(daysAgo: 2, hour: 11, minute: 5), released: false,
                          hasAttachments: false, allocationPending: false),
            WalletPayment(id: "wp-5", amount: 520_00, receiverName: "Elétrica União",
                          receiverTaxId: "34.567.890/0001-45", method: .key, status: .confirmed,
                          createdAt: iso(daysAgo: 5, hour: 14, minute: 22), released: true,
                          hasAttachments: false, allocationPending: false),
        ],
        "wal-2": [
            WalletPayment(id: "wp-6", amount: 76_30, receiverName: "Ferragens Central",
                          receiverTaxId: "56.789.012/0001-67", method: .barcode, status: .confirmed,
                          createdAt: iso(daysAgo: 1, hour: 10, minute: 0), released: true,
                          hasAttachments: true, allocationPending: false),
        ],
        "wal-3": [],
    ]

    /// Detalhe (comprovante) mock — preenche recebedor/pagador e IDs por método.
    static func detail(for payment: WalletPayment, payerName: String? = nil) -> WalletPaymentDetail {
        var receipt = WalletReceipt()
        receipt.creditName = payment.receiverName
        receipt.creditTaxId = payment.receiverTaxId
        receipt.creditBankName = "Itaú Unibanco"
        receipt.creditBranch = "0001"
        receipt.creditAccount = "12345-6"
        receipt.debitName = payerName ?? "Construtora Alfa S.A."
        receipt.debitTaxId = "11.222.333/0001-44"
        receipt.debitBankName = "Paggo (Celcoin)"
        receipt.debitBranch = "0001"
        receipt.debitAccount = "98765-0"

        switch payment.method {
        case .key, .qrCode:
            receipt.endToEndId = "E18236120\(payment.id.suffix(8))202606301200ABCDEF"
        case .barcode:
            receipt.digitableLine = "34191.79001 01043.510047 91020.150008 1 99980000\(payment.amount)"
            receipt.authenticationData = "A1B2C3D4E5F6"
            receipt.assignor = payment.receiverName
            receipt.originalAmount = payment.amount
            receipt.dueDate = payment.createdAt
            receipt.fineAmount = 0
            receipt.interestAmount = 0
            receipt.discountAmount = 0
        }
        return WalletPaymentDetail(payment: payment, receipt: receipt)
    }

    static func iso(daysAgo: Int, hour: Int, minute: Int) -> String {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let day = cal.date(byAdding: .day, value: -daysAgo, to: startOfDay) ?? startOfDay
        let date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    static func isoNow() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: Date())
    }
}
