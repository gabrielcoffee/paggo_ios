import Foundation

/// Carrega fixtures JSON do bundle (`Resources/WalletFixtures/*.json`) pelo **mesmo** caminho
/// Codable que o cliente live usará (`JSONDecoder.api`) — se um DTO não parsear o payload real,
/// falha aqui na demo, não na integração.
enum WalletFixtureLoader {
    static func load<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw WalletError.generic("Fixture \(name).json não encontrada no bundle.")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.api.decode(T.self, from: data)
    }
}
