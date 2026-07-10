# 04 — Policy engine + smart receipts

Regras de gasto (categorias bloqueadas, tetos, exigência de recibo, auto-aprovação) aplicadas
nos instrumentos (cartão, carteira, reembolso) + recibos com OCR **real** (Vision, on-device)
casados automaticamente com transações. Status: **Passe A (contratos + regras) aprovado
2026-07-08** · Passe B (UX) pendente · Passe C (arquitetura) pendente.

## Contratos

### `policies.json`

Escopo global ou por orçamento. Campo `null` num policy de budget **herda do global**
(override campo a campo).

```jsonc
{
  "id": "pol_01",
  "scope": { "type": "budget", "budgetId": "bgt_01" },  // ou { "type": "global" }
  "blockedCategories": ["software"],
  "maxPerTransaction": 200000,      // cents; null = sem teto
  "receiptRequiredAbove": 5000,     // cents; recibo exigido acima disso
  "autoApproveBelow": 10000,        // reembolso (doc 03) abaixo → auto-aprovado
  "enabled": true,
  "updatedBy": { "id": "usr_admin_1", "name": "Ana Lima" },
  "createdAt": "2026-07-01T00:00:00Z",
  "updatedAt": "2026-07-01T00:00:00Z"
}
```

### `receipts.json`

```jsonc
{
  "id": "rcp_01",
  "uploadedBy": { "id": "usr_emp_7", "name": "Igor Souza" },
  "url": "storage://receipts/rcp_01.jpg",     // Supabase Storage
  "ocr": {                                     // Vision on-device; null enquanto processa
    "merchantName": "Posto Shell Marginal",
    "date": "2026-07-07",
    "amount": 15000,                           // cents
    "confidence": { "merchantName": 0.94, "date": 0.99, "amount": 0.97 }
  },
  "match": {                                   // null = sem casamento
    "type": "cardTransaction",                 // cardTransaction | payment
    "id": "ctx_01",
    "method": "auto"                           // auto | manual
  },
  "status": "matched",                         // processing | unmatched | matched
  "createdAt": "2026-07-08T17:00:00Z",
  "updatedAt": "2026-07-08T17:00:10Z"
}
```

### Extensões de contratos existentes

- `declineReason` (doc 02) ganha valores: `category_blocked` · `policy_max_amount`.
- Reembolso (doc 03) ganha `policyFlags: ["over_max_amount", "blocked_category"]` —
  violações **não bloqueiam** submissão, só sinalizam pro aprovador.
- `decidedBy` aceita `{ "id": "system", "name": "Política" }` na auto-aprovação.

## Matriz de enforcement

| Violação | Cartão | Carteira | Reembolso |
|---|---|---|---|
| Categoria bloqueada | decline `category_blocked` | erro na RPC | flag pro aprovador |
| Acima de `maxPerTransaction` | decline `policy_max_amount` | erro na RPC | flag pro aprovador |
| Sem recibo ≥ `receiptRequiredAbove` | pendência + nudge | pendência + nudge | bloqueia submissão |
| Abaixo de `autoApproveBelow` | — | — | auto-aprova |

## Regras de negócio

1. **Precedência** — policy do budget sobrepõe o global campo a campo; campo `null` herda.
   `enabled: false` desliga o policy inteiro (herda global).
2. **Pontos de enforcement por instrumento** — ver matriz: cartão recusa no auth
   (server-side, função do feed); carteira valida na RPC de criação do intent (erro antes de
   criar); reembolso nunca bloqueia por categoria/teto — violações viram `policyFlags` pro
   aprovador.
3. **Auto-aprovação** — reembolso com `amount < autoApproveBelow`, sem `policyFlags` e com
   recibo casado → `approved` na hora por `decidedBy: system`; consumo de orçamento e payout
   seguem o doc 03 normalmente.
4. **Recibo exigido** — `receiptRequiredAbove` **relaxa** a regra 1 do doc 03: reembolso
   abaixo do valor dispensa recibo. Para cartão/carteira, transação liquidada
   ≥ `receiptRequiredAbove` sem recibo casado vira **pendência** (alimenta doc 05).
5. **OCR** — Vision framework on-device (`VNRecognizeTextRequest`), sem serviço externo.
   Heurísticas: valor = maior quantia monetária; data = primeiro padrão de data; merchant =
   primeira linha não-numérica. Confiança por campo no contrato; extração ruim não impede
   casamento manual.
6. **Casamento (matching)** — candidatos: transações do mesmo usuário com valor dentro de
   ±5% e data dentro de ±3 dias, ainda sem recibo. Exatamente 1 candidato → casa `auto`;
   0 ou >1 → `unmatched` com sugestões ordenadas, usuário escolhe (`manual`). Casar seta
   `receiptStatus: attached` no alvo; descasar reverte. Recibo de reembolso anexa direto na
   submissão (doc 03) — não passa pelo matching.
7. **Edição de policy** — só admin; muda comportamento **prospectivamente** (transações e
   decisões passadas não reprocessam).
