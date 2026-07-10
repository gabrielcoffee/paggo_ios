# Changelog

Formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), enxuto. Datas ISO.

## [0.2.0] — 2026-07-10

Lado funcionário (specs 01–06) implementado em SwiftUI sobre repositórios mock, no visual
da plataforma. Parte admin intocada.

### Added
- `docs/UX-DECISIONS.md` — decisões de UX, inovações e regras de arquitetura da fase mock.
- Fundação: tab bar do modo Carteira vira Início / Extrato / Avisos / Perfil (Pagar vira
  ação do hub); modelos das 6 features no shape do passe A; `SpendMockServer` (actor único
  com as regras server-side) + repositórios; stores; componentes `ConsumptionBar`,
  `ComplianceIcons`, `ActionTile`.
- Início (hub): pilha de carteiras + ações Pix/Pagar + linhas Cartão/Reembolsos/Assistente
  + faixa Meus orçamentos com barras 75/90%.
- Orçamentos: lista, detalhe (limite efetivo, aumento temporário, gastos do período,
  política legível) e pedido de aumento (máx. 1 pendente).
- Cartão: reveal com biometria + clipboard local com validade + `privacySensitive`,
  congelar/descongelar, feed com 7 motivos de recusa em pt-BR, correção de categoria.
- Extrato unificado: pagamentos + compras de cartão numa lista, ícones de conformidade por
  linha, detalhe de compra com ajuste de settle explicado.
- Reembolsos: formulário com OCR (Vision, on-device) preenchendo valor/data, política
  visível antes do envio, auto-aprovação, sucesso com previsão D+2, linha do tempo,
  cancelamento em análise.
- Recibos: captura → OCR com confiança por campo → casamento automático (1 candidata) ou
  manual por sugestões; resolve pendências.
- Avisos: pendências derivadas + notificações com deep-link; badge na tab.
- Assistente: chat com action cards (proposed→confirmed→executed) executando nos mesmos
  stores; motor roteirizado atrás de `ChatRepository`.
- Seções "UX (passe B)" nos 6 docs de spec.

## [0.1.0] — 2026-07-10

### Added
- Estado inicial publicado: app iOS (admin: Dashboard/Solicitações/Pagamentos/Aprovações;
  carteira: Início/Pagar/Extrato), wallet-pwa de referência, specs passe A das 6 features
  (`docs/specs/00..06`).
