# Reactant Stoichiometry Calculator — Design

Date: 2026-06-23
Status: Approved design (pending spec review)
Approach: **A — pure solver in ChemCore, UI-owned input state**

## 1. Goal

A second feature layered on top of the existing bonding feature. The bonding
feature already takes two dropped reactants (slot A, slot B), determines the
bonding type, and produces a product compound with known subscripts. This
feature lets the user assign a **quantity** to each reactant and then reports
the stoichiometric outcome of the reaction: the balanced equation, the limiting
reactant, the theoretical yield of the product, and the leftover excess
reactant.

The calculation lives in the **ChemCore** library as pure, side-effect-free
code, mirroring the existing engine style (`CovalentStoich.swift` — free
functions, no SwiftUI, fully unit-tested).

## 2. Decisions (from brainstorming)

1. **Inputs on both reactants.** Each dropzone (A and B) carries its own
   `(quantity, unit)`. The engine compares the two amounts to find the limiting
   reactant.
2. **Hover interaction.** Hovering a reactant pops up a context menu with two
   fields: quantity (floating number) and unit (mole / mass).
3. **Diatomic auto-correction.** Naturally-diatomic elements
   (H, N, O, F, Cl, Br, I) are auto-corrected to their X₂ molecular form, with
   an exclamation message: `{symbol} cannot exist as monoatomic, It only exist
   in {X₂}`. The entered quantity then counts as moles/mass of the **X₂
   molecule** (molar mass = 2 × atomic), and the balanced equation is rebalanced
   accordingly (e.g. `2H₂ + O₂ → 2H₂O`, `2Na + Cl₂ → 2NaCl`).
4. **Full result panel** shown near the product: balanced equation, limiting
   reactant, theoretical yield (mol + mass), and excess leftover (mol + mass).
5. **Blank = enough.** If one reactant has a quantity and the other is blank,
   the blank reactant is assumed present in exactly the amount required
   (stoichiometric to the entered one) → the entered reactant is limiting, no
   spurious excess. If both blank, use a 1-mol-of-reaction basis.

## 3. Scope

**In scope (v1):**
- Element + element reactions that yield a single binary compound (ionic or
  covalent), as already produced by the bonding feature.
- Mono- and diatomic elemental reactants.
- Quantity in mole or mass (grams).

**Out of scope (v1):**
- Metallic pairs (metal + metal) — no discrete molecular compound / yield; the
  panel is not shown.
- Polyatomic-ion reactants — their molar mass would need formula parsing; defer.
- Percent yield / actual yield — only **theoretical** yield is computed.
- Reactions with more than two reactants or multiple products.

## 4. Architecture

```
ChemCore/Sources/ChemCore/Engine/
  Stoichiometry.swift      (NEW)  — pure solver + value types

ChemInteractive/Views/Bridge/
  ReactantQuantityPopover.swift  (NEW) — hover context menu (qty + unit)
  StoichResultPanel.swift        (NEW) — renders StoichResult
  BridgeView.swift               (EDIT) — holds quantity @State, wires popover + panel
```

The solver is a free function (plus small value types) in ChemCore. SwiftUI
owns the transient quantity state locally in `BridgeView` (`@State`) — it is NOT
added to `CanvasState` / `CanvasReducer`. Quantities need no replay/undo, so
keeping them out of the reduced state keeps the bonding state machine untouched.

### Data flow

```
user hovers reactant → ReactantQuantityPopover (qty, unit)
        │  (diatomic? auto-correct + message)
        ▼
BridgeView @State: entryA, entryB : ReactantEntry?
        │  + subscripts from existing engine (cationSub/anionSub or covalentStoich)
        │  + atomic masses from PeriodicTable
        ▼
ChemCore.solveStoichiometry(...) -> StoichResult
        ▼
StoichResultPanel renders result
```

## 5. Data model (ChemCore, `Stoichiometry.swift`)

```swift
public enum QuantityUnit: String, Sendable { case mole, mass }   // mass in grams

/// One reactant's user-entered amount. `nil` entry = "blank = enough".
public struct ReactantEntry: Equatable, Sendable {
    public let value: Double          // > 0
    public let unit: QuantityUnit
}

/// Everything the solver needs about one reactant, resolved by the caller.
public struct ReactantSpec: Equatable, Sendable {
    public let symbol: String
    public let atomicMass: Double     // single-atom mass from PeriodicTable
    public let subscriptInProduct: Int // x (or y) — from existing engine
    public let isDiatomic: Bool       // H,N,O,F,Cl,Br,I
    public let entry: ReactantEntry?  // nil = blank
}

public struct BalancedEquation: Equatable, Sendable {
    public let coeffA: Int            // a in  a·A_p + b·B_q → c·product
    public let coeffB: Int
    public let coeffProduct: Int      // c
    public let molecularityA: Int     // p (1 or 2)
    public let molecularityB: Int     // q (1 or 2)
}

public enum LimitingSide: Equatable, Sendable { case a, b, both }

public struct AmountResult: Equatable, Sendable {
    public let moles: Double
    public let mass: Double           // grams
}

public struct StoichResult: Equatable, Sendable {
    public let equation: BalancedEquation
    public let productMolarMass: Double
    public let limiting: LimitingSide
    public let yield: AmountResult         // theoretical product
    public let excess: AmountResult        // leftover of the non-limiting reactant (zero if `both`)
    public let diatomicMessages: [String]  // auto-correction notices to surface
}

public func solveStoichiometry(a: ReactantSpec, b: ReactantSpec) -> StoichResult
```

## 6. Algorithm

Let `x = a.subscriptInProduct`, `y = b.subscriptInProduct`,
`p = a.isDiatomic ? 2 : 1`, `q = b.isDiatomic ? 2 : 1`.

**6.1 Balance** `coeffA·A_p + coeffB·B_q → coeffProduct·AₓBᵧ`

Atom conservation: `coeffA·p = coeffProduct·x` and `coeffB·q = coeffProduct·y`.

```
c = lcm( p / gcd(p, x),  q / gcd(q, y) )
coeffA = c * x / p
coeffB = c * y / q
coeffProduct = c
// reduce all three by gcd(coeffA, coeffB, coeffProduct)
```

Worked checks:
- H₂O (x=2,y=1,p=2,q=2): c=lcm(1,2)=2 → 2 H₂ + 1 O₂ → 2 H₂O ✓
- NaCl (x=1,y=1,p=1,q=2): c=2 → 2 Na + 1 Cl₂ → 2 NaCl ✓
- MgCl₂ (x=1,y=2,p=1,q=2): c=1 → 1 Mg + 1 Cl₂ → 1 MgCl₂ ✓

**6.2 Molar masses**
- Reactant unit molar mass: `unitMassA = p · a.atomicMass` (the X₂ molecule when
  diatomic), likewise `unitMassB`.
- Product molar mass: `x · a.atomicMass + y · b.atomicMass`.

**6.3 Available moles** of each reactant's molecular unit:
```
molesUnit(entry, unitMass):
    entry == nil            -> nil      // blank
    entry.unit == .mole     -> entry.value
    entry.unit == .mass     -> entry.value / unitMass
```

**6.4 Reaction extent** ξ (moles of reaction):
- `extentA = molesUnitA / coeffA`, `extentB = molesUnitB / coeffB`.
- Both blank → `ξ = 1` (1-mol-of-reaction basis), `limiting = .both`.
- One blank → ξ = the entered side's extent; entered side is limiting; blank side
  consumed exactly, `limiting = .a` or `.b`.
- Both present → `ξ = min(extentA, extentB)`; limiting = the min side;
  `.both` if equal.

**6.5 Yield**
`yield.moles = coeffProduct · ξ`, `yield.mass = yield.moles · productMolarMass`.

**6.6 Excess** (non-limiting reactant only; zero when `limiting == .both` or the
non-limiting side is blank):
```
consumed = coeffOfExcessSide · ξ
leftoverMoles = molesUnitExcess - consumed
excess.moles  = leftoverMoles
excess.mass   = leftoverMoles · unitMassExcess
```

## 7. UI integration

**`ReactantQuantityPopover`** — shown on hover over a reactant token. Two
controls: a numeric `TextField` (float) and a `Picker` for unit (mole / mass).
On commit it produces a `ReactantEntry`. If the reactant symbol is diatomic, the
popover shows the exclamation message inline and the value is interpreted as the
X₂ amount (the engine handles the molar-mass doubling).

**`BridgeView`** — holds `@State entryA, entryB: ReactantEntry?`. It resolves
each reactant's `atomicMass` from `PeriodicTable`, its `subscriptInProduct` from
the already-computed product (ionic `cationSub/anionSub` via `crossoverModel`, or
covalent `nA/nB` via `covalentStoich`), and the `isDiatomic` flag, then calls
`solveStoichiometry`.

**`StoichResultPanel`** — renders, near the product:
- the balanced equation (with coefficients + subscripts),
- "Limiting reactant: {symbol}",
- "Theoretical yield: {moles} mol ({mass} g) {product}",
- "Excess: {moles} mol ({mass} g) {symbol} remaining" (hidden when zero).

Panel is only shown for ionic/covalent products (not metallic).

## 8. Validation & edge cases

- Quantity must be a positive number (> 0). Non-numeric or ≤ 0 → field shows an
  error, solver not called.
- Diatomic element → auto-correct message; quantity reinterpreted as X₂.
- Metallic pair / polyatomic reactant → panel not shown (out of scope v1).
- Both fields blank → 1-mol basis, `limiting = .both`, no excess.
- Subscript of 0 cannot occur (every reactant appears in the product).

## 9. Testing (TDD, ChemCoreTests/StoichiometryTests.swift)

Pure-function tests, no SwiftUI:
- **Balancing:** H+O→H₂O gives (2,1,2); Na+Cl→NaCl gives (2,1,2);
  Mg+Cl→MgCl₂ gives (1,1,1); Mg+O→MgO gives (2,1,2).
- **Molar mass:** unit mass of O is 32 (diatomic), Na is ~23 (monatomic);
  product mass of H₂O ≈ 18.
- **Limiting reactant:** excess of one side → other is limiting; equal extents →
  `.both`; mass-unit vs mole-unit inputs compared correctly.
- **Yield:** 2 mol H₂ + 1 mol O₂ → 2 mol H₂O (≈ 36 g).
- **Excess:** 3 mol H₂ + 1 mol O₂ (eqn 2H₂ + O₂ → 2H₂O): extents 3/2 vs 1/1 →
  O₂ limiting; H₂ consumed = 2 mol, leftover = 1 mol H₂ (≈ 2 g). Assert leftover
  moles + mass on the non-limiting side.
- **Blank handling:** A entered, B blank → A limiting, excess zero; both blank →
  1-mol basis.
- **Diatomic message** emitted for H,N,O,F,Cl,Br,I and absent otherwise.

## 10. Files

- `ChemCore/Sources/ChemCore/Engine/Stoichiometry.swift` — NEW (solver + types)
- `ChemCore/Tests/ChemCoreTests/StoichiometryTests.swift` — NEW
- `ChemInteractive/Views/Bridge/ReactantQuantityPopover.swift` — NEW
- `ChemInteractive/Views/Bridge/StoichResultPanel.swift` — NEW
- `ChemInteractive/Views/Bridge/BridgeView.swift` — EDIT (state + wiring)

Diatomic set constant `naturallyDiatomic = ["H","N","O","F","Cl","Br","I"]`
lives in `Stoichiometry.swift`.
