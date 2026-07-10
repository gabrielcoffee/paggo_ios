# Extrato — picker de carteira custom, cores claras, renomeações (2026-07-07)

## Objetivo

Melhorar a tela de transações da Carteira ("Extrato"):

1. Substituir o `Menu` nativo de escopo por um componente próprio (`WalletScopePicker`)
   com identidade visual dos cartões e animação de entrada da esquerda.
2. Clarear a cor de identidade dos cartões nas linhas do extrato (hoje escura demais).
3. Renomear a aba "Transações" → "Extrato".
4. `ProfileMenu` (botão com nome no topo esquerdo) apenas na tela Início.

## 1. `WalletScopePicker` (arquivo novo)

`Paggo/Features/Wallet/Transactions/WalletScopePicker.swift`. Substitui `scopePicker`
em `WalletTransactionsView.swift:71-112`.

**Estado fechado — botão:**
- Cápsula (`Theme.surfaceHigh`) com: ponta de cartão em miniatura (~28×18,
  gradiente `style.top→style.bottom`, cantos esquerdos arredondados, borda direita reta —
  cartão "saindo do bolso"), nome da carteira selecionada (ou "Todas as carteiras"),
  chevron que gira 180° ao abrir.
- Escopo "Todas": em vez de uma ponta, 2–3 pontas sobrepostas (deslocadas ~4 pt,
  uma por carteira, máx. 3) — leque em miniatura.

**Estado aberto — painel inline:**
- Expande abaixo do botão, empurrando o conteúdo (sem overlay).
- Uma linha por carteira: ponta de cartão maior (~36×24, mesmo gradiente + fio de luz
  sutil na aresta, ecoando `WalletCardView`), nome, checkmark na selecionada.
- Animação de entrada: cada ponta desliza da esquerda — `offset(x: -40→0)` +
  `opacity(0→1)`, spring (`response: 0.35, dampingFraction: 0.8`), stagger de 50 ms
  por índice.
- Divider + linha "Todas as carteiras" ao final (dispara
  `wallet.ensureAllPaymentsLoaded()`, comportamento atual mantido).
- Selecionar fecha o painel; tocar no botão de novo também fecha (animação reversa).
- `accessibilityReduceMotion` ⇒ apenas fade, sem deslize.

**Contrato do componente:** lê/escreve `wallet.transactionsScope` via
`@Environment(WalletStore.self)`; nenhuma mudança no `WalletStore`.

## 2. Cores accent (claras)

`WalletCardStyle` ganha `let accent: Color`:

| Cartão | top (atual) | accent (novo) |
|---|---|---|
| verde | `#2A3F25` | `#7FB56E` |
| oliva | `#3C3A16` | `#B5AC4E` |
| azul-petróleo | `#1E2E3A` | `#6FA3C7` |
| vinho | `#3A2230` | `#C76F9B` |

Usos que passam de gradiente escuro → `accent` chapado:
- Filete esquerdo das linhas do extrato (`row(_:)` overlay, `WalletTransactionsView.swift:230-235`).
- Bolinha de identidade da carteira no escopo "Todas" (`walletDot` some junto com o Menu
  antigo; a bolinha da linha, `WalletTransactionsView.swift:205-215`, usa `accent`).

Cartões grandes (`WalletCardView`) não mudam.

## 3. Renomear aba

`WalletRootView.swift:37`: `Tab("Transações", …)` → `Tab("Extrato", …)`.
Enum case `transacoes` permanece (compat com `PAGGO_WALLET_TAB`).

## 4. ProfileMenu só no Início

- Remover `ToolbarItem` de `WalletTransactionsView.swift:47`.
- Remover `ToolbarItem` de `WalletPaymentMenuView.swift:67-68`.
- Consequência aceita: drawer de perfil/modo acessível apenas pelo Início
  (header acima do "Boa tarde, …"). Dashboard (modo plataforma) não muda.

## Erros / casos-limite

- 0 carteiras: picker não renderiza (extrato já mostra empty state).
- 1 carteira: botão renderiza, painel mostra a única + "Todas as carteiras".
- Nomes longos: `lineLimit(1)` + truncamento, como hoje.

## Verificação

1. `xcodegen` (se arquivo novo) + build sem warnings (Swift 6 strict concurrency).
2. Simulator `PAGGO_WALLET_TAB=transacoes`: abrir/fechar picker, stagger da esquerda,
   seleção muda escopo, "Todas" mostra bolinhas accent, filetes claros, aba "Extrato",
   sem ProfileMenu no Extrato/Pagar, presente no Início.
3. Reduce Motion ligado: fade sem deslize.
