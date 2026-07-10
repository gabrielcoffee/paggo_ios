# Wallet — roteiro de demo (mock)

A wallet roda 100% mock com **fixtures no shape real dos contratos**.
Inputs específicos disparam cenários específicos — tudo determinístico (lógica em
`Mocks/MockWalletRepository.swift`).

## Como entrar

Perfil (avatar) → **Carteira** — ou direto:

```bash
SIMCTL_CHILD_PAGGO_SCREEN=wallet xcrun simctl launch booted com.gabrielpereira.paggo
```

PIN da Carteira Obra Centro: **1234** (vem de `wallets.json > walletUsers`). A Carteira
Suprimentos **não tem PIN** — pagamento pula essa etapa.

## Tabela de cenários

| Onde | Input | Resultado |
|---|---|---|
| Pix chave | qualquer chave (ex. `113.036.437-23`, `pix@paggo.ai`) | DICT: Thiago Morales / Santander; valor livre |
| Pix chave | `(21) 99999-0000` | normalizada para `+5521999990000` antes do DICT |
| Pix chave | chave contendo `naoexiste` | "Chave Pix não encontrada" |
| Pix chave | colar um código EMV (`000201…`) | rejeição: "use a opção Pix Copia e Cola" |
| Copia e Cola / QR | qualquer código | decode estático, valor livre |
| Copia e Cola / QR | código contendo `fixo` | QR dinâmico: valor **fixo R$ 152,90**, campo travado |
| Copia e Cola / QR | código contendo `invalido` | "QRCode inválido" |
| Valor (qualquer Pix) | **R$ 777,77** | intent duplicado → tela de comparação lado a lado |
| Valor | **R$ 999,99** | saldo insuficiente → toast, permanece na revisão |
| Valor | **R$ 444,44** | evento `confirmed:false` → tela de falha |
| Valor | **R$ 555,55** | sem evento → tela "demorado" após 30 s* |
| Valor | acima do limite disponível | bloqueio client-side na revisão |
| Valor | acima de R$ 6.000,00 | teto por pagamento |
| Boleto | linha começando `34191` | boleto limpo R$ 1.004,86, valor travado |
| Boleto | linha começando `23793` | multa R$ 24,80 + juros R$ 9,92 → final R$ 1.274,72 |
| Boleto | linha começando `999` | "não está disponível para pagamento" |
| Boleto | linha começando `2370` | `allowChangeValue` → valor editável entre R$ 100 e R$ 1.000 |
| PIN | `1234` | válido |
| PIN | qualquer outro | erro + shake |

\* encurte com `SIMCTL_CHILD_PAGGO_WALLET_DELAYED_SECONDS=5` (só DEBUG).

## Roteiro sugerido (5 min)

1. **Home** — carteiras (carrossel), limite disponível/usado, esconder saldo, trocar carteira.
2. **Pix por chave** — `113.036.437-23` + R$ 152,90 → localização → revisão (recebedor real
   do DICT) → PIN 1234 → Lottie de processando → sucesso → **"Adicionar comprovante agora"**
   cai direto no extrato.
3. **Extrato** — pagamento novo no topo (Processando→Confirmado), limite da carteira reduzido.
   Abrir a transação: comprovante + seções de **descrição, anexos, alocações**. Anexar foto +
   alocar 60/40 → badge "Pendências" some ao voltar.
4. **Duplicado** — novo Pix com R$ 777,77 → comparação com pagamento existente da plataforma.
5. **Boleto com encargos** — `23793…` → multa/juros discriminados, valor final calculado.
6. **Falha e demorado** — R$ 444,44 e R$ 555,55 (com env de 5 s) → Lottie de falha/atraso.
7. **Device físico**: QR/código de barras com câmera real (VisionKit; qualquer código funciona —
   roteia pro fixture). No simulador aparece o campo de colar.

## Envs de debug (DEBUG builds)

`PAGGO_SCREEN=wallet` · `PAGGO_WALLET_TAB=inicio|pagar|transacoes` ·
`PAGGO_WALLET_PAY=pixKey|pixCopyPaste|pixQR|boleto` ·
`PAGGO_WALLET_PAY_STEP=review|duplicated|pin|success|delayed|failed` ·
`PAGGO_WALLET_PAY_RESULT=success|delayed|failed` · `PAGGO_WALLET_PAY_DUPLICATE=1` ·
`PAGGO_WALLET_DELAYED_SECONDS=n` · `PAGGO_WALLET_DETAIL=1` · `PAGGO_WALLET_CARDS=1`

Sempre prefixar com `SIMCTL_CHILD_` no `simctl launch`.
