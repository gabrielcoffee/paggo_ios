# 05 — Notificações

Central de notificações in-app alimentada por eventos server-side (thresholds de limite,
expirações, decisões, pendências) via Supabase realtime; push APNs como camada do passe C.
Status: **Passe A (contratos + regras) aprovado 2026-07-08** · Passe B (UX) pendente ·
Passe C (arquitetura) pendente.

## Contratos

### `notifications.json`

Servidor escreve título/corpo prontos (pt-BR) — fonte única de texto, paridade com push.
`payload` carrega o necessário pra navegação (deep-link).

```jsonc
{
  "id": "ntf_01",
  "recipient": { "id": "usr_emp_7" },
  "type": "budget_threshold",
  "payload": { "budgetId": "bgt_01", "membershipId": "bm_01", "threshold": 75 },
  "title": "Orçamento Marketing em 75%",
  "body": "Você usou R$ 6.000 de R$ 8.000 do seu limite neste período.",
  "readAt": null,
  "createdAt": "2026-07-08T18:00:00Z"
}
```

### Tipos e destinatários

| `type` | Gatilho | Destinatário |
|---|---|---|
| `budget_threshold` | consumo cruza **75%** ou **90%** do limite efetivo | membro (do próprio limite); owner/admin (do total do budget) |
| `budget_expiring` | oneTime: `endDate − 7d` e `endDate − 1d` | membros + owner |
| `budget_expired` | virada/expiração executada pelo job | membros + owner |
| `limit_request_submitted` | novo pedido de aumento | owner do budget |
| `limit_request_decided` | aprovado/recusado | solicitante · **obrigatória** |
| `card_transaction` | auth nova no cartão | portador |
| `card_declined` | transação recusada (qualquer motivo) | portador |
| `receipt_pending` | job diário: liquidada ≥ `receiptRequiredAbove` sem recibo há ≥ 3 dias | dono da transação |
| `reimbursement_submitted` | novo reembolso | aprovador (doc 03 regra 4) |
| `reimbursement_decided` | aprovado/recusado (inclui auto-aprovação) | solicitante · **obrigatória** |
| `reimbursement_paid` | package do reembolso liquidado na esteira (`PAID`) | solicitante |

### `notification-prefs.json`

Por usuário, toggle por tipo (integra com `NotificationPrefsStore` existente):

```jsonc
{ "userId": "usr_emp_7", "disabledTypes": ["card_transaction"], "updatedAt": "..." }
```

## Regras de negócio

1. **Emissão server-side** — triggers/jobs no Supabase; o app nunca cria notificação própria
   (fonte única, multi-device consistente). Entrega in-app via realtime subscription.
2. **Dedup** — `budget_threshold`: 1 por (membership, período, threshold); cruzou 75% duas
   vezes no mês (consumo caiu por reversal e subiu de novo) → não repete. `budget_expiring`:
   1 por marco. `receipt_pending`: 1 por transação a cada 3 dias.
3. **Preferência silencia entrega, não criação** — tipo desligado não gera registro pro
   usuário; exceção: os tipos `*_decided` são obrigatórios (decisões sobre pedidos seus
   sempre chegam).
4. **Leitura** — `readAt` por notificação; badge = count de não-lidas; "marcar todas".
5. **Retenção** — lidas somem após 90 dias (job); não-lidas persistem.
6. **Threshold usa limite efetivo** — 75/90% calculado sobre o limite da doc 01 regra 2
   (considera `temporaryLimit`); aumento aprovado pode "descruzar" o threshold — não gera
   nova notificação até cruzar de novo em outro período.
