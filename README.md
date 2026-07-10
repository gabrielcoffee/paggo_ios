# Paggo — Native iOS

A native **SwiftUI / iOS 26** app reimplementing a focused subset of
[`apps/paggo-mobile-app`](../apps/paggo-mobile-app) (React Native / Expo) as a fully native
experience. Built on the layout, patterns and UI/UX of the `ios-pocs` reference project —
Liquid Glass, Swift Charts, a Revolut-style dark theme with the Paggo terracotta accent, and
Inter typography.

**No backend.** Everything is mocked behind protocol-based repositories using the DTOs and
business logic ported faithfully from the mobile app (`src/domain/entities`, `src/mocks`,
`src/utils/formatters.ts`, `src/core/constants`). Swap the `Mock*Repository` implementations
for a real client later — the views and stores don't change.

## Features

Access is gated by a **Login** screen (full-bleed architectural background image, the Paggo
logo lockup, and a floating Liquid Glass card):

- **No saved user** — sign in with **Google**, **Microsoft**, or **e-mail** (the e-mail option
  opens a glass sheet with email + password). All sign-in is mocked behind `AuthRepository`.
- **Returning user** — a one-tap **"Entrar como {nome}"** shortcut authenticates with **Face ID**
  (`LocalAuthentication`) and drops straight into the app. The saved user persists in
  `UserDefaults`; "Usar outra conta" / "Esquecer este dispositivo" manage it. Sign out from the
  Dashboard profile menu (top-left avatar).

1. **Dashboard (Visão geral)** — consolidated balance hero with count-up animation, balance
   history chart, entradas/saídas insights, and the list of connected bank accounts (tap an
   account for its statement). Toggle balance visibility from the toolbar.
2. **Payments (Pagamentos)** — the 6 Payout status tabs (Previstos · Pendentes · Validação ·
   Liberação · Agendados · Pagos) with live counts, package cards (tags, status, amount, date,
   approvers), filters (search / status / payer / tags / high-value), sorting (date / amount /
   receiver), multi-select with bulk **approve / send-to-approval / return**, and a full
   **tabbed detail screen** — a 1:1 port of the Expo `PackageDetails`:
   - **Detalhes** — alerts, payer→receiver summary (+ fine/interest/discount), payment-type &
     tags, description, payment method (PIX key / account / QR / boleto / barcode, with bank-name
     map, EMV and digitable line), allocations (% + calculated + cost-center/managerial/project),
     grouped approvers (per release group, with e-mail and approved/pending/rejected state), and
     **Origem** (payment-request with installments / reimbursement / payroll / wallet).
   - **Documentos** — fiscal document entries with status, counterparty, net amount, date and a
     reconciliation progress bar; plus attachments.
   - **Orçamento** (when the payment consumes budget) — per-line consumption bars with
     over-budget warnings.
   - **Conciliação** — reconciliation status, linked financial entry and config flags.
   - **Histórico** — chat with platform events + message bubbles and a send box.
   - Action **footer** (Liberar / Retornar / Rejeitar / Cancelar / Pago Externamente / Enviar
     para Liberação, by status) with an MFA verification-code modal on release.
3. **Approvals (Aprovações)** — every payment pending release (`WAITING_APPROVAL`) with inline
   **approve / return**. Shares the same `PayoutStore`, so an approval here updates the
   Payments tab badge instantly.

## Stack

- **SwiftUI** + **Liquid Glass** (iOS 26)
- **Swift Charts** — animated balance area/line chart
- **Observation** (`@Observable`) — MV architecture, lightweight stores, no per-view view models
- **Swift 6** strict concurrency (`complete`)
- **Adaptive theming** — every `Theme` token is a dynamic light/dark color, driven by an
  appearance preference (Claro / Escuro / Sistema) in the profile menu; the login stays dark
- **LocalAuthentication** — Face ID / Touch ID for the returning-user shortcut
- Protocol-based repositories with deterministic mock data (money in **cents**, pt-BR locale)

## Requirements

- Xcode 26.x (iOS 26 SDK)
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Generate & run

```bash
# 1. Generate the Xcode project from project.yml
xcodegen generate

# 2. Open in Xcode
open Paggo.xcodeproj

# — or build/run from the CLI on the simulator —
xcodebuild -scheme Paggo \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

The `.xcodeproj` is generated (and git-ignored). Re-run `xcodegen generate` after adding or
removing files.

> The iOS 26 simulator runtime ships without devices pre-created. If `xcodebuild` can't find a
> destination, create one once:
> `xcrun simctl create "iPhone 16 Pro (26.5)" com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5`

### Debug — open a single screen

Launch directly into one feature, bypassing login (used for UI verification):

```bash
SIMCTL_CHILD_PAGGO_SCREEN=payments xcrun simctl launch booted ai.paggo.mobile
```

Supported: `dashboard`, `payments`, `approvals`, `detail`. For `detail`, pick the initial tab
with `PAGGO_DETAIL_TAB` (`details` · `documents` · `budget` · `conciliation` · `history`):

```bash
SIMCTL_CHILD_PAGGO_SCREEN=detail SIMCTL_CHILD_PAGGO_DETAIL_TAB=budget xcrun simctl launch booted ai.paggo.mobile
```

### Debug — login states

```bash
# Seed a saved user → the "Entrar como Igor" (Face ID) screen
SIMCTL_CHILD_PAGGO_AUTH=saved  xcrun simctl launch booted ai.paggo.mobile

# Seed + auto-trigger the Face ID prompt on appear (for verifying the biometric path)
SIMCTL_CHILD_PAGGO_AUTH=faceid xcrun simctl launch booted ai.paggo.mobile
```

With no env var the app starts logged out at the provider list. To exercise Face ID in the
simulator, enroll a face first (**Features ▸ Face ID ▸ Enrolled**), launch with
`PAGGO_AUTH=faceid`, then approve via **Features ▸ Face ID ▸ Matching Face**.

### Debug — appearance

The appearance preference lives in the Dashboard profile menu (Claro / Escuro / Sistema). Force
it for a screenshot with `PAGGO_APPEARANCE` (overrides the device setting):

```bash
SIMCTL_CHILD_PAGGO_SCREEN=dashboard SIMCTL_CHILD_PAGGO_APPEARANCE=light xcrun simctl launch booted ai.paggo.mobile
```

## Project layout

```
Paggo/
├─ App/             App entry + Liquid Glass TabView root
├─ DesignSystem/    Theme, typography, spacing + reusable components (ported from ios-pocs)
├─ Extensions/      Color(hex:), Money (cents → BRL), ISO date formatting
├─ Models/          DTOs ported from paggo-mobile-app + tab/status/tag display mappings
├─ Mocks/           Deterministic mock data mirroring src/mocks/*
├─ Services/        Repositories (protocol + mock) · Auth/Payout/Bank stores · biometrics
├─ Features/        Login · Dashboard · Payments · Approvals
└─ Resources/       Info.plist, Inter fonts, Assets (accent, background, app icon)
```

## Theming

All color/gradient tokens live in `Paggo/DesignSystem/Theme.swift`. Each token is an **adaptive**
color — a `(light, dark)` pair resolved per trait — so the entire app follows the appearance
preference automatically with no per-view changes. Swap the accent there (and `AccentColor` in
`Assets.xcassets`) to rebrand.
