import AVFoundation
import SwiftUI
import Vision
import VisionKit

/// Scanner de câmera do fluxo de pagamento (VisionKit `DataScannerViewController`):
/// QR Pix ou código de barras de boleto (ITF/Code128). Emite o primeiro código reconhecido
/// (com haptic) e para. Lanterna via AVCaptureDevice (o DataScanner não expõe torch).
/// Indisponível (simulador / permissão negada) → o chamador mostra o campo de colar.
struct WalletScannerView: View {
    enum Mode {
        case pixQR
        case boletoBarcode

        var symbologies: [VNBarcodeSymbology] {
            switch self {
            case .pixQR: return [.qr]
            case .boletoBarcode: return [.i2of5, .itf14, .code128]
            }
        }

        var hint: String {
            switch self {
            case .pixQR: return "Aponte a câmera para o QR Code Pix"
            case .boletoBarcode: return "Aponte para o código de barras do boleto"
            }
        }
    }

    let mode: Mode
    let onCode: (String) -> Void

    @State private var torchOn = false

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DataScannerRepresentable(symbologies: mode.symbologies) { code in
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onCode(code)
            }
            .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Text(mode.hint)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(.black.opacity(0.55), in: Capsule())

                Button {
                    torchOn.toggle()
                    setTorch(torchOn)
                } label: {
                    Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(torchOn ? .black : .white)
                        .frame(width: 52, height: 52)
                        .background(torchOn ? .white : .black.opacity(0.55), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, Spacing.xxl)
        }
    }

    private func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let symbologies: [VNBarcodeSymbology]
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: symbologies)],
            qualityLevel: .balanced,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var fired = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(_ scanner: DataScannerViewController,
                         didAdd added: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !fired else { return }
            for item in added {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    fired = true
                    scanner.stopScanning()
                    onCode(payload)
                    return
                }
            }
        }
    }
}
