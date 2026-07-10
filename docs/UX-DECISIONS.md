# UX — decisões e inovações (lado funcionário)

Decisões de UX do modo Carteira (employee), com as referências que as motivaram.
Pesquisa: Mobbin (Brex iOS, Mercury, Expensify, Airwallex), 2026-07-10.

## Estrutura

- **Home = hub de ações** — o funcionário abre o app pra fazer algo (pagar, ver cartão,
  pedir reembolso), não pra contemplar saldo. Números ficam informativos: disponível da
  carteira ativa no topo, orçamentos em faixa compacta.
- **Tab bar: Início · Extrato · Avisos · Perfil** — abas são lugares; ações (Pagar,
  Reembolso) são fluxos que abrem do hub. "Pagar" saiu da tab bar da versão anterior.
- **Disponível no topo = carteira ativa** (chip seletor, troca por sheet), nunca soma de
  carteiras — soma mente por omissão (5k + 2k não pagam boleto de 6k).

## Inovações vs base atual

| Inovação | Referência | Detalhe |
|---|---|---|
| Aba **Avisos** funde pendências acionáveis + notificações | [Brex — tab Tasks com badge](https://mobbin.com/screens/20068687-9cef-4aef-bed2-e2bb5d7756c8) | Seção "Pendências" (anexar recibo, alocar, pedido aguardando) com deep-link + seção "Avisos" (readAt). Badge = não-lidas + pendências. |
| **Política legível** no detalhe do orçamento | [Brex — limit detail com regras](https://mobbin.com/screens/481a6913-2abe-44b2-9790-56226f75e00b) | Seção "O que a política exige" derivada de `policies` (recibo acima de X, categorias bloqueadas, teto por transação). Funcionário descobre a regra antes de estourar, não no decline. |
| **Ícones de conformidade por linha** no extrato | [Brex — expense rows](https://mobbin.com/screens/fa17ae10-11bc-47ca-854b-a427d7a455a1) | Recibo ok/faltando + alocação pendente visíveis na lista, sem abrir a transação. |
| Sucesso do reembolso com **expectativa de prazo** | Mercury — "paid within 24h" | Usa `estimatedPaymentDate` (D+2) na tela de sucesso. |
| Reembolso **valor primeiro** (numpad grande) | Expensify — create expense | Valor → formulário → revisão; menor fricção no caso comum. |
| Recusa de cartão com **motivo em pt-BR e ordem fixa** | — (derivado da spec doc 02) | Estado → política → carteira → limite do membro; o funcionário sabe o que resolver. |

## Alternativas consideradas e rejeitadas

- **"Switch limit" (Brex)** — 1 cartão que troca de orçamento por contexto. Rejeitado:
  nosso modelo cartão→membership dá atribuição determinística (toda compra nasce com dono
  e verba); N cartões virtuais custam zero. Fica registrado como evolução possível.
- **Soma de carteiras no hub** — ver acima.
- **Envelope fundado** (dinheiro dentro do budget) — rejeitado no passe A; budget conta,
  carteira move.

## Dados sensíveis (regras vinculantes)

- Fixtures novos usam `hasPin: Bool` — o **valor** do PIN nunca desce pro cliente.
  Divergência do wire legado (`walletUsers[].pin` em `GET /wallets`): corrigir quando a
  carteira migrar pro Supabase; validação de PIN é sempre server-side.
- PAN/CVV de fixture são marcadamente falsos; tela de reveal usa `privacySensitive()`,
  cópia via `UIPasteboard` com `localOnly` + expiração; valor revelado nunca é logado nem
  persistido. Fase live: RPC `revealCard` exige step-up (Face ID local não é autorização).
- `users.role` (`admin | employee`) existe no fixture; no live, modo Plataforma é
  escondido de `employee` e o servidor nega por RLS (passe C).

## Regras de arquitetura (fase mock)

1. Mock repository (actor) = servidor de mentira: regras server-side da spec (duplo
   limite, policy engine, declines, auto-aprovação, virada de período) executam nele —
   nunca em View/Store. Troca mock→Supabase = troca de implementação.
2. Dono único: mutação vai pro repo; stores invalidam e recarregam — nenhuma store edita
   cópia local de entidade de outro domínio.
3. Dinheiro derivado (`min(limit, balance)`, limite efetivo, %) = computed puro no model;
   view só formata.
4. Pendências são derivadas dos repos na hora, nunca cacheadas em store própria.
