# 02 — Cartões corporativos virtuais

Cartão virtual por membership de orçamento, lastreado numa carteira (pré-pago): admin emite,
funcionário usa/congela/revela, transações chegam por feed server-side (auth → settle) e
debitam carteira + orçamento. Status: **Passe A (contratos + regras) aprovado 2026-07-08,
rev. 2026-07-10** · Passe B (UX) pendente · Passe C (arquitetura) pendente.

## Contratos

### `cards.json`

1 cartão **ativo** por membership. PAN/CVV **nunca** aparecem no wire de listagem.

```jsonc
{
  "id": "crd_01",
  "membershipId": "bm_01",
  "budget": { "id": "bgt_01", "name": "Marketing" },
  "wallet": { "id": "wal_01", "name": "Carteira Obra Centro" },   // conta lastro que financia (regra 1)
  "holder": { "id": "usr_emp_7", "name": "Igor Souza" },
  "type": "virtual",
  "brand": "visa",
  "last4": "4821",
  "expMonth": 7,
  "expYear": 2029,
  "status": "active",               // active | frozen | locked | canceled
  "lockedBy": null,                 // { id, name } quando lock manual do admin; "system" nos automáticos
  "createdAt": "2026-07-08T15:00:00Z",
  "updatedAt": "2026-07-08T15:00:00Z"
}
```

### Reveal (RPC `revealCard`)

Dados completos só na resposta da RPC, exigindo Face ID recente; o app não persiste.
Cada chamada gera um registro de auditoria:

```jsonc
// resposta
{ "cardId": "crd_01", "pan": "4111111111114821", "cvv": "382", "expMonth": 7, "expYear": 2029 }

// card-reveals.json (log de auditoria)
{ "id": "rvl_01", "cardId": "crd_01", "revealedBy": { "id": "usr_emp_7", "name": "Igor Souza" },
  "revealedAt": "2026-07-08T15:20:00Z" }
```

### `card-transactions.json`

```jsonc
{
  "id": "ctx_01",
  "cardId": "crd_01",
  "membershipId": "bm_01",
  "budget": { "id": "bgt_01", "name": "Marketing" },
  "holder": { "id": "usr_emp_7", "name": "Igor Souza" },   // denormalizado p/ feeds do admin
  "merchant": { "name": "Uber *Trip", "category": "transport", "city": "São Paulo", "country": "BR" },
  "amount": 4890,                   // autorização, cents
  "settledAmount": null,            // preenchido no settle; pode diferir (gorjeta/ajuste)
  "currency": "BRL",
  "status": "authorized",           // authorized | settled | reversed | declined
  "declineReason": null,            // card_frozen | card_locked | insufficient_funds | limit_exceeded | budget_expired
  "authorizedAt": "2026-07-08T15:12:00Z",
  "settledAt": null,
  "receiptStatus": "missing",       // missing | attached — ponte pro doc 04
  "createdAt": "2026-07-08T15:12:00Z",
  "updatedAt": "2026-07-08T15:12:00Z"
}
```

## Regras de negócio

1. **Emissão** — admin emite cartão virtual para membership ativo, escolhendo a **carteira
   lastro** que o financia; máx. 1 cartão ativo por membership; cancelado → pode reemitir.
2. **Estados** — funcionário: freeze/unfreeze; admin: lock/unlock/cancel. Lock vence freeze
   (funcionário não destrava lock). `canceled` é terminal.
3. **Locks automáticos (o `status` sempre conta a verdade)** — membership suspenso → cartão
   `locked` (system); orçamento `expired`/`archived` ou carteira inativa → cartões `locked`
   (system). Nunca fica
   cartão `active` que sempre recusa; `declineReason: budget_expired` só existe para a corrida
   entre o job de expiração e uma autorização em voo.
4. **Débito no auth (pré-pago)** — `authorized` soma no `consumed` do membership **e debita
   o disponível da carteira lastro** imediatamente; `reversed` devolve nos dois; `declined`
   não consome; `settled` ajusta a diferença (`settledAmount − amount`) nos dois. **Ajuste de
   settle sempre aplica**, mesmo ultrapassando limite ou disponível — recusa no settle não
   existe; over vira aviso visual.
5. **Decline determinístico** — ordem de avaliação: estado do cartão (frozen/locked/canceled
   → `card_frozen`/`card_locked`), depois policy (doc 04), depois disponível da carteira
   (`insufficient_funds`), por fim limite efetivo do membership (doc 01 regra 2 →
   `limit_exceeded`).
6. **Categoria automática** — `merchant.category` vem da rede (MCC), ao contrário do Pix
   (doc 01 regra 9); funcionário pode corrigir — a correção alimenta o doc 04.
7. **Funding pré-pago** — o cartão gasta o disponível da carteira lastro (modelo conta de
   pagamento BR, como Pix/boleto da carteira): o duplo limite do doc 01 regra 3 vale igual —
   carteira **e** membership, verificações independentes.
8. **Refund pós-settle fora de escopo** — `reversed` só existe a partir de `authorized`;
   crédito/estorno depois de liquidado não está neste spec (como o estorno Pix no doc 01).
9. **Feed** — transações inseridas server-side (seed + scheduled function), chegam via
   realtime; cenários determinísticos cobrem auth→settle, decline por cada motivo, reversal
   e settle com ajuste de valor.
