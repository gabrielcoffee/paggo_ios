# Changelog

Formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), enxuto. Datas ISO.

## [Unreleased]

### Added
- `docs/UX-DECISIONS.md` — decisões de UX do lado funcionário, inovações e regras de
  arquitetura da fase mock (pesquisa Mobbin 2026-07-10).
- Fundação do lado funcionário: tab bar do modo Carteira agora é Início / Extrato /
  Avisos / Perfil (Pagar vira ação do hub); modelos das 6 features no shape do passe A
  (`Budget`, `BudgetMembership`, `LimitRequest`, `CorporateCard`, `CardTransaction`,
  `Reimbursement`, `SpendPolicy`, `SmartReceipt`, `AppNotification`, `Assistant*`);
  `SpendMockServer` (actor único, regras server-side) + repositórios/fachadas + fixtures
  coerentes; stores `Budget/Card/Reimbursement/Notice/Chat`; componentes `ConsumptionBar`,
  `ComplianceIcons`, `ActionTile`; telas de Avisos (pendências derivadas + notificações)
  e Perfil.

## [0.1.0] — 2026-07-10

### Added
- Estado inicial publicado: app iOS (admin: Dashboard/Solicitações/Pagamentos/Aprovações;
  carteira: Início/Pagar/Extrato), wallet-pwa de referência, specs passe A das 6 features
  (`docs/specs/00..06`).
