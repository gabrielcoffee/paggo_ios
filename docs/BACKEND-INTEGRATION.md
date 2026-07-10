# Backend Integration — Plan & Patterns

How the native app connects to the **mobile-api** backend, mirroring `apps/paggo-mobile-app`.
This doc is the plan + the recipe for wiring each endpoint.

## TL;DR — the stack

| Concern | Choice | Why |
|---|---|---|
| Transport | **URLSession + async/await** (`APIClient`) | Native, zero deps, full control to mirror the axios interceptors |
| Contracts | **Codable DTOs ported from `@paggo/payments-service/*` Zod types** | Reuse the existing typed endpoints; same shapes the Expo app uses |
| Auth | **Keychain** (`TokenStore`) + single-flight refresh (`TokenRefresher` actor) | Direct port of the axios refresh queue; secure token storage |
| Server-state cache | **`QueryClient`** — stale-while-revalidate, keyed, deduped, **disk-persisted** | Native equivalent of TanStack Query; the team's mental model; offline reads |
| Mutations | async repo/API calls + cache invalidation | |
| Offline writes | **`Outbox`** (persisted queue, replays on reconnect) | "Offline mode with proper mutation" |
| Connectivity | **`NWPathMonitor`** (`Connectivity`) | Drives offline fallback + Outbox flush |
| DI / switch | **`ServiceContainer`** + `AppConfig.dataSource` (`mock`\|`live`) | Flip to backend without touching screens |

No third-party Swift dependencies. Tier-2 upgrade path (GRDB / SwiftData / OpenAPI codegen) at the bottom.

## Layers

```
SwiftUI View ─ .task ─▶ Store (@Observable)          ← loading / error state
                          │
                          ├─▶ QueryClient.fetch(key) { … }     ← cache + SWR + offline read
                          │        └─▶ PayoutAPI (pure network) ─▶ APIClient ─▶ mobile-api
                          │                                           │ Bearer + api-key + device headers
                          │                                           │ 401 → TokenRefresher → retry
                          └─▶ Outbox.enqueue(...)              ← offline mutations, replay on reconnect
```

Repositories stay the seam: `Mock*` (offline-dev/previews/tests) and live (`PayoutAPI` / future `Live*Repository`) are interchangeable behind protocols.

## What's scaffolded

```
Paggo/Core/AppConfig.swift            env (base URLs, api key) + dataSource flag (mock|live)
Paggo/Networking/
  APIError.swift                      normalized error (offline/unauthorized/server/decoding)
  Endpoint.swift                      typed endpoint + JSONEncoder/Decoder.api
  TokenStore.swift                    Keychain token storage (+ in-memory mock)
  TokenRefresher.swift                single-flight token refresh (actor)
  APIClient.swift                     URLSession transport: headers, auth, 401-retry, decode
  Connectivity.swift                  NWPathMonitor → isOnline
  QueryClient.swift                   SWR cache + disk persistence + PaymentKeys
  Outbox.swift                        offline mutation queue (persisted)
Paggo/Services/
  PayoutAPI.swift                     reference live service (mirrors payout.service.ts)
  ServiceContainer.swift             DI: picks mock|live
```

The backend contract (base URL, headers, refresh, endpoint list) is captured in the reference
section below and mirrors `apps/paggo-mobile-app/src/data/api/axios.client.ts` + `payout.service.ts`.

## Recipe — add an endpoint (using the mobile-app as reference)

1. **Find the route** in `apps/paggo-mobile-app/src/data/services/<domain>/<domain>.service.ts`
   (method + path) and the **response DTO** (`@paggo/payments-service/<domain>/<name>.type`).
2. **Port the DTO** to a Codable Swift struct (see DTO mapping below). Reuse existing models when
   they already match (`Package`, `PackageTotals`, `PackageDetails`, the `*Section` models).
3. **Add a method** to the domain API service (e.g. `PayoutAPI`) using `client.send(.get/post(...))`.
4. **Consume it** from a store wrapped in `QueryClient` (reads) or via the Outbox (offline writes):

```swift
// Read with cache + offline fallback
let summary = try await QueryClient.shared.fetch(PaymentKeys.summary(id), staleTime: 30) {
    try await container.payoutAPI.summary(id: id)
}

// Mutate + invalidate
_ = try await container.payoutAPI.approve(items)
QueryClient.shared.invalidate(prefix: PaymentKeys.detail(id))
```

## Reusing the TS / Zod DTOs

Map each Zod type to a Codable struct, 1:1 by field name (camelCase, no key strategy):

| Zod (TS) | Swift |
|---|---|
| `z.string()` / `.uuid()` | `String` |
| `z.number().int()` (cents) | `Int` |
| `z.boolean().default(false)` | `Bool` *(see gotcha)* |
| `z.string().optional()` / `.nullish()` | `String?` |
| `z.nativeEnum(X)` | `enum: String, Codable` |
| `z.date()` (serialized) | `String` (ISO) — parse with `DateText` |
| `z.array(...)` | `[T]` |

**Decoding gotcha:** Swift's synthesized `Decodable` does **not** use property defaults — a
non-optional field whose key is absent in the JSON throws. For backend responses, either make the
field `Optional` or add a custom `init(from:)` using `decodeIfPresent`. (The enriched
`PackageDetails` fields like `alerts`/`consumesBudget` are app-composed from per-section endpoints,
so don't decode `GET /package/{id}` straight into `PackageDetails` — fetch sections and compose.)

**At scale:** if the mobile-api emits an OpenAPI document (e.g. via `zod-to-openapi` on the
backend), adopt **swift-openapi-generator** to generate the client + types instead of hand-porting.

## Caching & offline (`QueryClient`)

- `fetch(key, staleTime:)` returns fresh cache if within `staleTime`; otherwise hits the network,
  persists to disk, and returns. On transport failure / offline it returns the **last cached value**
  (memory → disk), so screens render offline.
- `invalidate(prefix:)` clears a subtree (e.g. `PaymentKeys.detail(id)`); `setData` writes optimistic values.
- Keys mirror `paymentKeys.ts` (`PaymentKeys.summary(id)` …). Default `staleTime` choices follow the
  Expo app (5 min general, 30 s for fast-changing like summary).

## Mutations & offline outbox

- **Online:** call the API method, then `invalidate` the affected keys (optionally `setData` first
  for an optimistic update).
- **Offline:** enqueue an `OutboxItem` (method/path/body + keys to invalidate). On reconnect
  (`Connectivity.isOnline → true`) call `Outbox.shared.flush(send:)` to replay; failures stay queued.

## Auth & token refresh

`APIClient` injects `api-key`, device headers (`x-device-id`/`x-bundle-id`/`x-platform`/User-Agent)
and `Authorization: Bearer`. Expired token → `TokenRefresher` (single-flight) hits
`POST {authBaseURL}/auth/refresh` `{ refresh_token, session_id }`. A 401 triggers one refresh + retry.
Tokens live in the Keychain (`TokenBundle`).

### Login (Firebase + Google) — implemented

Every provider exchanges through Firebase → `POST /auth/login` (mirrors `completeFirebaseLogin`):

```
Google: GoogleSignIn → Firebase GoogleAuthProvider credential → Firebase user → id_token
E-mail: /auth/message-token (OTP) → /auth/validate-message-token → /generate-custom-token
        → Firebase signInWithCustomToken → id_token
then:   userByEmail(email) → {id, customerId}  →  POST {authBaseURL}/auth/login
        { id_token, provider, device_*, platform_user_id, platform_customer_id }
        → { access_token, refresh_token, session_id, expires_in }  → Keychain
```

Files: `AuthAPI.swift` (endpoints), `SessionService.swift` (`FirebaseBootstrap` + Google/e-mail
orchestration, all `@MainActor`), wired into `AuthStore` (live path) + `EmailLoginSheet` (OTP).
The SPM packages `firebase-ios-sdk` (FirebaseAuth) and `GoogleSignIn-iOS` are in `project.yml`.

### Config — wired (from the production env)

- **Firebase is configured programmatically** in `FirebaseBootstrap.configure()` from `AppConfig`
  (mirrors the Expo `src/config/firebase.ts`) — **no `GoogleService-Info.plist` needed**. The
  public Firebase + Google client IDs live in `AppConfig` (committed); the **API key** lives in
  `Paggo/Resources/Secrets.plist` (**git-ignored**, see `.gitignore`) read at runtime.
- **URLs**: production `paggo-mobile-api.paggo.ai/v1` (API) + `mobile-auth.paggo.ai/v1` (auth).
- **Google callback URL scheme** (reversed iOS client id) is in `Info.plist` `CFBundleURLTypes`.
- **`dataSource` defaults to `.live`** when `Secrets.plist` provides the API key; force mock with
  `PAGGO_DATA_SOURCE=mock`.

**Verified end-to-end:** the legitimate chain (generate-custom-token → Firebase
`signInWithCustomToken` → `/auth/login` → `GET /packages`) returns real data, and the app renders
it live (Approvals showed a real `WAITING_APPROVAL` package). To exercise the data path in the
sim without interactive login, seed a session: `PAGGO_SESSION_ACCESS_TOKEN` / `_REFRESH_TOKEN` /
`PAGGO_SESSION_ID` (debug-only, `DevSession.seedIfNeeded`).

**Caveat — Google interactive login:** the Firebase project only has a **web** app (the Expo app
uses the JS SDK), so `AppConfig.firebase.googleAppID` is an `:ios:` **placeholder** (Auth itself
uses apiKey+projectID). For robust production Google sign-in, register an **iOS app** in the
Firebase console (real `GoogleService-Info.plist` / iOS app id) and ensure the iOS OAuth client is
linked to the project's Google provider. Interactive Google consent couldn't be verified headlessly.

(Microsoft = MSAL; currently shows "em breve". Add `MSAL` SPM + Azure config + an
`OAuthProvider.credential` path in `SessionService`, same exchange.)

`AuthStore.signOut()` (live) calls `/auth/logout`, clears the Keychain, and signs out Firebase +
Google. The Face ID shortcut re-checks for a valid Keychain session and forces re-login if expired.

## Migrating a store from mock → live (sync → async)

Today the stores load mocks synchronously in `init`. To go live:

1. Give the store a `load()` async + `isLoading` / `error` published state; remove sync work from `init`.
2. In `load()`, read via `QueryClient.fetch(...) { try await container.payoutAPI.xxx() }`.
3. Call `.task { await store.load() }` from the screen; show a skeleton while `isLoading`.
4. Turn mutation methods async: call the API, `invalidate`, refetch (or `setData` optimistically;
   enqueue to `Outbox` when offline).

Until a store migrates it keeps using `Mock*Repository` (default `dataSource = .mock`).

### Reference: Payments list (migrated)

`PayoutStore` is the worked example: async `load(force:)` loads all tabs + totals concurrently via
`PayoutRepository` (`Live` = `PayoutAPI` + `QueryClient` with offline fallback; `Mock` = instant).
It exposes `isLoading` / `loadError` / `isOffline` / `hasLoaded`; `PaymentsView` + `ApprovalsView`
call `.task { await store.load() }`, `.refreshable { await store.load(force: true) }`, and render
loading / error-with-retry / offline-banner states. Bulk actions move optimistically, then `commit`
to the backend (live), reverting via reload on failure.

### Reference: Payment detail (migrated, live per-section)

`PackageDetailStore` (`Services/PackageDetailStore.swift`) loads ONE payment's detail. Mock →
assembles from `MockData.details`. Live → seeds a `PackageDetails` from the base `Package`, fetches
`GET /payments/{id}/summary` first (gates the screen; provides amounts, flags, `consumesBudget`,
document entries), then the rest **in parallel**: `tags`, `methods`, `allocations`, `approvers`,
`delivery-document`, `conciliation`, `alerts`, and `budget` (only when `consumesBudget`). Each
section paints as it arrives, with a **per-section skeleton** while loading. Endpoints + tolerant
DTOs live in `Networking/PaymentDetailsAPI.swift` (`Remote*` structs mirroring
`@paggo/payments-service/*`, every field optional so a missing/renamed field degrades to "—" instead
of crashing). `PackageDetailView` owns the store and renders skeletons per section.

### Skeletons

`DesignSystem/Components/Skeleton.swift` — shimmer placeholders (`Skeleton`, `PackageListSkeleton`,
`DetailSectionSkeleton`) replace spinners on the payments list, approvals, dashboard, and each detail
section/tab. Respects Reduce Motion.

### Filters (server-side, all `/package-filters` categories)

`PayoutFilters.selections` holds per-category selected ids; `categoryQueryItems()` maps them to
`/packages` query params. Options (with counts) come from **`GET /package-filters`** via
`PayoutAPI.filterOptions` → `PackageFilterOptions` (lenient decode handling array vs map shapes).
`FilterSheet` renders every returned category dynamically (Pagador, Contraparte, Método, Tipo,
Etiquetas, Origem, Projeto, Centro de custo, Conta gerencial, Unidade, Solicitante, Categoria da
empresa, Instituição financeira, Documento) plus search, in-tab status, and "alto valor". Applying
reloads the tabs server-side (live); search/status/high-value stay client-side. Mock derives
Pagador/Contraparte/Etiquetas from the loaded packages so the sheet isn't empty offline. Debug:
`PAGGO_OPEN_FILTERS=1`.

**Full parity with `apps/blue/src/modules/payout`** — beyond the categorical filters, `PayoutFilters`
also carries the remaining blue filters: **6 date ranges** (`paymentDate`, `dueDate`, `paidAt`,
`createdAt`, `provisionApprovedAt`, `documentDate` — toggleable from/until pickers), **2 option
toggles** (`documentConnected`, `onTime` — Todos/Sim/Não), and **2 text fields** (`beneficiaryName`,
`beneficiaryTaxId`). All map to `/packages` query params via `PayoutFilters.queryItems()`.
⚠ The date-range param encoding (`paymentDate=<from>,<to>` yyyy-MM-dd) and the `documentConnected`/
`onTime`/`beneficiary*` param names are best-effort against the mobile-api and should be verified
live; unknown params are ignored server-side, so they degrade gracefully.

### Reference: Banking / Dashboard (migrated)

`BankStore` is async too: `load(force:)` fetches **all account balances** + the **consolidated
group balance history** concurrently (best-effort history, so balances render even if history is
unavailable), with `isLoading` / `loadError` / `isOffline`. `DashboardView` calls
`.task { await bank.load() }` + `.refreshable`, and hides the movements/recent-activity sections on
live (no endpoint yet) so only real data shows.

- **Balances** → `GET /treasury/v2/banking-accounts` (existing; `Treasury.getBankingAccounts`).
  `BankingAPI` decodes the INTERNAL (`balance: number`) / EXTERNAL (`balance: { balance }`) union.
- **Consolidated group history** → **new** `GET /treasury/banking-accounts/balance-history`
  (added to `sst/mobile-api`, **non-breaking**; optional `startDate`/`endDate`, **defaults to last
  30 days**). It mirrors the web (`apps/blue/.../home-dashboard.service.ts#getBalanceHistory`)
  **exactly**: pulls from **BaaS `/accounts/balance-history`** (`cutoff_time=24`, `date_from/to`),
  then builds a **dense daily grid** where each account is **forward-filled** from its last snapshot
  (start 0) and **summed per day** (`buildDailyGroupSeries`, pure + unit-checked). This is the fix
  for the earlier "spiky" chart — that came from using the sparse Prisma balance-history table and
  emitting only days with entries. **Needs a mobile-api deploy** to be live.
- **Range switching:** native `BankStore.historyRange` (default `last30`; also `last60`, `thisMonth`,
  `thisYear`) maps to `startDate`/`endDate`; the Dashboard shows a chip selector and reloads only the
  chart on change. Debug: `PAGGO_HISTORY_RANGE=last60|thisMonth|thisYear`.
- Movements (Entradas/Saídas) + transactions aren't exposed by the mobile-api yet → empty on live.

## Going live

Set the data source + keys (env vars for local, `.xcconfig` / Info.plist for builds):

```bash
PAGGO_DATA_SOURCE=live \
PAGGO_API_URL=https://paggo-mobile-api.staging.paggo.ai/v1 \
PAGGO_API_KEY=… \
SIMCTL_CHILD_PAGGO_DATA_SOURCE=live xcrun simctl launch booted ai.paggo.mobile
```

## Endpoint reference (confirmed from `payout.service.ts`)

`GET /packages?{query}` · `GET /package/{id}` · `GET /packages-totals` · `GET /package-filters` ·
`POST /packages/approve` `{packages:[{id,paymentDate}]}` · `POST /packages/cancel-approval`
`{packageIds}` · `POST /packages/send-to-approval` `{packageIds}` ·
`POST /package/create-chat-message` `{id,message,type}` ·
`GET /payments/{id}/{summary|tags|allocations|approvers|methods|delivery-document|budget|conciliation|alerts|chat|document-entries|attachments}`

**Treasury / banking:** `GET /treasury/v2/banking-accounts` (accounts + balances) ·
`GET /treasury/banking-accounts/balance-history` (**new** — consolidated group balance history;
optional `startDate`/`endDate`, defaults to last 90 days) · `POST /treasury/v2/execute-transfer`.

## Tier-2 (when offline complexity grows)

- **GRDB** or **SwiftData** for a normalized local-first store (reactive queries, complex offline
  joins). Swap behind the repository + `QueryClient` seam — no screen changes.
- **swift-openapi-generator** for generated, always-in-sync client + types.

### Transfers (move money between accounts)

Dashboard ("Visão geral") has a top-right ⇄ button opening `TransferView` (`Features/Transfer/`):
two account selectors (origin/destination, via `AccountPickerSheet` — Revolut-style list + search),
a big R$ amount with a custom numpad, and a **Face ID confirmation** (MFA analog) before executing.
It reuses the existing `POST /treasury/v2/execute-transfer` (no new endpoint) with
`transferType: "INTERNAL"` (`TransferAPI.executeInternalTransfer` → `{ originBankingAccountId,
destinationBankingAccountId, amount(cents), description }`). Mock simulates success; on success the
dashboard reloads balances. Validates amount ≤ origin balance and ≤ R$ 2.000.000. Debug:
`PAGGO_OPEN_TRANSFER=1`.
