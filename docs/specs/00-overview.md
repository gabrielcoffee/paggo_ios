# Paggo iOS — Specs de features (overview)

Seis features inspiradas em Ramp/Brex, sobre duas personas: **admin** (aprovações/gestão) e
**funcionário** (carteira). Specs em três passes, **em largura** (um passe por vez em todas as
features): **A — contratos + regras** · **B — UX** · **C — arquitetura**. Cada feature tem seu
documento com o status do passe; este amarra o modelo.

## Convenções (todas as features)

- Dinheiro em **cents** (`Int`), moeda `BRL`, locale pt-BR na exibição
- Campos **camelCase**, idênticos ao wire; datas **ISO-8601**
- Nomes curtos: prefixo `max` (nunca `maximum*`) — ex. `maxLimit`; pagamentos da carteira
  chamam-se `payments` (tabela/contrato), não `walletPayments`. Wire legado do produto real
  (`maximumLimit` no `GET /wallets`) permanece até a migração — a convenção vale pro novo
- Pessoas referenciadas como mini-objeto denormalizado: `{ "id", "name" }` (+ `email` quando útil)
- Entidades exibíveis em lista carregam nome denormalizado (ex.: `budget: { id, name }`)
- Entidades carregam `createdAt`/`updatedAt`
- Enums de status em inglês no wire, tradução na camada de display
- **Backend: Supabase** — dados mockados/seedados, DTOs reais. Os contratos JSON destes docs
  são o wire truth: servidos por views/RPCs (ou Edge Functions) moldados ao contrato, não
  PostgREST cru — mantém o shape compatível com o payments-service real
- Repositórios `Mock*` permanecem para previews/testes (`AppConfig.dataSource: mock|live`);
  Supabase entra como implementação `live` atrás dos mesmos protocolos
- Comportamentos de servidor (viradas de período, expiração de aumentos, feed de transações)
  rodam no servidor (scheduled functions / `pg_cron`) — cada spec define o job

## Mapa de entidades e dependências

```
Budget ─── BudgetMembership ─── Employee
  │              │
  │              ├── LimitIncreaseRequest
  │              └── consumo (via pagamentos confirmados)
  │
  ├── Card (pendura em budget; lastreado numa carteira — auth debita carteira + budget)
  ├── Reimbursement (despesa do bolso; budget opcional; aprovado vira Package na esteira)
  ├── Policy (escopo global ou por budget; enforça categorias/valores)
  └── Notification (thresholds 75/90%, expiração, decisões)

Receipt ── casa com pagamento/cartão (OCR mock); reembolso anexa direto
Chatbot ── executa ações de TODAS as features pelos mesmos stores (sem caminho paralelo)
```

Ordem dos docs: budgets → cartões → reembolsos → policy+receipts → notificações → chatbot.
Cada uma consome contratos da anterior; nenhuma exige a posterior.

## Categorias de estabelecimento (compartilhada)

`materials · food · transport · lodging · fuel · services · software · other`

Neste conjunto de specs as categorias são **dados** (tags, breakdowns). Enforcement (bloqueio)
é exclusivo do policy engine (doc 04). Pix/boleto não trazem MCC — a categoria é escolhida
pelo pagador (default `other`); cartão traz MCC da rede.

## Documentos

| Doc | Feature | Persona dominante | Passe A | Passe B | Passe C |
|-----|---------|-------------------|---------|---------|---------|
| 01 | Budgets + limites | ambas | ✅ 2026-07-08 | — | — |
| 02 | Cartões corporativos virtuais | ambas | ✅ 2026-07-08 | — | — |
| 03 | Reembolsos | funcionário (admin aprova) | ✅ 2026-07-08 | — | — |
| 04 | Policy engine + smart receipts | admin | ✅ 2026-07-08 | — | — |
| 05 | Notificações | ambas | ✅ 2026-07-08 | — | — |
| 06 | Chatbot | ambas | ✅ 2026-07-08 | — | — |
