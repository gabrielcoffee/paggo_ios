# 01 — Budgets + limites

Orçamentos estilo Ramp: admin cria orçamento por time/projeto/período; funcionários são
membros com limite individual; gasto da carteira consome o orçamento; funcionário pede
aumento, admin aprova. Status: **Passe A (contratos + regras) aprovado 2026-07-08, rev. 2026-07-10** ·
Passe B (UX) implementado 2026-07-10 · Passe C (arquitetura) pendente.

## Contratos

### `budgets.json`

```jsonc
{
  "id": "bgt_01",
  "name": "Marketing",
  "description": "Mídia paga e eventos",
  "ownerId": "usr_admin_1",         // admin que gerencia (edita, decide pedidos)
  "period": {
    "type": "monthly",              // monthly | quarterly | oneTime
    "startDate": "2026-07-01",
    "endDate": null,                // obrigatório se oneTime
    "autoRenew": true
  },
  "totalLimit": 5000000,            // cents, por período
  "currency": "BRL",
  "status": "active",               // active | expired | archived
  "periodSummaries": [              // histórico de períodos fechados
    { "period": "2026-06", "consumed": 4200000 }
  ],
  "createdAt": "2026-06-20T12:00:00Z",
  "updatedAt": "2026-07-01T00:00:00Z"
}
```

> `consumed` do período atual **não existe no wire do budget** — é a soma dos memberships,
> calculada no app. Fonte de verdade única.

### `budget-memberships.json`

Array de memberships; cada registro liga **um** funcionário a **um** orçamento.
Funcionário em 2 orçamentos = 2 registros. Sem papel/role: todo membership é um gastador;
quem gerencia é o `ownerId` do budget.

```jsonc
{
  "id": "bm_01",
  "budgetId": "bgt_01",
  "employee": { "id": "usr_emp_7", "name": "Igor Souza", "email": "igor@paggo.ai" },
  "memberLimit": 800000,            // limite base; null = até o total do orçamento
  "temporaryLimit": {               // aumento temporário ativo; null quando não há
    "limit": 1200000,
    "validUntil": "2026-07-31",
    "requestId": "lir_01"           // auditoria: pedido que originou
  },
  "consumed": 240000,               // única fonte de verdade do gasto
  "status": "active",               // active | suspended
  "createdAt": "2026-06-20T12:00:00Z",
  "updatedAt": "2026-07-08T14:05:00Z"
}
```

### `limit-requests.json`

```jsonc
{
  "id": "lir_01",
  "membershipId": "bm_01",
  "budgetId": "bgt_01",
  "requestedBy": { "id": "usr_emp_7", "name": "Igor Souza" },
  "currentLimit": 800000,           // snapshot no momento do pedido (auditoria)
  "requestedLimit": 1200000,
  "kind": "temporary",              // temporary | permanent
  "validUntil": "2026-07-31",       // só temporary
  "reason": "Campanha de lançamento",
  "status": "submitted",            // submitted | approved | rejected
  "decidedBy": null,                // { id, name } quando decidido
  "decidedAt": null,
  "decisionNote": null,
  "createdAt": "2026-07-08T14:00:00Z"
}
```

### Extensão do pagamento da carteira (contrato existente)

Payload `POST /wallets/{id}/intents` e intent criado ganham campos **opcionais**:

```jsonc
// no payload de criação
{ "budgetId": "bgt_01", "merchantCategory": "food" }

// no intent criado / linha de extrato (denormalizado)
{ "budget": { "id": "bgt_01", "name": "Marketing" }, "merchantCategory": "food" }
```

## Regras de negócio

1. **Consumo** — pagamento com `confirmed: true` soma no `consumed` do membership do pagador.
   Falha/cancelamento não soma. Estorno fora deste spec.
2. **Limite efetivo do membro** — `temporaryLimit` ativo (hoje ≤ `validUntil`)
   ? `temporaryLimit.limit` : `memberLimit`. Sem ambos, teto = `totalLimit` do orçamento.
3. **Duplo limite** — pagamento marcado num orçamento precisa passar em **duas** verificações
   independentes: limite disponível da carteira **e** limite efetivo do membership. Mensagens
   de bloqueio distintas: "limite da carteira insuficiente" ≠ "limite do orçamento excedido".
4. **Renovação** (monthly/quarterly com `autoRenew`) — na virada do período, `consumed` vai
   para `periodSummaries` e zera. **Gatilho:** job agendado no servidor (`pg_cron` /
   scheduled function) executa a virada (arquiva, zera, avança o período) e remove
   `temporaryLimit` com `validUntil` no passado. No repositório mock (previews/testes),
   simulado lazily no load.
5. **Expiração** (oneTime) — após `endDate`, `status: expired`; novos pagamentos não podem ser
   marcados; histórico permanece visível.
6. **Membership suspenso** — não marca pagamentos; vê histórico; UI mostra "Suspenso".
7. **Total do orçamento** — a soma dos gastos pode ultrapassar `totalLimit`: apenas aviso
   visual. Bloqueio duro é papel do policy engine (doc 04).
8. **Pedido de aumento** — máx. 1 pendente por membership; `currentLimit` é snapshot.
   Aprovar `permanent` → `memberLimit = requestedLimit`. Aprovar `temporary` → seta
   `temporaryLimit { limit, validUntil, requestId }`; reversão = remoção do campo (regra 4).
   Recusa apenas registra `decisionNote`.
9. **Categoria** — `merchantCategory` é escolhida pelo funcionário na revisão do pagamento
   (opcional; default `other`). Pix/boleto não trazem MCC — não há fonte automática neste spec.
10. **Orçamento é opcional** — nenhum pagamento exige orçamento neste spec.

## UX (passe B) — implementado 2026-07-10

- Hub do Início traz a faixa **Meus orçamentos**: card por membership com restante grande e
  barra de consumo nas cores dos marcos 75/90% (as mesmas dos avisos — barra e notificação
  nunca discordam).
- Detalhe do orçamento: restante do limite efetivo em destaque; aumento temporário ativo
  aparece com a data e o valor de retorno; gastos do período (cartão + reembolsos) listados;
  seção **"O que a política exige"** (doc 04) legível antes de qualquer bloqueio.
- **Solicitar aumento**: sheet com valor absoluto, tipo temporário (com validade) ou
  permanente e motivo; o CTA some enquanto existe pedido pendente (regra 8 refletida na UI)
  e o card "aguardando decisão" mostra o de→para.
