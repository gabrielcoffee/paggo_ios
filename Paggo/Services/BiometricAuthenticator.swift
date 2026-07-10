import Foundation
import LocalAuthentication

enum BiometricResult: Sendable {
    case success
    case failed       // cancelado pelo usuário ou não reconhecido
    case unavailable  // sem biometria configurada no dispositivo
}

/// Abstrai a avaliação biométrica para permitir um mock em previews/testes.
protocol BiometricAuthenticating: Sendable {
    /// Rótulo do tipo de biometria disponível ("Face ID" / "Touch ID").
    var biometryLabel: String { get }
    func evaluate(reason: String) async -> BiometricResult
    /// Gate do dono do dispositivo (biometria OU código do aparelho) — fallback quando a
    /// biometria em si não está disponível (não cadastrada / permissão negada ao app).
    func evaluateDeviceOwner(reason: String) async -> BiometricResult
}

/// Wrapper de `LAContext`. Sem estado armazenado → seguro para `Sendable`.
struct BiometricAuthenticator: BiometricAuthenticating {
    var biometryLabel: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Face ID"
        }
    }

    func evaluate(reason: String) async -> BiometricResult {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .unavailable
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                   localizedReason: reason) { success, _ in
                continuation.resume(returning: success ? .success : .failed)
            }
        }
    }

    func evaluateDeviceOwner(reason: String) async -> BiometricResult {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication,
                                   localizedReason: reason) { success, _ in
                continuation.resume(returning: success ? .success : .failed)
            }
        }
    }
}

/// Mock para previews/testes — sempre autentica.
struct MockBiometricAuthenticator: BiometricAuthenticating {
    var biometryLabel: String { "Face ID" }
    func evaluate(reason: String) async -> BiometricResult { .success }
    func evaluateDeviceOwner(reason: String) async -> BiometricResult { .success }
}
