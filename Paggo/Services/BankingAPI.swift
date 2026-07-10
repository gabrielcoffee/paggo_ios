import Foundation

// Live banking data layer — maps the mobile-api treasury endpoints to the app's models.
//   GET /treasury/v2/banking-accounts            → accounts + balances (Treasury.getBankingAccounts)
//   GET /treasury/banking-accounts/balance-history → consolidated group balance history (new)

struct BankingAPI: Sendable {
    let client: APIClient

    func accounts() async throws -> [BankAccount] {
        // `includeBalance` defaults to false server-side — must opt in, else `balance` is omitted.
        let response: RemoteBankingAccountsResponse = try await client.send(
            .get("/treasury/v2/banking-accounts", query: [
                URLQueryItem(name: "includeBalance", value: "true"),
                URLQueryItem(name: "isActive", value: "true"),
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "pageSize", value: "100"),
            ])
        )
        return response.data.map { $0.toBankAccount() }
    }

    func consolidatedBalanceHistory(startDate: String, endDate: String) async throws -> [BalanceHistoryPoint] {
        let response: RemoteBalanceHistoryResponse = try await client.send(
            .get("/treasury/banking-accounts/balance-history", query: [
                URLQueryItem(name: "startDate", value: startDate),
                URLQueryItem(name: "endDate", value: endDate),
            ])
        )
        return response.data.map { BalanceHistoryPoint(date: $0.date, balance: Int($0.balance.rounded())) }
    }

    /// Transações bancárias no intervalo. `bankingAccountId` opcional → nil consolida todas as contas.
    func transactions(startDate: String, endDate: String,
                      bankingAccountId: String? = nil, page: Int = 1) async throws -> [BankTransaction] {
        var query = [
            URLQueryItem(name: "startDate", value: startDate),
            URLQueryItem(name: "endDate", value: endDate),
            URLQueryItem(name: "page", value: String(page)),
        ]
        if let bankingAccountId {
            query.append(URLQueryItem(name: "bankingAccountId", value: bankingAccountId))
        }
        let response: RemoteTransactionsResponse = try await client.send(
            .get("/treasury/banking-accounts/transactions", query: query)
        )
        return response.data.map { $0.toBankTransaction() }
    }

    /// Próximos pagamentos agendados (GET /packages/upcoming). Já vem ordenado ascendente pelo backend.
    func upcomingPayments(limit: Int = 7) async throws -> [UpcomingPayment] {
        let response: RemoteUpcomingResponse = try await client.send(
            .get("/packages/upcoming", query: [URLQueryItem(name: "limit", value: String(limit))])
        )
        return response.data.map { $0.toUpcomingPayment() }
    }
}

// MARK: - DTOs (mirror @paggo/treasury-service shapes)

struct RemoteBalanceHistoryResponse: Decodable, Sendable {
    struct Point: Decodable, Sendable { let date: String; let balance: Double }
    let data: [Point]
}

// MARK: Transactions

struct RemoteTransactionsResponse: Decodable, Sendable {
    let data: [RemoteBankTransaction]
}

/// Decodifica de forma tolerante: categoria desconhecida → `.other`, `balanceAfter` ausente → nil,
/// campos extras/ausentes de uma API antiga não quebram o parse.
struct RemoteBankTransaction: Decodable, Sendable {
    let id: String
    let accountId: String
    let type: BankTransactionType
    let category: BankTransactionCategory
    let amount: Int
    let balanceAfter: Int?
    let description: String
    let counterpartyName: String?
    let counterpartyTaxId: String?
    let date: String

    private enum CodingKeys: String, CodingKey {
        case id, accountId, type, category, amount, balanceAfter
        case description, counterpartyName, counterpartyTaxId, date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        accountId = (try? c.decode(String.self, forKey: .accountId)) ?? ""
        let rawType = (try? c.decode(String.self, forKey: .type)) ?? ""
        type = BankTransactionType(rawValue: rawType) ?? .debit
        let rawCategory = (try? c.decode(String.self, forKey: .category)) ?? ""
        category = BankTransactionCategory(rawValue: rawCategory) ?? .other
        amount = (try? c.decode(Int.self, forKey: .amount)) ?? 0
        balanceAfter = try? c.decode(Int.self, forKey: .balanceAfter)
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        counterpartyName = try? c.decode(String.self, forKey: .counterpartyName)
        counterpartyTaxId = try? c.decode(String.self, forKey: .counterpartyTaxId)
        date = (try? c.decode(String.self, forKey: .date)) ?? ""
    }

    func toBankTransaction() -> BankTransaction {
        BankTransaction(
            id: id, accountId: accountId, type: type, category: category,
            amount: amount, balanceAfter: balanceAfter, description: description,
            counterpartyName: counterpartyName, counterpartyTaxId: counterpartyTaxId, date: date
        )
    }
}

// MARK: Upcoming payments

struct RemoteUpcomingResponse: Decodable, Sendable {
    let data: [RemoteUpcomingPayment]
}

/// Decodifica de forma tolerante (campos ausentes recebem defaults sensatos).
struct RemoteUpcomingPayment: Decodable, Sendable {
    let id: String
    let receiverName: String
    let paymentAmount: Int
    let paymentDate: String
    let status: String
    let organizationName: String?

    private enum CodingKeys: String, CodingKey {
        case id, receiverName, paymentAmount, paymentDate, status, organizationName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        receiverName = (try? c.decode(String.self, forKey: .receiverName)) ?? "—"
        paymentAmount = (try? c.decode(Int.self, forKey: .paymentAmount)) ?? 0
        paymentDate = (try? c.decode(String.self, forKey: .paymentDate)) ?? ""
        status = (try? c.decode(String.self, forKey: .status)) ?? ""
        organizationName = try? c.decode(String.self, forKey: .organizationName)
    }

    func toUpcomingPayment() -> UpcomingPayment {
        UpcomingPayment(
            id: id, receiverName: receiverName, paymentAmount: paymentAmount,
            paymentDate: paymentDate, status: status, organizationName: organizationName
        )
    }
}

struct RemoteBankingAccountsResponse: Decodable, Sendable {
    let data: [RemoteBankingAccount]
}

/// INTERNAL accounts carry `balance` as a number; EXTERNAL as `{ balance, balanceDate }` — both handled.
struct RemoteBankingAccount: Decodable, Sendable {
    let id: String
    let bankType: String
    let bankCodeStr: String
    let branchCode: String
    let accountType: String
    let descriptionText: String
    let accountNumber: String?
    let consolidator: Consolidator?
    let organization: OrgRef?
    let balanceCents: Int?

    struct Consolidator: Decodable, Sendable { let id: String; let legalName: String; let taxId: String }
    struct OrgRef: Decodable, Sendable { let id: String?; let legalName: String? }
    private struct ExternalBalance: Decodable { let balance: Double }

    private enum CodingKeys: String, CodingKey {
        case id, bankType, bankCodeStr, branchCode, accountType, description, accountNumber, consolidator, organization, balance
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        bankType = (try? c.decode(String.self, forKey: .bankType)) ?? "INTERNAL"
        bankCodeStr = (try? c.decode(String.self, forKey: .bankCodeStr)) ?? ""
        branchCode = (try? c.decode(String.self, forKey: .branchCode)) ?? ""
        accountType = (try? c.decode(String.self, forKey: .accountType)) ?? "CHECKING"
        descriptionText = (try? c.decode(String.self, forKey: .description)) ?? "Conta"
        accountNumber = try? c.decode(String.self, forKey: .accountNumber)
        consolidator = try? c.decode(Consolidator.self, forKey: .consolidator)
        organization = try? c.decode(OrgRef.self, forKey: .organization)
        if let number = try? c.decode(Double.self, forKey: .balance) {
            balanceCents = Int(number.rounded())
        } else if let external = try? c.decode(ExternalBalance.self, forKey: .balance) {
            balanceCents = Int(external.balance.rounded())
        } else {
            balanceCents = nil
        }
    }

    func toBankAccount() -> BankAccount {
        BankAccount(
            id: id,
            bankCode: bankCodeStr,
            bankCodeStr: bankCodeStr,
            branchCode: branchCode,
            accountNumber: accountNumber ?? "—",
            accountDigit: nil,
            accountType: BankAccountType(rawValue: accountType) ?? .checking,
            name: descriptionText,
            taxId: consolidator?.taxId ?? "",
            pixKey: nil,
            isExternal: bankType == "EXTERNAL",
            organizationId: organization?.id ?? consolidator?.id ?? "",
            organizationName: organization?.legalName ?? consolidator?.legalName,
            balance: balanceCents ?? 0,
            availableBalance: balanceCents,
            predictedExpenses: nil,
            bank: BankInfo(
                code: bankCodeStr,
                name: BankCodeName.name(for: bankCodeStr) ?? bankCodeStr,
                shortName: BankCodeName.name(for: bankCodeStr) ?? bankCodeStr,
                iconUrl: nil
            )
        )
    }
}
