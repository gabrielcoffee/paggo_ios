import SwiftUI

/// Assistente da carteira: responde sobre orçamentos/gastos e propõe ações que só executam
/// depois do toque em Confirmar — pelas MESMAS chamadas dos botões das telas (doc 06).
/// A conversa persistida é a auditoria: quem confirmou, quando, e o resultado.
struct AssistantView: View {
    @Environment(ChatStore.self) private var chat
    @Environment(CardStore.self) private var cardStore
    @State private var draft = ""
    @State private var reimbursementDraftOpen = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        if chat.messages.isEmpty {
                            welcome
                        }
                        ForEach(chat.messages) { message in
                            MessageBubble(message: message,
                                          onConfirm: { action in confirm(action, in: message) },
                                          onDismiss: { action in dismissAction(action, in: message) })
                                .id(message.id)
                        }
                        if chat.isSending {
                            HStack {
                                ProgressView().tint(Theme.accent)
                                Spacer()
                            }
                            .padding(.horizontal, Spacing.lg)
                        }
                    }
                    .padding(.vertical, Spacing.lg)
                }
                .onChange(of: chat.messages.count) { _, _ in
                    if let last = chat.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            inputBar
        }
        .screenBackground()
        .navigationTitle("Assistente")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await chat.load()
            if chat.currentSession == nil {
                if let last = chat.sessions.first {
                    await chat.open(last)
                } else {
                    await chat.startSession()
                }
            }
        }
        .fullScreenCover(isPresented: $reimbursementDraftOpen) {
            ReimbursementFormView()
        }
    }

    private var welcome: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 28)).foregroundStyle(Theme.accent)
            Text("Pergunte sobre seus orçamentos e gastos, ou peça uma ação")
                .font(.brand(.subheadline, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            HStack(spacing: Spacing.sm) {
                suggestionChip("Quanto sobrou em Marketing?")
                suggestionChip("Congela meu cartão")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            Task { await chat.send(text) }
        } label: {
            Text(text)
                .font(.brand(.caption, weight: .medium))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.xs)
                .background(Theme.accentSoft, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var inputBar: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Escreva sua pergunta…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .font(.brand(.subheadline))
                .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                .background(Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: 18))
            Button {
                let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                draft = ""
                Task { await chat.send(text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(draft.isEmpty ? Theme.textTertiary : Theme.accent)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.isSending)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: Execução das ações (mesmos stores da UI; resultado volta pra conversa)

    private func confirm(_ action: AssistantAction, in message: AssistantMessage) {
        Task {
            await chat.updateAction(messageId: message.id, actionId: action.id, status: .confirmed)
            switch action.tool {
            case "freezeCard":
                let ok = await cardStore.setFrozen(true)
                await finish(action, in: message, ok: ok,
                             result: ok ? "Cartão congelado" : "Falha ao congelar")
            case "unfreezeCard":
                let ok = await cardStore.setFrozen(false)
                await finish(action, in: message, ok: ok,
                             result: ok ? "Cartão descongelado" : "Falha ao descongelar")
            case "draftReimbursement":
                await finish(action, in: message, ok: true, result: "Rascunho aberto")
                reimbursementDraftOpen = true
            default:
                await finish(action, in: message, ok: false, result: "Ação não disponível")
            }
        }
    }

    private func finish(_ action: AssistantAction, in message: AssistantMessage,
                        ok: Bool, result: String) async {
        await chat.updateAction(messageId: message.id, actionId: action.id,
                                status: ok ? .executed : .failed, result: result)
        ToastCenter.shared.show(result, style: ok ? .success : .error)
    }

    private func dismissAction(_ action: AssistantAction, in message: AssistantMessage) {
        Task {
            await chat.updateAction(messageId: message.id, actionId: action.id, status: .dismissed)
        }
    }
}

// MARK: - Bolha + card de ação

private struct MessageBubble: View {
    let message: AssistantMessage
    let onConfirm: (AssistantAction) -> Void
    let onDismiss: (AssistantAction) -> Void

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: Spacing.sm) {
            Text(message.content)
                .font(.brand(.subheadline))
                .foregroundStyle(message.role == .user ? .white : Theme.textPrimary)
                .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                .background(message.role == .user ? AnyShapeStyle(Theme.accent)
                                                  : AnyShapeStyle(Theme.surfaceHigh),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            ForEach(message.actions) { action in
                ActionCard(action: action,
                           onConfirm: { onConfirm(action) },
                           onDismiss: { onDismiss(action) })
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .padding(.horizontal, Spacing.lg)
    }
}

private struct ActionCard: View {
    let action: AssistantAction
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.brand(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            switch action.status {
            case .proposed:
                HStack(spacing: Spacing.sm) {
                    Button("Confirmar", action: onConfirm)
                        .buttonStyle(PrimaryActionStyle())
                    Button("Agora não", action: onDismiss)
                        .buttonStyle(SecondaryActionStyle())
                }
            case .confirmed:
                Label("Executando…", systemImage: "hourglass")
                    .font(.brand(.caption)).foregroundStyle(Theme.textSecondary)
            case .executed:
                Label(action.result ?? "Feito", systemImage: "checkmark.circle.fill")
                    .font(.brand(.caption, weight: .medium)).foregroundStyle(Theme.positive)
            case .failed:
                Label(action.result ?? "Falhou", systemImage: "xmark.octagon.fill")
                    .font(.brand(.caption, weight: .medium)).foregroundStyle(Theme.negative)
            case .dismissed:
                Label("Dispensado", systemImage: "minus.circle")
                    .font(.brand(.caption)).foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var title: String {
        switch action.tool {
        case "freezeCard": return "Congelar cartão"
        case "unfreezeCard": return "Descongelar cartão"
        case "draftReimbursement": return "Preparar reembolso"
        default: return action.tool
        }
    }

    private var symbol: String {
        switch action.tool {
        case "freezeCard", "unfreezeCard": return "snowflake"
        case "draftReimbursement": return "arrow.uturn.backward.circle"
        default: return "bolt"
        }
    }

    private var tint: Color {
        action.tool == "freezeCard" || action.tool == "unfreezeCard" ? Theme.info : Theme.accent
    }
}
