# Reactant Stoichiometry Calculator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user assign a quantity (mole or mass) to each dropped reactant and report the balanced equation, limiting reactant, theoretical product yield, and leftover excess.

**Architecture:** A pure, side-effect-free solver in the ChemCore Swift package (`Stoichiometry.swift`) does all the chemistry/math. SwiftUI owns transient quantity input as local `@State` in `BridgeView` and renders the result — the existing `CanvasState`/`CanvasReducer` bonding state machine is untouched.

**Tech Stack:** Swift, ChemCore SwiftPM package (XCTest), SwiftUI (ChemInteractive Xcode target).

## Global Constraints

- ChemCore code is pure: no SwiftUI/Foundation UI imports in `Stoichiometry.swift` (Foundation only).
- All new public types: `Equatable, Sendable`.
- Diatomic set is exactly `["H","N","O","F","Cl","Br","I"]`.
- Diatomic message string is verbatim: `{symbol} cannot exist as monoatomic, It only exist in {symbol}₂`.
- Quantity unit `mass` is in grams; molar mass in g/mol.
- ChemCore tests run from the `ChemCore/` dir: `swift test --filter <Name>`.
- ChemInteractive build: `xcodebuild -project ChemInteractive.xcodeproj -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' build`.
- Out of scope v1: metallic pairs, polyatomic-ion reactants, percent/actual yield.

---

### Task 1: Core types + equation balancer

**Files:**
- Create: `ChemCore/Sources/ChemCore/Engine/Stoichiometry.swift`
- Test: `ChemCore/Tests/ChemCoreTests/StoichiometryTests.swift`

**Interfaces:**
- Consumes: `gcd(_:_:)` from `ChemCore/Sources/ChemCore/Engine/MathUtil.swift`.
- Produces:
  - `enum QuantityUnit: String, Sendable, Equatable { case mole, mass }`
  - `struct ReactantEntry { let value: Double; let unit: QuantityUnit }`
  - `struct ReactantSpec { let symbol: String; let atomicMass: Double; let subscriptInProduct: Int; let isDiatomic: Bool; let entry: ReactantEntry? }`
  - `struct BalancedEquation { let coeffA, coeffB, coeffProduct, molecularityA, molecularityB: Int }`
  - `enum LimitingSide { case a, b, both }`
  - `struct AmountResult { let moles: Double; let mass: Double }`
  - `struct StoichResult { let equation: BalancedEquation; let productMolarMass: Double; let limiting: LimitingSide; let yield: AmountResult; let excess: AmountResult; let diatomicMessages: [String] }`
  - `let naturallyDiatomic: Set<String>`
  - `func molecularity(isDiatomic: Bool) -> Int`
  - `func balanceEquation(subscriptA: Int, molecularityA: Int, subscriptB: Int, molecularityB: Int) -> BalancedEquation`

- [ ] **Step 1: Write the failing test**

```swift
// ChemCore/Tests/ChemCoreTests/StoichiometryTests.swift
import XCTest
@testable import ChemCore

final class StoichiometryTests: XCTestCase {
    func test_balance_water() {
        // H (subscript 2, diatomic) + O (subscript 1, diatomic) -> 2H₂ + O₂ -> 2H₂O
        let e = balanceEquation(subscriptA: 2, molecularityA: 2, subscriptB: 1, molecularityB: 2)
        XCTAssertEqual([e.coeffA, e.coeffB, e.coeffProduct], [2, 1, 2])
    }
    func test_balance_nacl() {
        // Na (1, mono) + Cl (1, diatomic) -> 2Na + Cl₂ -> 2NaCl
        let e = balanceEquation(subscriptA: 1, molecularityA: 1, subscriptB: 1, molecularityB: 2)
        XCTAssertEqual([e.coeffA, e.coeffB, e.coeffProduct], [2, 1, 2])
    }
    func test_balance_mgcl2() {
        // Mg (1, mono) + Cl (2, diatomic) -> Mg + Cl₂ -> MgCl₂
        let e = balanceEquation(subscriptA: 1, molecularityA: 1, subscriptB: 2, molecularityB: 2)
        XCTAssertEqual([e.coeffA, e.coeffB, e.coeffProduct], [1, 1, 1])
    }
    func test_diatomic_set() {
        XCTAssertEqual(naturallyDiatomic, ["H", "N", "O", "F", "Cl", "Br", "I"])
        XCTAssertEqual(molecularity(isDiatomic: true), 2)
        XCTAssertEqual(molecularity(isDiatomic: false), 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter StoichiometryTests`
Expected: FAIL — `cannot find 'balanceEquation' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemCore/Sources/ChemCore/Engine/Stoichiometry.swift
import Foundation

public enum QuantityUnit: String, Sendable, Equatable { case mole, mass }

public struct ReactantEntry: Equatable, Sendable {
    public let value: Double
    public let unit: QuantityUnit
    public init(value: Double, unit: QuantityUnit) {
        self.value = value; self.unit = unit
    }
}

public struct ReactantSpec: Equatable, Sendable {
    public let symbol: String
    public let atomicMass: Double
    public let subscriptInProduct: Int
    public let isDiatomic: Bool
    public let entry: ReactantEntry?
    public init(symbol: String, atomicMass: Double, subscriptInProduct: Int,
                isDiatomic: Bool, entry: ReactantEntry?) {
        self.symbol = symbol; self.atomicMass = atomicMass
        self.subscriptInProduct = subscriptInProduct
        self.isDiatomic = isDiatomic; self.entry = entry
    }
}

public struct BalancedEquation: Equatable, Sendable {
    public let coeffA: Int
    public let coeffB: Int
    public let coeffProduct: Int
    public let molecularityA: Int
    public let molecularityB: Int
}

public enum LimitingSide: Equatable, Sendable { case a, b, both }

public struct AmountResult: Equatable, Sendable {
    public let moles: Double
    public let mass: Double
}

public struct StoichResult: Equatable, Sendable {
    public let equation: BalancedEquation
    public let productMolarMass: Double
    public let limiting: LimitingSide
    public let yield: AmountResult
    public let excess: AmountResult
    public let diatomicMessages: [String]
}

public let naturallyDiatomic: Set<String> = ["H", "N", "O", "F", "Cl", "Br", "I"]

func lcm(_ a: Int, _ b: Int) -> Int { a / gcd(a, b) * b }

public func molecularity(isDiatomic: Bool) -> Int { isDiatomic ? 2 : 1 }

/// Balance `coeffA·A_p + coeffB·B_q -> coeffProduct·AₓBᵧ` for smallest integers,
/// where x/y are the product subscripts and p/q the reactant molecularities.
public func balanceEquation(subscriptA x: Int, molecularityA p: Int,
                            subscriptB y: Int, molecularityB q: Int) -> BalancedEquation {
    let c0 = lcm(p / gcd(p, x), q / gcd(q, y))
    var a = c0 * x / p
    var b = c0 * y / q
    var c = c0
    let g = gcd(gcd(a, b), c)
    a /= g; b /= g; c /= g
    return BalancedEquation(coeffA: a, coeffB: b, coeffProduct: c,
                            molecularityA: p, molecularityB: q)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter StoichiometryTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Engine/Stoichiometry.swift ChemCore/Tests/ChemCoreTests/StoichiometryTests.swift
git commit -m "feat: stoichiometry types and equation balancer"
```

---

### Task 2: Solver — molar mass, limiting, yield, excess

**Files:**
- Modify: `ChemCore/Sources/ChemCore/Engine/Stoichiometry.swift` (append `solveStoichiometry`)
- Test: `ChemCore/Tests/ChemCoreTests/StoichiometryTests.swift` (add cases)

**Interfaces:**
- Consumes: all Task 1 types, `balanceEquation`, `molecularity`, `naturallyDiatomic`.
- Produces: `func solveStoichiometry(a: ReactantSpec, b: ReactantSpec) -> StoichResult`.

- [ ] **Step 1: Write the failing test**

```swift
// Append inside StoichiometryTests
private func spec(_ sym: String, _ mass: Double, _ sub: Int, _ di: Bool,
                  _ entry: ReactantEntry?) -> ReactantSpec {
    ReactantSpec(symbol: sym, atomicMass: mass, subscriptInProduct: sub,
                 isDiatomic: di, entry: entry)
}

func test_yield_water_stoichiometric() {
    // 2 mol H₂ + 1 mol O₂ -> 2 mol H₂O ; masses H=1, O=16 -> product 18 g/mol
    let h = spec("H", 1, 2, true, ReactantEntry(value: 2, unit: .mole))
    let o = spec("O", 16, 1, true, ReactantEntry(value: 1, unit: .mole))
    let r = solveStoichiometry(a: h, b: o)
    XCTAssertEqual(r.limiting, .both)
    XCTAssertEqual(r.yield.moles, 2, accuracy: 1e-9)
    XCTAssertEqual(r.productMolarMass, 18, accuracy: 1e-9)
    XCTAssertEqual(r.yield.mass, 36, accuracy: 1e-9)
    XCTAssertEqual(r.excess.moles, 0, accuracy: 1e-9)
}

func test_excess_hydrogen() {
    // 3 mol H₂ + 1 mol O₂ : extents 1.5 vs 1 -> O limiting, 1 mol H₂ left (2 g)
    let h = spec("H", 1, 2, true, ReactantEntry(value: 3, unit: .mole))
    let o = spec("O", 16, 1, true, ReactantEntry(value: 1, unit: .mole))
    let r = solveStoichiometry(a: h, b: o)
    XCTAssertEqual(r.limiting, .b)
    XCTAssertEqual(r.yield.moles, 2, accuracy: 1e-9)
    XCTAssertEqual(r.excess.moles, 1, accuracy: 1e-9)
    XCTAssertEqual(r.excess.mass, 2, accuracy: 1e-9)   // 1 mol H₂ × 2 g/mol
}

func test_mass_unit_conversion() {
    // 32 g O₂ = 1 mol O₂ ; pair with 4 mol H₂ -> O limiting, yield 2 mol H₂O
    let h = spec("H", 1, 2, true, ReactantEntry(value: 4, unit: .mole))
    let o = spec("O", 16, 1, true, ReactantEntry(value: 32, unit: .mass))
    let r = solveStoichiometry(a: h, b: o)
    XCTAssertEqual(r.limiting, .b)
    XCTAssertEqual(r.yield.moles, 2, accuracy: 1e-9)
}

func test_blank_is_enough() {
    // A entered, B blank -> A limiting, no excess
    let h = spec("H", 1, 2, true, ReactantEntry(value: 2, unit: .mole))
    let o = spec("O", 16, 1, true, nil)
    let r = solveStoichiometry(a: h, b: o)
    XCTAssertEqual(r.limiting, .a)
    XCTAssertEqual(r.yield.moles, 2, accuracy: 1e-9)
    XCTAssertEqual(r.excess.moles, 0, accuracy: 1e-9)
}

func test_both_blank_one_mol_basis() {
    let h = spec("H", 1, 2, true, nil)
    let o = spec("O", 16, 1, true, nil)
    let r = solveStoichiometry(a: h, b: o)
    XCTAssertEqual(r.limiting, .both)
    XCTAssertEqual(r.yield.moles, 2, accuracy: 1e-9)   // coeffProduct × ξ(=1)
}

func test_diatomic_messages() {
    let na = spec("Na", 23, 1, false, ReactantEntry(value: 1, unit: .mole))
    let cl = spec("Cl", 35.45, 1, true, ReactantEntry(value: 1, unit: .mole))
    let r = solveStoichiometry(a: na, b: cl)
    XCTAssertEqual(r.diatomicMessages,
                   ["Cl cannot exist as monoatomic, It only exist in Cl₂"])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter StoichiometryTests`
Expected: FAIL — `cannot find 'solveStoichiometry' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// Append to Stoichiometry.swift
public func solveStoichiometry(a: ReactantSpec, b: ReactantSpec) -> StoichResult {
    let p = molecularity(isDiatomic: a.isDiatomic)
    let q = molecularity(isDiatomic: b.isDiatomic)
    let eqn = balanceEquation(subscriptA: a.subscriptInProduct, molecularityA: p,
                              subscriptB: b.subscriptInProduct, molecularityB: q)

    let unitMassA = Double(p) * a.atomicMass    // molar mass of A_p (X₂ when diatomic)
    let unitMassB = Double(q) * b.atomicMass
    let productMolarMass = Double(a.subscriptInProduct) * a.atomicMass
                         + Double(b.subscriptInProduct) * b.atomicMass

    func molesUnit(_ e: ReactantEntry?, _ unitMass: Double) -> Double? {
        guard let e else { return nil }
        switch e.unit {
        case .mole: return e.value
        case .mass: return e.value / unitMass
        }
    }
    let molA = molesUnit(a.entry, unitMassA)
    let molB = molesUnit(b.entry, unitMassB)
    let extentA = molA.map { $0 / Double(eqn.coeffA) }
    let extentB = molB.map { $0 / Double(eqn.coeffB) }

    let xi: Double
    let limiting: LimitingSide
    switch (extentA, extentB) {
    case (nil, nil):              xi = 1;  limiting = .both
    case (let ea?, nil):          xi = ea; limiting = .a
    case (nil, let eb?):          xi = eb; limiting = .b
    case (let ea?, let eb?):
        if ea < eb {              xi = ea; limiting = .a }
        else if eb < ea {         xi = eb; limiting = .b }
        else {                    xi = ea; limiting = .both }
    }

    let yieldMoles = Double(eqn.coeffProduct) * xi
    let yield = AmountResult(moles: yieldMoles, mass: yieldMoles * productMolarMass)

    var excess = AmountResult(moles: 0, mass: 0)
    if limiting == .a, let mb = molB {
        let left = mb - Double(eqn.coeffB) * xi
        excess = AmountResult(moles: left, mass: left * unitMassB)
    } else if limiting == .b, let ma = molA {
        let left = ma - Double(eqn.coeffA) * xi
        excess = AmountResult(moles: left, mass: left * unitMassA)
    }

    var messages: [String] = []
    if a.isDiatomic { messages.append("\(a.symbol) cannot exist as monoatomic, It only exist in \(a.symbol)₂") }
    if b.isDiatomic { messages.append("\(b.symbol) cannot exist as monoatomic, It only exist in \(b.symbol)₂") }

    return StoichResult(equation: eqn, productMolarMass: productMolarMass,
                        limiting: limiting, yield: yield, excess: excess,
                        diatomicMessages: messages)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter StoichiometryTests`
Expected: PASS (all cases, Task 1 + Task 2).

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Engine/Stoichiometry.swift ChemCore/Tests/ChemCoreTests/StoichiometryTests.swift
git commit -m "feat: solve limiting reactant, yield and excess"
```

---

### Task 3: Stoichiometry mode transition (reducer)

**Files:**
- Modify: `ChemCore/Sources/ChemCore/State/Phase.swift` (add `.stoichiometry` case)
- Modify: `ChemCore/Sources/ChemCore/State/CanvasState.swift` (add `.startStoichiometry` action)
- Modify: `ChemCore/Sources/ChemCore/State/CanvasReducer.swift` (handle it)
- Test: `ChemCore/Tests/ChemCoreTests/CanvasReducerTests.swift` (add case)

**Interfaces:**
- Consumes: existing `CanvasState`, `canvasReducer`, `CanvasAction`, `CanvasPhase`.
- Produces: `CanvasPhase.stoichiometry`; `CanvasAction.startStoichiometry`;
  reducer rule: from `.complete`, `.startStoichiometry` → phase `.stoichiometry`
  with `slotA`, `slotB`, `bondingType` preserved; a no-op from any other phase.

- [ ] **Step 1: Write the failing test**

```swift
// Add to CanvasReducerTests
func test_startStoichiometry_fromComplete() {
    var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na", oxidation: [1])))
    s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl", oxidation: [-1])))
    s = canvasReducer(s, .dismissExplanation)   // -> animatingCrossover
    s = canvasReducer(s, .crossoverComplete)     // -> complete
    XCTAssertEqual(s.canvasPhase, .complete)
    let stoich = canvasReducer(s, .startStoichiometry)
    XCTAssertEqual(stoich.canvasPhase, .stoichiometry)
    XCTAssertEqual(stoich.slotA?.symbol, "Na")   // reactants preserved
    XCTAssertEqual(stoich.slotB?.symbol, "Cl")
    XCTAssertEqual(stoich.bondingType, .ionic)
}

func test_startStoichiometry_ignoredBeforeComplete() {
    let s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na")))
    let same = canvasReducer(s, .startStoichiometry)
    XCTAssertEqual(same.canvasPhase, .slotAFilled)   // no-op
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter CanvasReducerTests`
Expected: FAIL — `type 'CanvasAction' has no member 'startStoichiometry'`.

- [ ] **Step 3: Write minimal implementation**

In `Phase.swift`, add the case to `CanvasPhase`:

```swift
    case complete
    case stoichiometry
```

In `CanvasState.swift`, add the action to `CanvasAction`:

```swift
    case crossoverComplete
    case startStoichiometry
    case reset
```

In `CanvasReducer.swift`, add a case in the `switch action` (before `.reset`):

```swift
    case .startStoichiometry:
        guard state.canvasPhase == .complete else { return state }
        var s = state
        s.canvasPhase = .stoichiometry
        return s
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter CanvasReducerTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/State/Phase.swift ChemCore/Sources/ChemCore/State/CanvasState.swift ChemCore/Sources/ChemCore/State/CanvasReducer.swift ChemCore/Tests/ChemCoreTests/CanvasReducerTests.swift
git commit -m "feat: stoichiometry mode phase and transition"
```

---

### Task 4: Reactant quantity popover (SwiftUI)

**Files:**
- Create: `ChemInteractive/Views/Bridge/ReactantQuantityPopover.swift`

**Interfaces:**
- Consumes: `ReactantEntry`, `QuantityUnit`, `naturallyDiatomic` from ChemCore.
- Produces: `struct ReactantQuantityPopover: View` with init
  `(symbol: String, entry: Binding<ReactantEntry?>)`.

A self-contained popover: a numeric `TextField` (float) bound to a local string, a `Picker` over `QuantityUnit` (mole / mass), and — when `naturallyDiatomic.contains(symbol)` — the inline exclamation message. On a valid positive number it writes a `ReactantEntry` to the binding; on empty/invalid it writes `nil`.

- [ ] **Step 1: Write the component**

```swift
// ChemInteractive/Views/Bridge/ReactantQuantityPopover.swift
import SwiftUI
import ChemCore

/// Hover popover letting the user set a reactant's quantity + unit. Writes a
/// `ReactantEntry?` (nil when blank/invalid). Diatomic elements show a notice.
struct ReactantQuantityPopover: View {
    let symbol: String
    @Binding var entry: ReactantEntry?

    @State private var text: String = ""
    @State private var unit: QuantityUnit = .mole

    private var isDiatomic: Bool { naturallyDiatomic.contains(symbol) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quantity of \(symbol)").font(.caption.weight(.semibold))
            HStack(spacing: 6) {
                TextField("0", text: $text)
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: text) { _, _ in sync() }
                Picker("", selection: $unit) {
                    Text("mol").tag(QuantityUnit.mole)
                    Text("g").tag(QuantityUnit.mass)
                }
                .pickerStyle(.segmented)
                .onChange(of: unit) { _, _ in sync() }
            }
            if isDiatomic {
                Text("\(symbol) cannot exist as monoatomic, It only exist in \(symbol)₂")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(12)
        .onAppear {
            if let e = entry { text = trimmed(e.value); unit = e.unit }
        }
    }

    private func trimmed(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }

    /// Parse the field; positive number -> ReactantEntry, else nil.
    private func sync() {
        guard let v = Double(text), v > 0 else { entry = nil; return }
        entry = ReactantEntry(value: v, unit: unit)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project ChemInteractive.xcodeproj -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Bridge/ReactantQuantityPopover.swift
git commit -m "feat: reactant quantity popover with diatomic notice"
```

---

### Task 5: Stoich result panel (SwiftUI)

**Files:**
- Create: `ChemInteractive/Views/Bridge/StoichResultPanel.swift`

**Interfaces:**
- Consumes: `StoichResult`, `LimitingSide`, `BalancedEquation` from ChemCore; reactant symbols passed in.
- Produces: `struct StoichResultPanel: View` with init
  `(result: StoichResult, symbolA: String, symbolB: String, productFormula: String)`.

Renders the balanced equation line, limiting reactant, theoretical yield (mol + g), and excess (hidden when `result.excess.moles == 0`).

- [ ] **Step 1: Write the component**

```swift
// ChemInteractive/Views/Bridge/StoichResultPanel.swift
import SwiftUI
import ChemCore

/// Renders a StoichResult: balanced equation, limiting reactant, yield, excess.
struct StoichResultPanel: View {
    let result: StoichResult
    let symbolA: String
    let symbolB: String
    let productFormula: String

    private func fmt(_ v: Double) -> String { String(format: "%.3g", v) }

    private var limitingSymbol: String? {
        switch result.limiting {
        case .a: return symbolA
        case .b: return symbolB
        case .both: return nil
        }
    }

    private var equationText: String {
        let e = result.equation
        func term(_ coeff: Int, _ sym: String, _ molecularity: Int) -> String {
            let unit = molecularity == 2 ? "\(sym)₂" : sym
            return coeff == 1 ? unit : "\(coeff)\(unit)"
        }
        let lhs = "\(term(e.coeffA, symbolA, e.molecularityA)) + \(term(e.coeffB, symbolB, e.molecularityB))"
        let rhs = e.coeffProduct == 1 ? productFormula : "\(e.coeffProduct)\(productFormula)"
        return "\(lhs) → \(rhs)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(equationText).font(.callout.weight(.semibold))
            if let lim = limitingSymbol {
                Text("Limiting reactant: \(lim)").font(.caption)
            } else {
                Text("Stoichiometric (no limiting reactant)").font(.caption)
            }
            Text("Theoretical yield: \(fmt(result.yield.moles)) mol (\(fmt(result.yield.mass)) g) \(productFormula)")
                .font(.caption)
            if result.excess.moles > 0 {
                let sym = result.limiting == .a ? symbolB : symbolA
                Text("Excess: \(fmt(result.excess.moles)) mol (\(fmt(result.excess.mass)) g) \(sym) remaining")
                    .font(.caption)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project ChemInteractive.xcodeproj -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Bridge/StoichResultPanel.swift
git commit -m "feat: stoich result panel view"
```

---

### Task 6: Wire button, phase switch, popover + panel into BridgeView

**Files:**
- Modify: `ChemInteractive/Views/Bridge/BridgeView.swift`

**Interfaces:**
- Consumes: `ReactantQuantityPopover`, `StoichResultPanel`, `solveStoichiometry`, `ReactantEntry`, `ReactantSpec` (ChemCore); product subscripts from existing code (`crossoverModel(...).cationSub/anionSub` in `ChemInteractive/Diagrams/LewisLayout.swift` for ionic, `covalentStoich(...)` for covalent); atomic mass via `PeriodicTable.load().bySymbol(_:)?.atomicMass`.
- Produces: no new public API; in-view behavior only.

> **Before editing:** read `BridgeView.swift` in full plus `ChemInteractive/Diagrams/LewisLayout.swift` (for `ionicPair`/`crossoverModel`) and `ChemInteractive/Views/Bridge/CovalentLewisView.swift` (for the `covalentStoich` call pattern) so the subscript resolution matches the existing product exactly.

- [ ] **Step 1: Add quantity state + a spec-builder helper**

Add to `BridgeView`:

```swift
@State private var entryA: ReactantEntry?
@State private var entryB: ReactantEntry?

/// Build a ReactantSpec for one slot: resolve atomic mass + its subscript in the
/// product (cationSub/anionSub for ionic, covalentStoich nA/nB for covalent).
private func spec(for zone: ZoneState, subscriptInProduct: Int,
                  entry: ReactantEntry?) -> ReactantSpec? {
    guard let pt = try? PeriodicTable.load(),
          let el = pt.bySymbol(zone.symbol) else { return nil }
    return ReactantSpec(symbol: zone.symbol, atomicMass: el.atomicMass,
                        subscriptInProduct: subscriptInProduct,
                        isDiatomic: naturallyDiatomic.contains(zone.symbol),
                        entry: entry)
}
```

- [ ] **Step 2: Attach the popover on hover/long-press of each reactant token**

On each reactant token view (slot A and slot B), add (adjust the trigger to match the existing token view — `.popover` on hover for macOS-designed, long-press elsewhere):

```swift
.popover(isPresented: $showPopoverA) {
    ReactantQuantityPopover(symbol: slotA.symbol, entry: $entryA)
}
```

with a matching `@State private var showPopoverA = false` / `showPopoverB` and a tap/hover gesture toggling them.

- [ ] **Step 3: Add the Stoichiometry button in the `.complete` phase**

Where the completed bonding diagram is shown (phase `.complete`), add a button —
only for non-metallic products — that starts the use case:

```swift
if model.state.canvasPhase == .complete, model.state.bondingType != .metallic {
    Button("Stoichiometry") { model.send(.startStoichiometry) }
        .buttonStyle(.borderedProminent)
}
```

- [ ] **Step 4: Switch the canvas body on phase — diagram vs stoichiometry view**

Gate the main content so the Lewis/crossover diagram renders in the bonding
phases and the stoichiometry view replaces it (diagram cleared) in
`.stoichiometry`:

```swift
if model.state.canvasPhase == .stoichiometry,
   let a = model.state.slotA, let b = model.state.slotB,
   let subs = productSubscripts(a, b),                 // (subA, subB) from existing engine
   let specA = spec(for: a, subscriptInProduct: subs.0, entry: entryA),
   let specB = spec(for: b, subscriptInProduct: subs.1, entry: entryB) {
    let result = solveStoichiometry(a: specA, b: specB)
    VStack(spacing: 12) {
        // the two reactant tokens, each carrying the popover from Step 2
        StoichResultPanel(result: result, symbolA: a.symbol, symbolB: b.symbol,
                          productFormula: productFormula(a, b))
    }
} else {
    // existing bonding diagram content (unchanged)
}
```

Implement `productSubscripts(_:_:)` and `productFormula(_:_:)` as private helpers in `BridgeView` reusing the existing ionic (`crossoverModel`) and covalent (`covalentStoich`) logic already used by the diagrams — do not duplicate the math, call the same functions.

- [ ] **Step 5: Build to verify it compiles**

Run: `xcodebuild -project ChemInteractive.xcodeproj -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manual smoke test**

Run the app on the iPhone 17 simulator (install + launch as in prior session). Drop Na + Cl to complete bonding, tap **Stoichiometry** (diagram clears), open each reactant popover, enter quantities, confirm the panel shows `2Na + Cl₂ → 2NaCl`, a limiting reactant, yield, and excess. Confirm the diatomic notice appears for Cl.

- [ ] **Step 7: Commit**

```bash
git add ChemInteractive/Views/Bridge/BridgeView.swift
git commit -m "feat: wire stoichiometry popover and result panel"
```

---

## Notes for the implementer

- Tasks 1–3 are pure/unit-tested (ChemCore); get them green before touching UI.
- Task 6 is the only task that depends on existing-code details — read the named files first; the subscript sources (`crossoverModel`, `covalentStoich`) already exist and must be reused, not reimplemented.
- `BridgeView`'s exact token views and result-display location are not reproduced here; follow the established layout and inject the two new views at the natural points.
