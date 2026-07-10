import SwiftUI
import UIKit

/// Entrada do PIN de transação (4 dígitos) com teclado próprio.
/// A validação é **server-side** (RN-15): `onConfirm` chama `POST /wallets/{id}/validate-pin`
/// via repository e devolve `false` em PIN incorreto (shake + limpa). Sem atalho de Face ID —
/// biometria não substitui o PIN (o servidor é quem valida), igual ao wallet-pwa.
struct WalletPinSheet: View {
    let onConfirm: (String) async -> Bool
    let onCancel: () -> Void

    @State private var pin = ""
    @State private var error = false
    @State private var validating = false
    @State private var shake: CGFloat = 0

    private let length = 4

    var body: some View {
        VStack(spacing: Spacing.xl) {
            HStack {
                Button(action: onCancel) {
                    Label("Voltar", systemImage: "chevron.left")
                        .font(.brand(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(validating)
                Spacer()
            }
            .padding(.top, Spacing.md)

            VStack(spacing: Spacing.sm) {
                Text("PIN de transação")
                    .font(.brand(.title3, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text(error ? "PIN incorreto. Tente novamente." : "Digite seu PIN para confirmar o pagamento.")
                    .font(.brand(.subheadline))
                    .foregroundStyle(error ? Theme.negative : Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Text("Caso não lembre o seu PIN, entre em contato com o suporte.")
                    .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Spacing.md)

            ZStack {
                dots.offset(x: shake).opacity(validating ? 0.3 : 1)
                if validating { ProgressView().tint(Theme.accent) }
            }

            Spacer(minLength: 0)

            keypad.disabled(validating)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.base)
    }

    private var dots: some View {
        HStack(spacing: Spacing.lg) {
            ForEach(0..<length, id: \.self) { i in
                Circle()
                    .fill(i < pin.count ? Theme.accent : Theme.surfaceHigh)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Theme.stroke, lineWidth: i < pin.count ? 0 : 1))
            }
        }
    }

    private var keypad: some View {
        Grid(horizontalSpacing: Spacing.xxl, verticalSpacing: Spacing.lg) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(1...3, id: \.self) { col in key("\(row * 3 + col)") }
                }
            }
            GridRow {
                Color.clear.frame(width: 72, height: 72)
                key("0")
                deleteKey
            }
        }
    }

    private func key(_ digit: String) -> some View {
        Button { append(digit) } label: {
            Text(digit)
                .font(.brand(size: 28, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 72, height: 72)
                .background(Theme.surfaceHigh.opacity(0.5), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var deleteKey: some View {
        Button { if !pin.isEmpty { pin.removeLast(); error = false } } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 22)).foregroundStyle(Theme.textSecondary)
                .frame(width: 72, height: 72)
        }
        .buttonStyle(.plain)
        .disabled(pin.isEmpty)
    }

    // MARK: Logic

    private func append(_ digit: String) {
        guard pin.count < length else { return }
        error = false
        pin += digit
        if pin.count == length { submit() }
    }

    private func submit() {
        validating = true
        let entered = pin
        Task {
            let valid = await onConfirm(entered)
            validating = false
            if valid {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation(.default) { error = true }
                shakeDots()
                pin = ""
            }
        }
    }

    private func shakeDots() {
        withAnimation(.linear(duration: 0.05).repeatCount(6, autoreverses: true)) { shake = 8 }
        Task {
            try? await Task.sleep(for: .seconds(0.35))
            await MainActor.run { shake = 0 }
        }
    }
}
