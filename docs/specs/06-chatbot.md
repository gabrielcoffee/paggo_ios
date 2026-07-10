# 06 — Chatbot

Assistente conversacional que responde perguntas ("quanto sobrou no orçamento de Marketing?")
e executa ações ("congela meu cartão") pelos **mesmos stores/RPCs da UI** — sem caminho de
escrita paralelo. LLM = Claude API atrás de Supabase Edge Function (chave nunca no app).
Status: **Passe A (contratos + regras) aprovado 2026-07-08** · Passe B (UX) pendente ·
Passe C (arquitetura) pendente.

## Contratos

### `chat-sessions.json` / `chat-messages.json`

```jsonc
// sessão
{ "id": "chs_01", "userId": "usr_emp_7", "title": "Cartão e limites",
  "createdAt": "2026-07-08T19:00:00Z", "updatedAt": "2026-07-08T19:04:00Z" }

// mensagem
{
  "id": "msg_03",
  "sessionId": "chs_01",
  "role": "assistant",              // user | assistant
  "content": "Seu cartão do orçamento Marketing está ativo. Quer que eu congele?",
  "actions": [                      // propostas de ação embutidas (pode ser vazio)
    {
      "id": "act_01",
      "tool": "freezeCard",
      "params": { "cardId": "crd_01" },
      "status": "proposed",         // proposed | confirmed | executed | failed | dismissed
      "result": null,               // preenchido após execução
      "confirmedAt": null,
      "executedAt": null
    }
  ],
  "createdAt": "2026-07-08T19:04:00Z"
}
```

### Registro de ferramentas (tool registry)

Filtrado por papel do usuário. Leitura executa direto; mutação exige confirmação.

| Ferramenta | Tipo | Papel | Executa onde |
|---|---|---|---|
| `getBudgets` / `getBudgetStatus` | leitura | ambos | servidor (RPC) |
| `getCardTransactions` / `getStatement` | leitura | ambos | servidor (RPC) |
| `getPendingApprovals` | leitura | admin | servidor (RPC) |
| `freezeCard` / `unfreezeCard` | mutação | funcionário | cliente → mesma RPC da UI |
| `requestLimitIncrease` | mutação | funcionário | cliente → mesma RPC da UI |
| `draftReimbursement` | mutação* | funcionário | cliente → abre fluxo do doc 03 pré-preenchido |
| `approveLimitRequest` / `rejectLimitRequest` | mutação | admin | cliente → mesma RPC da UI |
| `decideReimbursement` | mutação | admin | cliente → mesma RPC da UI |
| `lockCard` / `unlockCard` | mutação | admin | cliente → mesma RPC da UI |

\* `draftReimbursement` não submete — abre o fluxo do doc 03 preenchido (submissão continua
tendo recibo/validações do fluxo normal).

## Regras de negócio

1. **Sem caminho paralelo** — toda mutação passa pelas mesmas RPCs/stores da UI; o modelo
   nunca escreve direto no banco. Policy engine (doc 04) e validações aplicam igual.
2. **Confirmação obrigatória** — mutação vira `action` com `status: proposed`; card de
   confirmação na conversa; usuário toca **Confirmar** → app executa → `executed` + `result`
   (ou `failed` + erro legível). Dispensar → `dismissed`. Leitura não pede confirmação.
3. **Escopo por papel** — registry filtrado por funcionário/admin **no servidor** (edge
   function); ferramenta fora do papel nem chega ao modelo. Dados: modelo só vê o que o
   usuário veria na UI (mesmas RLS/queries).
4. **Chave da API server-side** — Claude API chamada só pela edge function; app envia
   mensagens, recebe stream. Modelo: `claude-sonnet-5` (custo/latência de chat).
5. **Mutações executam no cliente** — resultado volta pra edge function completar a resposta
   (loop de tool-use atravessa o cliente quando necessário).
6. **Contexto da sessão** — system prompt injeta: usuário `{id, name}`, papel, resumo dos
   memberships (budget, limite efetivo, consumido) e data atual. Histórico da sessão vai
   completo; sessões antigas não.
7. **Auditoria** — `actions` persistidas na mensagem são o log: quem confirmou, quando,
   resultado. Nada de ação sem rastro na conversa.
