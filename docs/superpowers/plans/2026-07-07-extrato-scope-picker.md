# Extrato Scope Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Custom wallet-scope dropdown on the Extrato screen with card-tip visuals and slide-from-left animation; lighter card-identity colors; tab renamed to "Extrato"; ProfileMenu only on Início.

**Architecture:** New self-contained SwiftUI view `WalletScopePicker` reads/writes `WalletStore.transactionsScope` via environment (no store changes). `WalletCardStyle` gains an `accent` color used for row identity marks. Two toolbar items removed, one tab label renamed.

**Tech Stack:** SwiftUI (iOS 26), Swift 6 strict concurrency, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-07-07-extrato-scope-picker-design.md`

## Global Constraints

- Swift 6, `SWIFT_STRICT_CONCURRENCY: complete` — new code must build warning-free.
- No new dependencies. Follow existing DesignSystem tokens (`Theme`, `Spacing`, `Radius`, `.brand` fonts).
- Project has no test target; each task's gate is a clean build, final task verifies in simulator.
- Not a git repository — no commit steps.
- New file added ⇒ run `xcodegen` before building (`.xcodeproj` is generated).
- Comments in pt-BR, matching codebase style.
- Build command (used by every task):
  `cd /Users/gabrielpereira/Desktop/ios && xcodebuild -project Paggo.xcodeproj -scheme Paggo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20`
  Expected: `** BUILD SUCCEEDED **`, no warnings mentioning the touched files.

---

### Task 1: Accent colors on `WalletCardStyle` + lighter row identity marks

**Files:**
- Modify: `Paggo/Features/Wallet/Home/WalletCard.swift:4-16` (palette)
- Modify: `Paggo/Features/Wallet/Transactions/WalletTransactionsView.swift:204-215` (identity dot) and `:229-235` (left border)

**Interfaces:**
- Produces: `WalletCardStyle.accent: Color` — flat, lighter identity color per card style. Task 2's `WalletScopePicker` uses `WalletCardStyle.at(index)` (existing) and may use `.accent` for checkmarks.

- [ ] **Step 1: Add `accent` to the palette**

In `Paggo/Features/Wallet/Home/WalletCard.swift`, replace the `WalletCardStyle` struct (lines 4-16) with:

```swift
/// Paleta de gradientes dos cartões da carteira (um tom por carteira).
/// `accent` é a versão clara da cor — usada para identificar o cartão em superfícies
/// pequenas (filete do extrato, bolinhas), onde o gradiente escuro não tem contraste.
struct WalletCardStyle: Sendable {
    let top: Color
    let bottom: Color
    let accent: Color

    static let palette: [WalletCardStyle] = [
        .init(top: Color(hex: "#2A3F25"), bottom: Color(hex: "#0C160B"), accent: Color(hex: "#7FB56E")),  // verde
        .init(top: Color(hex: "#3C3A16"), bottom: Color(hex: "#15140A"), accent: Color(hex: "#B5AC4E")),  // oliva
        .init(top: Color(hex: "#1E2E3A"), bottom: Color(hex: "#0A1016"), accent: Color(hex: "#6FA3C7")),  // azul-petróleo
        .init(top: Color(hex: "#3A2230"), bottom: Color(hex: "#160A11"), accent: Color(hex: "#C76F9B")),  // vinho
    ]

    static func at(_ index: Int) -> WalletCardStyle { palette[((index % palette.count) + palette.count) % palette.count] }
}
```

- [ ] **Step 2: Row left border uses `accent`**

In `Paggo/Features/Wallet/Transactions/WalletTransactionsView.swift`, replace the `.overlay` at the end of `row(_:)` (lines 229-235):

```swift
        // Filete com a cor accent do cartão dono — clara o bastante para identificar o cartão.
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: Radius.lg, bottomLeadingRadius: Radius.lg)
                .fill(style.accent)
                .frame(width: 4)
        }
```

- [ ] **Step 3: Identity dot in "Todas" scope uses `accent`**

Same file, inside `row(_:)` (lines 205-215), replace the gradient `Circle()`:

```swift
                if showsWalletIdentity, let owner {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(style.accent)
                            .frame(width: 8, height: 8)
                        Text(owner.name)
                            .font(.brand(.caption2, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
```

- [ ] **Step 4: Build**

Run the build command from Global Constraints. Expected: `** BUILD SUCCEEDED **`.

---

### Task 2: `WalletScopePicker` component + integration

**Files:**
- Create: `Paggo/Features/Wallet/Transactions/WalletScopePicker.swift`
- Modify: `Paggo/Features/Wallet/Transactions/WalletTransactionsView.swift` (replace `scopePicker`, delete `scopeLabel`/`isScoped`/`scopedWalletStyleIndex`/`walletDot`)

**Interfaces:**
- Consumes: `WalletCardStyle.at(_:)`, `.top`, `.bottom`, `.accent` (Task 1); `WalletStore.transactionsScope: TransactionsScope` (cases `.current`, `.wallet(String)`, `.all`), `wallet.wallets: [Wallet]` (`.id: String`, `.name: String`), `wallet.currentWallet: Wallet?`, `wallet.styleIndex(for:) -> Int`, `wallet.ensureAllPaymentsLoaded() async` — all existing.
- Produces: `WalletScopePicker: View`, no parameters (environment-driven). Used only by `WalletTransactionsView`.

- [ ] **Step 1: Create the component**

Create `Paggo/Features/Wallet/Transactions/WalletScopePicker.swift`:

```swift
import SwiftUI

/// Seletor custom de escopo do extrato — botão cápsula com ponta de cartão e painel inline.
/// As pontas deslizam da esquerda (stagger) ao abrir; com Reduce Motion vira fade.
struct WalletScopePicker: View {
    @Environment(WalletStore.self) private var wallet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            toggleButton
            if isOpen {
                panel.transition(.opacity)
            }
        }
    }

    private var toggleAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.8)
    }

    // MARK: Botão

    private var toggleButton: some View {
        Button {
            withAnimation(toggleAnimation) { isOpen.toggle() }
        } label: {
            HStack(spacing: Spacing.sm) {
                buttonTip
                Text(scopeLabel)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
            .background(Theme.surfaceHigh, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Escopo "Todas": leque de até 3 pontas sobrepostas; senão, a ponta do cartão escolhido.
    @ViewBuilder private var buttonTip: some View {
        if wallet.transactionsScope == .all {
            ZStack {
                ForEach(Array(wallet.wallets.prefix(3).enumerated()), id: \.element.id) { index, _ in
                    CardTip(style: .at(index), width: 22, height: 15)
                        .offset(x: CGFloat(index) * 4)
                }
            }
            .padding(.trailing, CGFloat(min(wallet.wallets.count, 3) - 1) * 4)
        } else {
            CardTip(style: .at(scopedStyleIndex), width: 28, height: 18)
        }
    }

    private var scopeLabel: String {
        switch wallet.transactionsScope {
        case .current: return wallet.currentWallet?.name ?? "Carteira"
        case .wallet(let id): return wallet.wallets.first { $0.id == id }?.name ?? "Carteira"
        case .all: return "Todas as carteiras"
        }
    }

    private var scopedStyleIndex: Int {
        switch wallet.transactionsScope {
        case .current: return wallet.styleIndex(for: wallet.currentWallet)
        case .wallet(let id): return wallet.styleIndex(for: wallet.wallets.first { $0.id == id })
        case .all: return 0
        }
    }

    // MARK: Painel

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(wallet.wallets.enumerated()), id: \.element.id) { index, item in
                walletRow(item, index: index)
            }
            Divider().padding(.vertical, Spacing.xs)
            allWalletsRow
        }
        .padding(Spacing.sm)
        .cardSurface()
    }

    private func walletRow(_ item: Wallet, index: Int) -> some View {
        PickerRow(index: index, reduceMotion: reduceMotion) {
            select(.wallet(item.id))
        } label: {
            HStack(spacing: Spacing.md) {
                CardTip(style: .at(index), width: 36, height: 24)
                Text(item.name)
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.sm)
                if isScoped(to: item.id) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WalletCardStyle.at(index).accent)
                }
            }
        }
    }

    private var allWalletsRow: some View {
        PickerRow(index: wallet.wallets.count, reduceMotion: reduceMotion) {
            select(.all)
        } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    ForEach(Array(wallet.wallets.prefix(3).enumerated()), id: \.element.id) { index, _ in
                        CardTip(style: .at(index), width: 28, height: 19)
                            .offset(x: CGFloat(index) * 5)
                    }
                }
                .frame(width: 36 + CGFloat(max(0, min(wallet.wallets.count, 3) - 1)) * 5, alignment: .leading)
                Text("Todas as carteiras")
                    .font(.brand(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: Spacing.sm)
                if wallet.transactionsScope == .all {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private func isScoped(to id: String) -> Bool {
        switch wallet.transactionsScope {
        case .current: return wallet.currentWallet?.id == id
        case .wallet(let scopedId): return scopedId == id
        case .all: return false
        }
    }

    private func select(_ scope: WalletStore.TransactionsScope) {
        withAnimation(toggleAnimation) { isOpen = false }
        wallet.transactionsScope = scope
        if scope == .all { Task { await wallet.ensureAllPaymentsLoaded() } }
    }
}

/// Linha do painel — desliza da esquerda com atraso proporcional ao índice (stagger 50 ms).
private struct PickerRow<Label: View>: View {
    let index: Int
    let reduceMotion: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var appeared = false

    var body: some View {
        Button(action: action) {
            label()
                .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.sm)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: appeared || reduceMotion ? 0 : -40)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(entrance) { appeared = true }
        }
    }

    private var entrance: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.15)
            : .spring(response: 0.35, dampingFraction: 0.8).delay(Double(index) * 0.05)
    }
}

/// Ponta de cartão em miniatura — gradiente do cartão, cantos esquerdos arredondados e
/// borda direita reta (cartão "saindo do bolso"), com o mesmo fio de luz do cartão grande.
private struct CardTip: View {
    let style: WalletCardStyle
    var width: CGFloat
    var height: CGFloat

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: height * 0.3, bottomLeadingRadius: height * 0.3,
                               bottomTrailingRadius: 2, topTrailingRadius: 2, style: .continuous)
    }

    var body: some View {
        shape
            .fill(LinearGradient(colors: [style.top, style.bottom],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.06)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
            .frame(width: width, height: height)
    }
}
```

Note: `TransactionsScope` is `enum TransactionsScope: Hashable` nested in `WalletStore` (`Paggo/Services/WalletStore.swift:18`) — hence the `WalletStore.TransactionsScope` qualification in `select(_:)`.

- [ ] **Step 2: Integrate into `WalletTransactionsView`**

In `Paggo/Features/Wallet/Transactions/WalletTransactionsView.swift`:

a) Replace the call site (line 18) — hidden when there are no wallets (spec edge case):

```swift
                    if !wallet.wallets.isEmpty {
                        WalletScopePicker()
                            .padding(.horizontal, Spacing.lg)
                    }
```

b) Delete the entire `// MARK: Scope picker` block — `scopeLabel`, `scopePicker`, `isScoped(to:)`, `scopedWalletStyleIndex`, `walletDot(for:)` (lines 61-138). The `showsWalletIdentity` property (line 12) stays — rows still use it.

- [ ] **Step 3: Regenerate project and build**

```bash
cd /Users/gabrielpereira/Desktop/ios && xcodegen
```

Expected: `Created project at .../Paggo.xcodeproj`. Then run the build command. Expected: `** BUILD SUCCEEDED **`.

---

### Task 3: Rename tab + ProfileMenu only on Início

**Files:**
- Modify: `Paggo/Features/Wallet/WalletRootView.swift:37`
- Modify: `Paggo/Features/Wallet/Transactions/WalletTransactionsView.swift:47`
- Modify: `Paggo/Features/Wallet/Payment/WalletPaymentMenuView.swift:67-68`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: no API — label and toolbar changes only.

- [ ] **Step 1: Rename the tab**

In `WalletRootView.swift`, replace:

```swift
            Tab("Transações", systemImage: "list.bullet.rectangle.portrait",
                value: WalletTabRouter.WalletTab.transacoes) {
                WalletTransactionsView()
            }
```

with:

```swift
            Tab("Extrato", systemImage: "list.bullet.rectangle.portrait",
                value: WalletTabRouter.WalletTab.transacoes) {
                WalletTransactionsView()
            }
```

(Enum case `transacoes` unchanged — keeps `PAGGO_WALLET_TAB=transacoes` working.)

- [ ] **Step 2: Remove ProfileMenu from Extrato**

In `WalletTransactionsView.swift`, delete line 47:

```swift
            .toolbar { ToolbarItem(placement: .topBarLeading) { ProfileMenu() } }
```

- [ ] **Step 3: Remove ProfileMenu from Pagar**

In `WalletPaymentMenuView.swift`, delete the `ToolbarItem(placement: .topBarLeading) { ProfileMenu() }` entry (lines 67-68). If it's the only item in the `.toolbar { }` block, delete the whole block.

- [ ] **Step 4: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`. Also check `ProfileMenu` still referenced by `WalletHomeView` (no dead-code warning removal needed — Dashboard also uses it).

---

### Task 4: Simulator verification

**Files:** none (verification only).

- [ ] **Step 1: Launch on Extrato tab**

```bash
cd /Users/gabrielpereira/Desktop/ios && xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; xcodebuild -project Paggo.xcodeproj -scheme Paggo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build && xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Paggo.app 2>/dev/null || true
xcrun simctl launch --terminate-running-process booted com.gabrielpereira.paggo --setenv PAGGO_WALLET_TAB transacoes
```

(If install path differs, find the built .app with `find ~/Library/Developer/Xcode/DerivedData -name "Paggo.app" -path "*iphonesimulator*" | head -1`.)

- [ ] **Step 2: Screenshot checklist**

```bash
xcrun simctl io booted screenshot /private/tmp/claude-501/-Users-gabrielpereira-Desktop-ios/534eb9e8-f8ad-4f70-9a07-f3f274843c58/scratchpad/extrato-closed.png
```

Read the screenshot and verify: tab bar shows "Extrato"; no ProfileMenu top-left; picker button shows card tip + name + chevron; row left borders are the lighter accent colors.

- [ ] **Step 3: Open picker, screenshot again**

`simctl` cannot tap. Add a debug env var (mirrors the codebase's existing `PAGGO_WALLET_*` pattern) to `WalletScopePicker`:

```swift
    @State private var isOpen = ProcessInfo.processInfo.environment["PAGGO_WALLET_PICKER"] == "1"
```

Relaunch with `--setenv PAGGO_WALLET_PICKER 1`, screenshot `extrato-open.png`, verify: panel with card tips, checkmark on selected, "Todas as carteiras" row with fan of tips.

- [ ] **Step 4: Verify Início and Pagar**

Relaunch with `PAGGO_WALLET_TAB=inicio` then `PAGGO_WALLET_TAB=pagar`, screenshot each: greeting + ProfileMenu present on Início; no ProfileMenu on Pagar.
