import Foundation

/// Origem dos dados: mocks locais ou backend real.
enum DataSource: String, Sendable {
    case mock
    case live
}

/// Config do Google OAuth (público — embarcado no app, como no app Expo).
struct GoogleConfig: Sendable {
    var iosClientID: String
    var serverClientID: String   // web client id (audience do backend)
}

/// Config do Firebase (público — espelha `src/config/firebase.ts` do app Expo).
struct FirebaseConfigValues: Sendable {
    var apiKey: String
    var projectID: String
    var googleAppID: String
    var gcmSenderID: String
    var storageBucket: String
}

/// Configuração de ambiente. URLs + config pública ficam em código; a **API key** (sensível) é lida
/// de `Secrets.plist` (git-ignored) ou de uma variável de ambiente — nunca commitada.
struct AppConfig: Sendable {
    var apiBaseURL: URL
    var authBaseURL: URL
    var apiKey: String
    var dataSource: DataSource
    var google: GoogleConfig
    var firebase: FirebaseConfigValues

    static let current: AppConfig = .load()

    private static func load() -> AppConfig {
        let env = ProcessInfo.processInfo.environment
        let secrets = secretsPlist()

        func secret(_ envKey: String, _ plistKey: String) -> String {
            if let v = env[envKey], !v.isEmpty { return v }
            if let v = secrets[plistKey] as? String, !v.isEmpty { return v }
            return ""
        }

        let api = env["PAGGO_API_URL"] ?? "https://paggo-mobile-api.paggo.ai/v1"
        let auth = env["PAGGO_AUTH_API_URL"] ?? "https://mobile-auth.paggo.ai/v1"
        let apiKey = secret("PAGGO_API_KEY", "PaggoApiKey")

        // Default: live quando há API key; senão mock. Override via PAGGO_DATA_SOURCE.
        let source: DataSource = {
            if let raw = env["PAGGO_DATA_SOURCE"], let s = DataSource(rawValue: raw) { return s }
            return apiKey.isEmpty ? .mock : .live
        }()

        return AppConfig(
            apiBaseURL: URL(string: api)!,
            authBaseURL: URL(string: auth)!,
            apiKey: apiKey,
            dataSource: source,
            google: GoogleConfig(
                iosClientID: "928261899617-40699rr89rr98320aj9h3ndshsjf0gs9.apps.googleusercontent.com",
                serverClientID: "928261899617-d8old13o47s053lgs9c1dq3691thq2mv.apps.googleusercontent.com"
            ),
            firebase: FirebaseConfigValues(
                apiKey: "AIzaSyB_zgxg-xZUi3mSnw68wXKcoseAdcFcBM0",
                projectID: "paggo-app",
                // iOS SDK exige plataforma `:ios:` no app id (o app Expo só tem app web no Firebase).
                // Placeholder de formato válido; o Auth usa apiKey+projectID. Para produção,
                // registre um app iOS no Firebase e use o GoogleService-Info.plist real.
                googleAppID: "1:928261899617:ios:4b425cda273d790f77b120",
                gcmSenderID: "928261899617",
                storageBucket: "paggo-app.firebasestorage.app"
            )
        )
    }

    private static func secretsPlist() -> [String: Any] {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return dict
    }
}
