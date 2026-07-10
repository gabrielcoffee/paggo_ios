import CoreLocation
import Observation

/// Portão de localização para pagamentos da Carteira: a wallet-pwa exige geolocalização antes de
/// pagar. Pede permissão "quando em uso" e obtém uma coordenada única. Retorna nil se negado.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    private var authContinuation: CheckedContinuation<Bool, Never>?
    private var locContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Garante permissão + uma coordenada. `nil` = negado/indisponível (o fluxo deve bloquear).
    func requireLocation() async -> CLLocationCoordinate2D? {
        // Uma requisição por vez: evita sobrescrever (e vazar) uma continuation pendente.
        guard authContinuation == nil, locContinuation == nil else { return nil }
        switch manager.authorizationStatus {
        case .notDetermined:
            let granted = await requestAuthorization()
            guard granted else { return nil }
        case .denied, .restricted:
            return nil
        default:
            break
        }
        return await requestOnce()
    }

    // MARK: Requests

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestOnce() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            locContinuation = continuation
            manager.requestLocation()
        }
    }

    private func resolveAuth(_ granted: Bool) {
        authContinuation?.resume(returning: granted)
        authContinuation = nil
    }

    private func resolveLocation(_ coordinate: CLLocationCoordinate2D?) {
        locContinuation?.resume(returning: coordinate)
        locContinuation = nil
    }

    // MARK: CLLocationManagerDelegate (chamado na main thread; faz hop p/ o ator)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                resolveAuth(true)
            case .denied, .restricted:
                resolveAuth(false)
            default:
                break   // .notDetermined: aguarda a escolha do usuário
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in resolveLocation(coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in resolveLocation(nil) }
    }
}
