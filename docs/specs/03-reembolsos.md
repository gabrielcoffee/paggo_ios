# 03 — Reembolsos

Funcionário gastou do próprio bolso → submete despesa com recibo → admin aprova → vira
package `REIMBURSEMENT` na esteira de payout → Pix na liquidação. Status: **Passe A
(contratos + regras) aprovado 2026-07-08, rev. 2026-07-10** · Passe B (UX) implementado 2026-07-10 ·
Passe C (arquitetura) pendente.

## Contratos

### `reimbursements.json`

```jsonc
{
  "id": "rmb_01",
  "requester": { "id": "usr_emp_7", "name": "Igor Souza" },
  "budget": { "id": "bgt_01", "name": "Marketing" },    // opcional (doc 01 regra 10)
  "merchantCategory": "food",
  "description": "Almoço com cliente",
  "amount": 12350,                  // cents, digitado pelo funcionário
  "currency": "BRL",
  "expenseDate": "2026-07-07",
  "receipt": { "status": "attached", "url": "storage://receipts/rmb_01.jpg" },  // doc 04 estende
  "status": "submitted",            // submitted | approved | paid | rejected | canceled
  "packageId": null,                // wire: derivado — no banco a FK mora no package (packages.reimbursementId)
  "estimatedPaymentDate": null,     // set na aprovação (D+2 corridos, expectativa exibida)
  "paidAt": null,
  "payoutKey": { "type": "cpf", "value": "113.036.437-23" },  // snapshot do perfil
  "decidedBy": null,
  "decidedAt": null,
  "decisionNote": null,
  "createdAt": "2026-07-08T16:00:00Z",
  "updatedAt": "2026-07-08T16:00:00Z"
}
```

### Extensão do perfil do funcionário

Campo novo no perfil: chave Pix para receber payouts. Sem ela, submissão bloqueada com CTA
de cadastro:

```jsonc
{ "payoutKey": { "type": "cpf", "value": "113.036.437-23" } }   // tipos: cpf | phone | email | evp
```

## Regras de negócio

1. **Recibo obrigatório** na submissão. Relaxamento por policy (`receiptRequiredAbove`) e
   auto-aprovação: doc 04.
2. **Fluxo** — `submitted → approved → paid`. Terminais: `rejected` (com `decisionNote`) e
   `canceled` (pelo solicitante, só enquanto `submitted`). Aprovar seta
   `estimatedPaymentDate = D+2 corridos` e **cria um package `REIMBURSEMENT` na esteira de
   payout** (recebedor = solicitante, Pix via `payoutKey`), nascendo em Validação — aprovação
   da despesa (gestor) e liberação financeira (esteira) são portões distintos. Package `PAID`
   → reembolso `paid`; é o único estado do package que reflete de volta no reembolso.
   Armazenamento: a referência fica no package (`packages.reimbursementId`, FK — o package
   aponta pra sua origem, como no produto real); o `packageId` do wire vem por junção.
3. **Consumo de orçamento** — com budget marcado, consome `membership.consumed` na
   **aprovação** (compromisso), não na submissão nem no paid. Rejeição/cancelamento não
   consomem.
4. **Aprovador** — budget marcado → `ownerId` do budget; sem budget → qualquer admin.
5. **payoutKey** — snapshot do perfil no momento da submissão (mudança posterior de chave
   não afeta pedidos em andamento).

## UX (passe B) — implementado 2026-07-10

- Entrada pelo hub: linha "Reembolsos" com contagem em andamento.
- Formulário único: a **foto do recibo preenche valor e data via OCR** (o funcionário só
  confere); a política aparece antes de enviar — "aprova na hora" quando elegível,
  alertas de teto/categoria quando sinalizado (violação não bloqueia, doc 04).
- Sucesso com expectativa: valor + previsão D+2 + explicação de que o financeiro libera
  (portões distintos). Detalhe com linha do tempo (enviado → aprovado → pago) e motivo de
  recusa; cancelamento só enquanto em análise.
