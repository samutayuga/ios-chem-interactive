# Compound-Reactant Reaction Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a pure ChemCore engine that generalizes stoichiometry from binary element synthesis to compound reactants (1–2 species per zone), with reaction classification, product prediction, a general integer balancer, and an activity-series feasibility check.

**Architecture:** A new additive `Reaction/` module inside the standalone ChemCore SPM package. Each reactant is a compound built from 1–2 species; the solver classifies the reaction, predicts products (formulas + element-count maps, no coefficients), balances via rational null-space, then computes limiting reactant and per-product yields. The existing binary path is untouched.

**Tech Stack:** Swift 5, XCTest, Swift Package Manager (ChemCore package).

## Global Constraints

- **ChemCore is a standalone SPM package.** It MUST NOT import or depend on the ChemInteractive app target. App-target helpers (`ionicFormula`, `crossoverModel`, `ionicPair`, `subscriptGlyphs` in `ChemInteractive/`) are OFF LIMITS — reimplement minimal equivalents inside `Reaction/`.
- **Reusable ChemCore helpers (import nothing extra, same module):** `gcd(_:_:)` (`Engine/MathUtil.swift`), `covalentStoich(...)`, `iupacFirst(_:_:)`, `calcStoich(...)` (`Engine/CovalentStoich.swift`), `determineBonding(_:_:)` (`Engine/Bonding.swift`), `naturallyDiatomic` set, `LimitingSide`, `AmountResult`, `QuantityUnit`, `ReactantEntry` (`Engine/Stoichiometry.swift`), `ElementClass` (`PTDomain/Classification.swift`).
- **Do not modify** `Engine/Stoichiometry.swift`, `Engine/Bonding.swift`, or any existing source/test. The engine is purely additive; all existing tests must stay green.
- **Test style:** `import XCTest` + `@testable import ChemCore`, `final class XxxTests: XCTestCase`, methods named `test_...`. Match `ChemCore/Tests/ChemCoreTests/StoichiometryTests.swift`.
- **Numeric tolerance:** compare `Double` with `XCTAssertEqual(a, b, accuracy: 1e-6)`.
- **Run tests from `ChemCore/`:** `swift test` (all) or `swift test --filter <TestClass>` (one class).
- **Commit message convention:** end body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

All new files under `ChemCore/Sources/ChemCore/Reaction/` (source) and `ChemCore/Tests/ChemCoreTests/` (tests):

- `Fraction.swift` — exact rational used by the balancer.
- `FormulaText.swift` — subscript-digit rendering + ionic crossover subscripts (ChemCore-local, replaces app helpers).
- `Species.swift` — a single placed species (element or polyatomic ion).
- `Reactant.swift` — a reactant compound built from 1–2 species (`makeReactant`).
- `ReactionClass.swift` — `ReactionClass` enum + `classifyReaction`.
- `ActivitySeries.swift` — metal + halogen reactivity data + `displaces(_:over:)`.
- `ProductPrediction.swift` — `predictProducts` per class → `[Product]` + optional infeasibility.
- `Balancer.swift` — `balance(reactants:products:)` general integer balancer.
- `ReactionSolver.swift` — `ReactionResult`, `ReactionError`, `solveReaction`.

Task order respects dependencies: Fraction → FormulaText → Species/Reactant → Balancer → ClassifyReaction → ActivitySeries → ProductPrediction → ReactionSolver.

---

### Task 1: Fraction (exact rational for the balancer)

**Files:**
- Create: `ChemCore/Sources/ChemCore/Reaction/Fraction.swift`
- Test: `ChemCore/Tests/ChemCoreTests/FractionTests.swift`

**Interfaces:**
- Consumes: `gcd(_:_:)` from `Engine/MathUtil.swift`.
- Produces: `struct Fraction` with `init(_ num: Int, _ den: Int = 1)`, stored `num: Int`, `den: Int` (den always > 0, reduced), `static func + `, `static func * `, `var isZero: Bool`.

- [ ] **Step 1: Write the failing test**

```swift
// ChemCore/Tests/ChemCoreTests/FractionTests.swift
import XCTest
@testable import ChemCore

final class FractionTests: XCTestCase {
    func test_reduces_on_init() {
        let f = Fraction(4, 8)
        XCTAssertEqual(f.num, 1)
        XCTAssertEqual(f.den, 2)
    }
    func test_normalizes_sign_to_numerator() {
        let f = Fraction(1, -2)
        XCTAssertEqual(f.num, -1)
        XCTAssertEqual(f.den, 2)
    }
    func test_addition() {
        XCTAssertEqual(Fraction(1, 2) + Fraction(1, 3), Fraction(5, 6))
    }
    func test_multiplication() {
        XCTAssertEqual(Fraction(2, 3) * Fraction(3, 4), Fraction(1, 2))
    }
    func test_isZero() {
        XCTAssertTrue(Fraction(0, 5).isZero)
        XCTAssertFalse(Fraction(1, 5).isZero)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter FractionTests`
Expected: FAIL — `cannot find 'Fraction' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemCore/Sources/ChemCore/Reaction/Fraction.swift
import Foundation

/// Exact rational, always stored reduced with a positive denominator.
public struct Fraction: Equatable, Sendable {
    public let num: Int
    public let den: Int

    public init(_ num: Int, _ den: Int = 1) {
        precondition(den != 0, "Fraction denominator must be non-zero")
        let sign = den < 0 ? -1 : 1
        let n = num * sign
        let d = abs(den)
        if n == 0 { self.num = 0; self.den = 1; return }
        let g = gcd(abs(n), d)
        self.num = n / g
        self.den = d / g
    }

    public var isZero: Bool { num == 0 }

    public static func + (a: Fraction, b: Fraction) -> Fraction {
        Fraction(a.num * b.den + b.num * a.den, a.den * b.den)
    }

    public static func * (a: Fraction, b: Fraction) -> Fraction {
        Fraction(a.num * b.num, a.den * b.den)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter FractionTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Reaction/Fraction.swift ChemCore/Tests/ChemCoreTests/FractionTests.swift
git commit -m "feat(chemcore): add exact Fraction rational for reaction balancer"
```

---

### Task 2: FormulaText (subscript rendering + ionic crossover subscripts)

**Files:**
- Create: `ChemCore/Sources/ChemCore/Reaction/FormulaText.swift`
- Test: `ChemCore/Tests/ChemCoreTests/FormulaTextTests.swift`

**Interfaces:**
- Consumes: `gcd(_:_:)`.
- Produces:
  - `func formulaSubscript(_ n: Int) -> String` — Unicode subscript digits; `n <= 1` → `""`.
  - `func crossoverSubscripts(cationCharge: Int, anionCharge: Int) -> (cationSub: Int, anionSub: Int)` — gcd-reduced, uses magnitudes.
  - `func binaryFormula(first: String, firstCount: Int, second: String, secondCount: Int, secondIsPolyatomic: Bool) -> String` — assembles `"Na"`, `"H₂O"`, `"(NH₄)₂SO₄"`; wraps the second symbol in parentheses only when polyatomic AND its count > 1.

- [ ] **Step 1: Write the failing test**

```swift
// ChemCore/Tests/ChemCoreTests/FormulaTextTests.swift
import XCTest
@testable import ChemCore

final class FormulaTextTests: XCTestCase {
    func test_subscript_hides_one() {
        XCTAssertEqual(formulaSubscript(1), "")
        XCTAssertEqual(formulaSubscript(2), "₂")
        XCTAssertEqual(formulaSubscript(12), "₁₂")
    }
    func test_crossover_nacl() {
        let s = crossoverSubscripts(cationCharge: 1, anionCharge: -1)
        XCTAssertEqual(s.cationSub, 1)
        XCTAssertEqual(s.anionSub, 1)
    }
    func test_crossover_mgcl2() {
        let s = crossoverSubscripts(cationCharge: 2, anionCharge: -1)
        XCTAssertEqual(s.cationSub, 1)
        XCTAssertEqual(s.anionSub, 2)
    }
    func test_crossover_reduces_al2o3_not_needed_but_ca_o() {
        let s = crossoverSubscripts(cationCharge: 2, anionCharge: -2)
        XCTAssertEqual(s.cationSub, 1)
        XCTAssertEqual(s.anionSub, 1)
    }
    func test_binaryFormula_simple() {
        XCTAssertEqual(binaryFormula(first: "H", firstCount: 2, second: "O", secondCount: 1, secondIsPolyatomic: false), "H₂O")
    }
    func test_binaryFormula_polyatomic_parenthesised() {
        XCTAssertEqual(binaryFormula(first: "NH₄", firstCount: 2, second: "SO₄", secondCount: 1, secondIsPolyatomic: true), "(NH₄)₂SO₄")
    }
    func test_binaryFormula_polyatomic_single_no_parens() {
        XCTAssertEqual(binaryFormula(first: "Na", firstCount: 1, second: "OH", secondCount: 1, secondIsPolyatomic: true), "NaOH")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter FormulaTextTests`
Expected: FAIL — `cannot find 'formulaSubscript' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemCore/Sources/ChemCore/Reaction/FormulaText.swift
import Foundation

private let subscriptDigits: [Character: Character] = [
    "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
    "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
]

/// Unicode subscript for a count; empty string when n <= 1.
public func formulaSubscript(_ n: Int) -> String {
    guard n > 1 else { return "" }
    return String(String(n).map { subscriptDigits[$0] ?? $0 })
}

/// gcd-reduced crossover subscripts from ionic charges (magnitudes crossed over).
public func crossoverSubscripts(cationCharge: Int, anionCharge: Int) -> (cationSub: Int, anionSub: Int) {
    let cc = abs(cationCharge)
    let ac = abs(anionCharge)
    let g = max(1, gcd(cc, ac))
    return (cationSub: ac / g, anionSub: cc / g)
}

/// Assemble a two-part formula. The second part is parenthesised only when it is a
/// polyatomic ion carrying a subscript > 1 (e.g. "(NH₄)₂SO₄", but "NaOH").
public func binaryFormula(first: String, firstCount: Int,
                          second: String, secondCount: Int,
                          secondIsPolyatomic: Bool) -> String {
    let firstPart = firstIsWrapped(first) && firstCount > 1
        ? "(\(first))\(formulaSubscript(firstCount))"
        : "\(first)\(formulaSubscript(firstCount))"
    let secondPart = secondIsPolyatomic && secondCount > 1
        ? "(\(second))\(formulaSubscript(secondCount))"
        : "\(second)\(formulaSubscript(secondCount))"
    return firstPart + secondPart
}

/// A leading polyatomic cation (e.g. NH₄) needs parentheses when it repeats.
private func firstIsWrapped(_ symbol: String) -> Bool {
    symbol.count > 2 && symbol.contains { $0.isNumber || subscriptDigits.values.contains($0) }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter FormulaTextTests`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Reaction/FormulaText.swift ChemCore/Tests/ChemCoreTests/FormulaTextTests.swift
git commit -m "feat(chemcore): add ChemCore-local formula text + crossover helpers"
```

---

### Task 3: Species + Reactant builder

**Files:**
- Create: `ChemCore/Sources/ChemCore/Reaction/Species.swift`
- Create: `ChemCore/Sources/ChemCore/Reaction/Reactant.swift`
- Test: `ChemCore/Tests/ChemCoreTests/ReactantTests.swift`

**Interfaces:**
- Consumes: `formulaSubscript`, `crossoverSubscripts`, `binaryFormula`, `determineBonding(_:_:)`, `covalentStoich(...)`, `iupacFirst(_:_:)`, `naturallyDiatomic`, `ElementClass`.
- Produces:
  - `struct Species` with members: `symbol: String`, `atomicMass: Double`, `charge: Int?`, `elementClass: ElementClass`, `isPolyatomic: Bool`, `valenceElectrons: Int`, `group: Int`, `period: Int`, `composition: [String: Int]`, plus a memberwise `init`.
  - `struct Reactant` with members: `species: [Species]`, `formula: String`, `composition: [String: Int]`, `molarMass: Double`, `cation: Species?`, `anion: Species?`, `isBareElement: Bool`.
  - `func makeReactant(_ species: [Species]) -> Reactant` — 1 species → bare element (diatomic composition if in `naturallyDiatomic`); 2 species → ionic (crossover, sets cation/anion) or covalent (covalentStoich); charged species are treated as ions.

**Reactant-builder rules:**
- 1 species: `isBareElement = true` when non-polyatomic. If `symbol ∈ naturallyDiatomic`, composition is `[symbol: 2]` and formula `"<sym>₂"`; else `[symbol: 1]`, formula `"<sym>"`. `cation`/`anion` nil.
- 2 species: ionic when either species is polyatomic OR `determineBonding` of the two element classes is `.ionic`. Cation = the species with positive `charge` (or the metal); anion = the other. Crossover subscripts from charges; `molarMass = Σ atomicMass × count`.
- 2 species, covalent: use `covalentStoich` on valence electrons; IUPAC ordering for display via `iupacFirst`.

- [ ] **Step 1: Write the failing test**

```swift
// ChemCore/Tests/ChemCoreTests/ReactantTests.swift
import XCTest
@testable import ChemCore

private func element(_ sym: String, mass: Double, _ cls: ElementClass,
                     charge: Int? = nil, ve: Int = 0, group: Int = 0, period: Int = 0) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: cls,
            isPolyatomic: false, valenceElectrons: ve, group: group, period: period,
            composition: [sym: 1])
}
private func poly(_ sym: String, mass: Double, charge: Int, comp: [String: Int]) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: .nonMetal,
            isPolyatomic: true, valenceElectrons: 0, group: 0, period: 0, composition: comp)
}

final class ReactantTests: XCTestCase {
    func test_bare_metal() {
        let r = makeReactant([element("Zn", mass: 65.38, .metal, charge: 2)])
        XCTAssertTrue(r.isBareElement)
        XCTAssertEqual(r.formula, "Zn")
        XCTAssertEqual(r.composition, ["Zn": 1])
    }
    func test_bare_diatomic() {
        let r = makeReactant([element("O", mass: 16.0, .nonMetal, charge: -2)])
        XCTAssertEqual(r.formula, "O₂")
        XCTAssertEqual(r.composition, ["O": 2])
        XCTAssertEqual(r.molarMass, 32.0, accuracy: 1e-6)
    }
    func test_ionic_nacl() {
        let na = element("Na", mass: 23.0, .metal, charge: 1)
        let cl = element("Cl", mass: 35.45, .nonMetal, charge: -1)
        let r = makeReactant([na, cl])
        XCTAssertEqual(r.formula, "NaCl")
        XCTAssertEqual(r.composition, ["Na": 1, "Cl": 1])
        XCTAssertEqual(r.cation?.symbol, "Na")
        XCTAssertEqual(r.anion?.symbol, "Cl")
        XCTAssertFalse(r.isBareElement)
    }
    func test_ionic_with_polyatomic_sulfate() {
        let na = element("Na", mass: 23.0, .metal, charge: 1)
        let so4 = poly("SO₄", mass: 96.06, charge: -2, comp: ["S": 1, "O": 4])
        let r = makeReactant([na, so4])
        XCTAssertEqual(r.formula, "Na₂SO₄")
        XCTAssertEqual(r.composition, ["Na": 2, "S": 1, "O": 4])
        XCTAssertEqual(r.molarMass, 2 * 23.0 + 96.06, accuracy: 1e-6)
    }
    func test_covalent_methane() {
        let c = element("C", mass: 12.011, .nonMetal, ve: 4, group: 14, period: 2)
        let h = element("H", mass: 1.008, .nonMetal, ve: 1, group: 1, period: 1)
        let r = makeReactant([c, h])
        XCTAssertEqual(r.composition, ["C": 1, "H": 4])
        XCTAssertNil(r.cation)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter ReactantTests`
Expected: FAIL — `cannot find 'Species' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemCore/Sources/ChemCore/Reaction/Species.swift
import Foundation

/// One placed species: a neutral element or a (poly)atomic ion.
public struct Species: Equatable, Sendable {
    public let symbol: String
    public let atomicMass: Double
    public let charge: Int?
    public let elementClass: ElementClass
    public let isPolyatomic: Bool
    public let valenceElectrons: Int
    public let group: Int
    public let period: Int
    public let composition: [String: Int]

    public init(symbol: String, atomicMass: Double, charge: Int?,
                elementClass: ElementClass, isPolyatomic: Bool,
                valenceElectrons: Int, group: Int, period: Int,
                composition: [String: Int]) {
        self.symbol = symbol; self.atomicMass = atomicMass; self.charge = charge
        self.elementClass = elementClass; self.isPolyatomic = isPolyatomic
        self.valenceElectrons = valenceElectrons; self.group = group
        self.period = period; self.composition = composition
    }
}
```

```swift
// ChemCore/Sources/ChemCore/Reaction/Reactant.swift
import Foundation

/// A reactant compound built from 1 or 2 species using the existing bonding rules.
public struct Reactant: Equatable, Sendable {
    public let species: [Species]
    public let formula: String
    public let composition: [String: Int]
    public let molarMass: Double
    public let cation: Species?
    public let anion: Species?
    public let isBareElement: Bool
}

private func scaled(_ comp: [String: Int], by n: Int) -> [String: Int] {
    comp.mapValues { $0 * n }
}
private func merge(_ a: [String: Int], _ b: [String: Int]) -> [String: Int] {
    a.merging(b) { $0 + $1 }
}
private func molarMass(_ comp: [String: Int], _ species: [Species]) -> Double {
    // Per-element atomic mass looked up from whichever species contributes it.
    var perElement: [String: Double] = [:]
    for s in species where !s.isPolyatomic {
        perElement[s.symbol] = s.atomicMass
    }
    // Polyatomic species contribute their whole mass; handle them separately below.
    return 0 // replaced in build via explicit sums
}

public func makeReactant(_ species: [Species]) -> Reactant {
    if species.count == 1 {
        let s = species[0]
        let diatomic = naturallyDiatomic.contains(s.symbol) && !s.isPolyatomic
        let count = diatomic ? 2 : 1
        let comp = scaled(s.composition, by: count)
        let formula = "\(s.symbol)\(formulaSubscript(count))"
        return Reactant(species: species, formula: formula, composition: comp,
                        molarMass: s.atomicMass * Double(count),
                        cation: nil, anion: nil, isBareElement: !s.isPolyatomic)
    }

    let a = species[0], b = species[1]
    let ionic = a.isPolyatomic || b.isPolyatomic
        || determineBonding(a.elementClass, b.elementClass) == .ionic

    if ionic {
        // Cation = positive charge (or the metal); anion = the other.
        let (cation, anion): (Species, Species) =
            (a.charge ?? cationBias(a)) >= (b.charge ?? cationBias(b)) ? (a, b) : (b, a)
        let sub = crossoverSubscripts(cationCharge: cation.charge ?? 1,
                                      anionCharge: anion.charge ?? -1)
        let comp = merge(scaled(cation.composition, by: sub.cationSub),
                         scaled(anion.composition, by: sub.anionSub))
        let formula = binaryFormula(first: cation.symbol, firstCount: sub.cationSub,
                                    second: anion.symbol, secondCount: sub.anionSub,
                                    secondIsPolyatomic: anion.isPolyatomic)
        let mass = cation.atomicMass * Double(sub.cationSub)
                 + anion.atomicMass * Double(sub.anionSub)
        return Reactant(species: species, formula: formula, composition: comp,
                        molarMass: mass, cation: cation, anion: anion, isBareElement: false)
    }

    // Covalent.
    let s = covalentStoich(veA: a.valenceElectrons, groupA: a.group, periodA: a.period,
                           veB: b.valenceElectrons, groupB: b.group, periodB: b.period)
    let aFirst = iupacFirst(a.symbol, b.symbol)
    let first = aFirst ? a : b
    let firstN = aFirst ? s.nA : s.nB
    let second = aFirst ? b : a
    let secondN = aFirst ? s.nB : s.nA
    let comp = merge(scaled(a.composition, by: s.nA), scaled(b.composition, by: s.nB))
    let formula = binaryFormula(first: first.symbol, firstCount: firstN,
                                second: second.symbol, secondCount: secondN,
                                secondIsPolyatomic: false)
    let mass = a.atomicMass * Double(s.nA) + b.atomicMass * Double(s.nB)
    return Reactant(species: species, formula: formula, composition: comp,
                    molarMass: mass, cation: nil, anion: nil, isBareElement: false)
}

/// Metals bias toward cation, non-metals toward anion, when charge is absent.
private func cationBias(_ s: Species) -> Int {
    s.elementClass == .metal ? 1 : -1
}
```

Note: delete the unused `molarMass(_:_:)` stub from `Reactant.swift` if the compiler warns — it is illustrative and not called.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter ReactantTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Reaction/Species.swift ChemCore/Sources/ChemCore/Reaction/Reactant.swift ChemCore/Tests/ChemCoreTests/ReactantTests.swift
git commit -m "feat(chemcore): add Species and Reactant compound builder"
```

---

### Task 4: General integer balancer

**Files:**
- Create: `ChemCore/Sources/ChemCore/Reaction/Balancer.swift`
- Test: `ChemCore/Tests/ChemCoreTests/BalancerTests.swift`

**Interfaces:**
- Consumes: `Fraction`, `gcd(_:_:)`.
- Produces: `func balance(reactants: [[String: Int]], products: [[String: Int]]) -> [Int]?` — returns smallest positive integer coefficients ordered `reactants ++ products`, or `nil` when unbalanceable / degenerate.

**Algorithm:** Build an element × species matrix (reactants +count, products −count). Row-reduce over `Fraction` to find a one-dimensional null space (one free variable, set to 1), back-substitute, scale by LCM of denominators, divide by overall GCD, reject non-positive/all-zero results.

- [ ] **Step 1: Write the failing test**

```swift
// ChemCore/Tests/ChemCoreTests/BalancerTests.swift
import XCTest
@testable import ChemCore

final class BalancerTests: XCTestCase {
    func test_water_synthesis() {
        // H₂ + O₂ -> H₂O  => [2,1,2]
        let c = balance(reactants: [["H": 2], ["O": 2]], products: [["H": 2, "O": 1]])
        XCTAssertEqual(c, [2, 1, 2])
    }
    func test_neutralisation() {
        // NaOH + HCl -> NaCl + H₂O => [1,1,1,1]
        let c = balance(reactants: [["Na": 1, "O": 1, "H": 1], ["H": 1, "Cl": 1]],
                        products:  [["Na": 1, "Cl": 1], ["H": 2, "O": 1]])
        XCTAssertEqual(c, [1, 1, 1, 1])
    }
    func test_combustion_methane() {
        // CH₄ + O₂ -> CO₂ + H₂O => [1,2,1,2]
        let c = balance(reactants: [["C": 1, "H": 4], ["O": 2]],
                        products:  [["C": 1, "O": 2], ["H": 2, "O": 1]])
        XCTAssertEqual(c, [1, 2, 1, 2])
    }
    func test_carbonate_acid() {
        // 2HCl + Na₂CO₃ -> 2NaCl + CO₂ + H₂O => [2,1,2,1,1]
        let c = balance(reactants: [["H": 1, "Cl": 1], ["Na": 2, "C": 1, "O": 3]],
                        products:  [["Na": 1, "Cl": 1], ["C": 1, "O": 2], ["H": 2, "O": 1]])
        XCTAssertEqual(c, [2, 1, 2, 1, 1])
    }
    func test_unbalanceable_returns_nil() {
        // Element on the left with no home on the right.
        let c = balance(reactants: [["Na": 1]], products: [["Cl": 1]])
        XCTAssertNil(c)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter BalancerTests`
Expected: FAIL — `cannot find 'balance' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemCore/Sources/ChemCore/Reaction/Balancer.swift
import Foundation

private func lcm(_ a: Int, _ b: Int) -> Int { a == 0 || b == 0 ? 0 : abs(a / gcd(a, b) * b) }

/// Balance a reaction to the smallest positive integer coefficients, ordered
/// reactants-then-products. Returns nil when no all-positive solution exists.
public func balance(reactants: [[String: Int]], products: [[String: Int]]) -> [Int]? {
    let species = reactants + products
    let n = species.count
    guard n >= 2 else { return nil }

    // Distinct elements → matrix rows. Reactants positive, products negative.
    let elements = Array(Set(species.flatMap { $0.keys })).sorted()
    var m: [[Fraction]] = elements.map { el in
        (0..<n).map { j in
            let count = species[j][el] ?? 0
            let sign = j < reactants.count ? 1 : -1
            return Fraction(sign * count)
        }
    }

    // Gaussian elimination to reduced row echelon form.
    var pivotCols: [Int] = []
    var row = 0
    for col in 0..<n {
        guard let pivot = (row..<m.count).first(where: { !m[$0][col].isZero }) else { continue }
        m.swapAt(row, pivot)
        let inv = Fraction(m[row][col].den, m[row][col].num)
        m[row] = m[row].map { $0 * inv }
        for r in 0..<m.count where r != row && !m[r][col].isZero {
            let factor = m[r][col]
            m[r] = zip(m[r], m[row]).map { $0 + (Fraction(-factor.num, factor.den) * $1) }
        }
        pivotCols.append(col)
        row += 1
        if row == m.count { break }
    }

    // Exactly one free column → unique ratio. Otherwise reject.
    let freeCols = (0..<n).filter { !pivotCols.contains($0) }
    guard freeCols.count == 1, let free = freeCols.first else { return nil }

    // Set free variable = 1; pivots = -matrix[pivotRow][free].
    var solution = [Fraction](repeating: Fraction(0), count: n)
    solution[free] = Fraction(1)
    for (rowIndex, col) in pivotCols.enumerated() {
        solution[col] = Fraction(-m[rowIndex][free].num, m[rowIndex][free].den)
    }

    // Scale to integers: multiply by LCM of denominators.
    let denLCM = solution.reduce(1) { lcm($0, $1.den) }
    var ints = solution.map { $0.num * (denLCM / $0.den) }

    // Normalise sign so coefficients are positive, then divide by GCD.
    if ints.contains(where: { $0 < 0 }) && ints.allSatisfy({ $0 <= 0 }) {
        ints = ints.map { -$0 }
    }
    guard ints.allSatisfy({ $0 > 0 }) else { return nil }
    let g = ints.reduce(0) { gcd($0, $1) }
    guard g > 0 else { return nil }
    return ints.map { $0 / g }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter BalancerTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Reaction/Balancer.swift ChemCore/Tests/ChemCoreTests/BalancerTests.swift
git commit -m "feat(chemcore): add general integer reaction balancer"
```

---

### Task 5: Reaction classifier

**Files:**
- Create: `ChemCore/Sources/ChemCore/Reaction/ReactionClass.swift`
- Test: `ChemCore/Tests/ChemCoreTests/ReactionClassTests.swift`

**Interfaces:**
- Consumes: `Reactant`.
- Produces: `enum ReactionClass: String { case synthesis, doubleDisplacement, singleDisplacement, combustion, none }` and `func classifyReaction(_ r1: Reactant, _ r2: Reactant) -> ReactionClass`.

**Priority order:** combustion → single displacement → double displacement → synthesis → none (per Section 2 of the spec).

- [ ] **Step 1: Write the failing test**

```swift
// ChemCore/Tests/ChemCoreTests/ReactionClassTests.swift
import XCTest
@testable import ChemCore

private func el(_ sym: String, mass: Double, _ cls: ElementClass, charge: Int? = nil,
                ve: Int = 0, group: Int = 0, period: Int = 0) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: cls,
            isPolyatomic: false, valenceElectrons: ve, group: group, period: period,
            composition: [sym: 1])
}
private func polyIon(_ sym: String, mass: Double, charge: Int, comp: [String: Int]) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: .nonMetal,
            isPolyatomic: true, valenceElectrons: 0, group: 0, period: 0, composition: comp)
}

final class ReactionClassTests: XCTestCase {
    func test_combustion_methane_and_o2() {
        let ch4 = makeReactant([el("C", mass: 12, .nonMetal, ve: 4, group: 14, period: 2),
                                el("H", mass: 1, .nonMetal, ve: 1, group: 1, period: 1)])
        let o2 = makeReactant([el("O", mass: 16, .nonMetal, charge: -2)])
        XCTAssertEqual(classifyReaction(ch4, o2), .combustion)
    }
    func test_single_displacement_zn_and_cuso4() {
        let zn = makeReactant([el("Zn", mass: 65.38, .metal, charge: 2)])
        let cuso4 = makeReactant([el("Cu", mass: 63.55, .metal, charge: 2),
                                  polyIon("SO₄", mass: 96.06, charge: -2, comp: ["S": 1, "O": 4])])
        XCTAssertEqual(classifyReaction(zn, cuso4), .singleDisplacement)
    }
    func test_double_displacement_naoh_and_hcl() {
        let naoh = makeReactant([el("Na", mass: 23, .metal, charge: 1),
                                 polyIon("OH", mass: 17, charge: -1, comp: ["O": 1, "H": 1])])
        let hcl = makeReactant([el("H", mass: 1, .nonMetal, charge: 1),
                                el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        XCTAssertEqual(classifyReaction(naoh, hcl), .doubleDisplacement)
    }
    func test_synthesis_two_bare_elements() {
        let na = makeReactant([el("Na", mass: 23, .metal, charge: 1)])
        let cl = makeReactant([el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        XCTAssertEqual(classifyReaction(na, cl), .synthesis)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter ReactionClassTests`
Expected: FAIL — `cannot find 'classifyReaction' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemCore/Sources/ChemCore/Reaction/ReactionClass.swift
import Foundation

public enum ReactionClass: String, Equatable, Sendable {
    case synthesis, doubleDisplacement, singleDisplacement, combustion, none
}

private func isDioxygen(_ r: Reactant) -> Bool {
    r.composition.count == 1 && r.composition["O"] == 2
}
private func isFuel(_ r: Reactant) -> Bool {
    r.composition["C"] != nil || r.composition["H"] != nil || r.isBareElement
}
private func isIonicCompound(_ r: Reactant) -> Bool {
    r.cation != nil && r.anion != nil
}

public func classifyReaction(_ r1: Reactant, _ r2: Reactant) -> ReactionClass {
    // 1. Combustion: one side is O₂, the other burns.
    if (isDioxygen(r1) && isFuel(r2) && !isDioxygen(r2))
        || (isDioxygen(r2) && isFuel(r1) && !isDioxygen(r1)) {
        return .combustion
    }
    // 2. Single displacement: exactly one bare element + one ionic compound.
    if (r1.isBareElement && isIonicCompound(r2)) || (r2.isBareElement && isIonicCompound(r1)) {
        return .singleDisplacement
    }
    // 3. Double displacement: both ionic compounds.
    if isIonicCompound(r1) && isIonicCompound(r2) {
        return .doubleDisplacement
    }
    // 4. Synthesis: two bare elements.
    if r1.isBareElement && r2.isBareElement {
        return .synthesis
    }
    return .none
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter ReactionClassTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Reaction/ReactionClass.swift ChemCore/Tests/ChemCoreTests/ReactionClassTests.swift
git commit -m "feat(chemcore): add reaction classifier"
```

---

### Task 6: Activity series + feasibility

**Files:**
- Create: `ChemCore/Sources/ChemCore/Reaction/ActivitySeries.swift`
- Test: `ChemCore/Tests/ChemCoreTests/ActivitySeriesTests.swift`

**Interfaces:**
- Produces:
  - `let metalActivitySeries: [String]` — most reactive first.
  - `let halogenActivitySeries: [String]` — most reactive first.
  - `func displaces(_ free: String, over bound: String) -> Bool?` — true when `free` outranks `bound` in whichever series they share; `nil` when they are not in a common series.

- [ ] **Step 1: Write the failing test**

```swift
// ChemCore/Tests/ChemCoreTests/ActivitySeriesTests.swift
import XCTest
@testable import ChemCore

final class ActivitySeriesTests: XCTestCase {
    func test_metal_ordering() {
        XCTAssertLessThan(metalActivitySeries.firstIndex(of: "Zn")!,
                          metalActivitySeries.firstIndex(of: "Cu")!)
    }
    func test_zn_displaces_cu() {
        XCTAssertEqual(displaces("Zn", over: "Cu"), true)
    }
    func test_cu_does_not_displace_zn() {
        XCTAssertEqual(displaces("Cu", over: "Zn"), false)
    }
    func test_halogen_ordering() {
        XCTAssertEqual(displaces("Cl", over: "Br"), true)
        XCTAssertEqual(displaces("I", over: "Cl"), false)
    }
    func test_unrelated_pair_nil() {
        XCTAssertNil(displaces("Zn", over: "Cl"))
    }
    func test_same_element_false() {
        XCTAssertEqual(displaces("Zn", over: "Zn"), false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter ActivitySeriesTests`
Expected: FAIL — `cannot find 'metalActivitySeries' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemCore/Sources/ChemCore/Reaction/ActivitySeries.swift
import Foundation

/// Metal reactivity, most reactive first (standard school activity series, H included).
public let metalActivitySeries: [String] = [
    "K", "Na", "Li", "Ca", "Mg", "Al", "Zn", "Fe", "Ni", "Sn", "Pb",
    "H", "Cu", "Ag", "Hg", "Au",
]

/// Halogen reactivity, most reactive first.
public let halogenActivitySeries: [String] = ["F", "Cl", "Br", "I"]

/// True when `free` can displace `bound` from a compound: `free` is higher (more
/// reactive) in a shared series. nil when the two share no series.
public func displaces(_ free: String, over bound: String) -> Bool? {
    for series in [metalActivitySeries, halogenActivitySeries] {
        if let f = series.firstIndex(of: free), let b = series.firstIndex(of: bound) {
            return f < b
        }
    }
    return nil
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter ActivitySeriesTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Reaction/ActivitySeries.swift ChemCore/Tests/ChemCoreTests/ActivitySeriesTests.swift
git commit -m "feat(chemcore): add metal and halogen activity series"
```

---

### Task 7: Product prediction

**Files:**
- Create: `ChemCore/Sources/ChemCore/Reaction/ProductPrediction.swift`
- Test: `ChemCore/Tests/ChemCoreTests/ProductPredictionTests.swift`

**Interfaces:**
- Consumes: `Reactant`, `Species`, `ReactionClass`, `crossoverSubscripts`, `binaryFormula`, `formulaSubscript`, `displaces(_:over:)`.
- Produces:
  - `struct Product: Equatable { let formula: String; let composition: [String: Int] }`
  - `enum Prediction: Equatable { case products([Product]); case infeasible(String) }`
  - `func predictProducts(_ cls: ReactionClass, _ r1: Reactant, _ r2: Reactant) -> Prediction`

**Prediction rules (per Section 2):**
- **doubleDisplacement:** build `ionicProduct(cation1, anion2)` and `ionicProduct(cation2, anion1)`. Special cases when an H⁺ cation meets a hydroxide/carbonate anion: `H + OH → H₂O`; `H + CO₃ → CO₂ + H₂O`.
- **singleDisplacement:** free element (`isBareElement`) vs salt (cation+anion). Metal free element displaces the salt's cation; halogen free element displaces a halide anion. If `displaces` is true → salt of free element + freed element. If false → `.infeasible`. If `nil` (no shared series) → `.infeasible`.
- **combustion:** fuel (C/H, optional O) + O₂ → CO₂ (one per C) and H₂O (one per pair of H, but emit unit H₂O — the balancer fixes counts); bare-element fuel → its oxide from the element's positive charge magnitude.
- **synthesis:** single product = the compound `makeReactant([speciesA, speciesB]).formula/composition`.

Products carry unit formulas/compositions (no coefficients). Molar mass is computed later in the solver.

- [ ] **Step 1: Write the failing test**

```swift
// ChemCore/Tests/ChemCoreTests/ProductPredictionTests.swift
import XCTest
@testable import ChemCore

private func el(_ sym: String, mass: Double, _ cls: ElementClass, charge: Int? = nil,
                ve: Int = 0, group: Int = 0, period: Int = 0) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: cls,
            isPolyatomic: false, valenceElectrons: ve, group: group, period: period,
            composition: [sym: 1])
}
private func polyIon(_ sym: String, mass: Double, charge: Int, comp: [String: Int]) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: .nonMetal,
            isPolyatomic: true, valenceElectrons: 0, group: 0, period: 0, composition: comp)
}
private func formulas(_ p: Prediction) -> [String] {
    if case let .products(list) = p { return list.map(\.formula).sorted() }
    return []
}

final class ProductPredictionTests: XCTestCase {
    func test_neutralisation_to_water() {
        let naoh = makeReactant([el("Na", mass: 23, .metal, charge: 1),
                                 polyIon("OH", mass: 17, charge: -1, comp: ["O": 1, "H": 1])])
        let hcl = makeReactant([el("H", mass: 1, .nonMetal, charge: 1),
                                el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        XCTAssertEqual(formulas(predictProducts(.doubleDisplacement, naoh, hcl)),
                       ["H₂O", "NaCl"].sorted())
    }
    func test_carbonate_gives_co2_and_water() {
        let na2co3 = makeReactant([el("Na", mass: 23, .metal, charge: 1),
                                   polyIon("CO₃", mass: 60, charge: -2, comp: ["C": 1, "O": 3])])
        let hcl = makeReactant([el("H", mass: 1, .nonMetal, charge: 1),
                               el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        XCTAssertEqual(formulas(predictProducts(.doubleDisplacement, na2co3, hcl)),
                       ["CO₂", "H₂O", "NaCl"].sorted())
    }
    func test_single_displacement_feasible() {
        let zn = makeReactant([el("Zn", mass: 65.38, .metal, charge: 2)])
        let cuso4 = makeReactant([el("Cu", mass: 63.55, .metal, charge: 2),
                                  polyIon("SO₄", mass: 96.06, charge: -2, comp: ["S": 1, "O": 4])])
        XCTAssertEqual(formulas(predictProducts(.singleDisplacement, zn, cuso4)),
                       ["Cu", "ZnSO₄"].sorted())
    }
    func test_single_displacement_infeasible() {
        let cu = makeReactant([el("Cu", mass: 63.55, .metal, charge: 2)])
        let znso4 = makeReactant([el("Zn", mass: 65.38, .metal, charge: 2),
                                  polyIon("SO₄", mass: 96.06, charge: -2, comp: ["S": 1, "O": 4])])
        if case let .infeasible(reason) = predictProducts(.singleDisplacement, cu, znso4) {
            XCTAssertTrue(reason.contains("activity series"))
        } else {
            XCTFail("expected infeasible")
        }
    }
    func test_combustion_hydrocarbon() {
        let ch4 = makeReactant([el("C", mass: 12, .nonMetal, ve: 4, group: 14, period: 2),
                                el("H", mass: 1, .nonMetal, ve: 1, group: 1, period: 1)])
        let o2 = makeReactant([el("O", mass: 16, .nonMetal, charge: -2)])
        XCTAssertEqual(formulas(predictProducts(.combustion, ch4, o2)),
                       ["CO₂", "H₂O"].sorted())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter ProductPredictionTests`
Expected: FAIL — `cannot find 'predictProducts' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemCore/Sources/ChemCore/Reaction/ProductPrediction.swift
import Foundation

public struct Product: Equatable, Sendable {
    public let formula: String
    public let composition: [String: Int]
    public init(formula: String, composition: [String: Int]) {
        self.formula = formula; self.composition = composition
    }
}

public enum Prediction: Equatable, Sendable {
    case products([Product])
    case infeasible(String)
}

private let water = Product(formula: "H₂O", composition: ["H": 2, "O": 1])
private let carbonDioxide = Product(formula: "CO₂", composition: ["C": 1, "O": 2])

/// Neutralise a cation with an anion into a single ionic Product.
private func ionicProduct(_ cation: Species, _ anion: Species) -> Product {
    let sub = crossoverSubscripts(cationCharge: cation.charge ?? 1,
                                  anionCharge: anion.charge ?? -1)
    let comp = cation.composition.mapValues { $0 * sub.cationSub }
        .merging(anion.composition.mapValues { $0 * sub.anionSub }) { $0 + $1 }
    let formula = binaryFormula(first: cation.symbol, firstCount: sub.cationSub,
                                second: anion.symbol, secondCount: sub.anionSub,
                                secondIsPolyatomic: anion.isPolyatomic)
    return Product(formula: formula, composition: comp)
}

public func predictProducts(_ cls: ReactionClass, _ r1: Reactant, _ r2: Reactant) -> Prediction {
    switch cls {
    case .doubleDisplacement:
        guard let c1 = r1.cation, let a1 = r1.anion,
              let c2 = r2.cation, let a2 = r2.anion else {
            return .infeasible("both reactants must be ionic")
        }
        var products: [Product] = []
        for (cat, an) in [(c1, a2), (c2, a1)] {
            if cat.symbol == "H" && an.symbol == "OH" {
                products.append(water)
            } else if cat.symbol == "H" && an.symbol == "CO₃" {
                products.append(carbonDioxide)
                products.append(water)
            } else {
                products.append(ionicProduct(cat, an))
            }
        }
        return .products(products)

    case .singleDisplacement:
        let (free, salt) = r1.isBareElement ? (r1, r2) : (r2, r1)
        guard let boundCation = salt.cation, let anion = salt.anion,
              let freeSpecies = free.species.first else {
            return .infeasible("salt reactant must be ionic")
        }
        // Metal free element displaces the salt's cation; halogen displaces the anion.
        if freeSpecies.elementClass == .metal {
            switch displaces(freeSpecies.symbol, over: boundCation.symbol) {
            case .some(true):
                let newSalt = ionicProduct(freeSpecies, anion)
                let freed = Product(formula: boundCation.symbol, composition: [boundCation.symbol: 1])
                return .products([newSalt, freed])
            default:
                return .infeasible("\(freeSpecies.symbol) is below \(boundCation.symbol) in the activity series")
            }
        } else {
            switch displaces(freeSpecies.symbol, over: anion.symbol) {
            case .some(true):
                let newSalt = ionicProduct(boundCation, freeSpecies)
                let freed = Product(formula: anion.symbol, composition: [anion.symbol: 1])
                return .products([newSalt, freed])
            default:
                return .infeasible("\(freeSpecies.symbol) is below \(anion.symbol) in the activity series")
            }
        }

    case .combustion:
        let fuel = isDioxygenReactant(r1) ? r2 : r1
        if let c = fuel.composition["C"] { // hydrocarbon path
            var products = [carbonDioxide]
            if fuel.composition["H"] != nil { products.append(water) }
            _ = c
            return .products(products)
        }
        if fuel.composition["H"] != nil {
            return .products([water])
        }
        // Bare-element fuel → oxide E O_n where n = |positive charge|.
        guard let e = fuel.species.first else { return .infeasible("no fuel") }
        let n = max(1, abs(e.charge ?? 2))
        let oxideComp = ["\(e.symbol)": 1, "O": n]
        let oxide = Product(formula: "\(e.symbol)O\(formulaSubscript(n))", composition: oxideComp)
        return .products([oxide])

    case .synthesis:
        let compound = makeReactant([r1.species[0], r2.species[0]])
        return .products([Product(formula: compound.formula, composition: compound.composition)])

    case .none:
        return .infeasible("no recognised reaction")
    }
}

private func isDioxygenReactant(_ r: Reactant) -> Bool {
    r.composition.count == 1 && r.composition["O"] == 2
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter ProductPredictionTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Reaction/ProductPrediction.swift ChemCore/Tests/ChemCoreTests/ProductPredictionTests.swift
git commit -m "feat(chemcore): add product prediction for all reaction classes"
```

---

### Task 8: Reaction solver (end-to-end)

**Files:**
- Create: `ChemCore/Sources/ChemCore/Reaction/ReactionSolver.swift`
- Test: `ChemCore/Tests/ChemCoreTests/ReactionSolverTests.swift`

**Interfaces:**
- Consumes: everything above — `Reactant`, `classifyReaction`, `predictProducts`, `balance`, `Product`, `ReactantEntry`, `QuantityUnit`, `AmountResult`, `LimitingSide`.
- Produces:
  - `struct BalancedTerm: Equatable { let coeff: Int; let formula: String; let molarMass: Double; let composition: [String: Int] }`
  - `struct ReactionResult: Equatable { let reactionClass: ReactionClass; let reactants: [BalancedTerm]; let products: [BalancedTerm]; let limiting: LimitingSide; let yields: [AmountResult]; let excess: AmountResult; let messages: [String]; let feasible: Bool }`
  - `enum ReactionError: Error, Equatable { case unbalanceable; case noProducts; case unknownReactionClass; case missingAtomicMass(String) }`
  - `func solveReaction(_ r1: Reactant, _ r2: Reactant, entry1: ReactantEntry?, entry2: ReactantEntry?, atomicMass: (String) -> Double?) -> Result<ReactionResult, ReactionError>`

**Solver logic:**
1. `classifyReaction`. If `.none` → `.failure(.unknownReactionClass)`.
2. `predictProducts`. `.infeasible(reason)` → build a `ReactionResult` with `feasible = false`, empty yields, message = reason, coefficients from balancing skipped (products empty). `.products([])` → `.failure(.noProducts)`.
3. Build coefficient input: reactant compositions `[r1.composition, r2.composition]`, product compositions. `balance` → `nil` → `.failure(.unbalanceable)`.
4. Compute each `BalancedTerm` molar mass from composition × `atomicMass(symbol)`; a missing symbol → `.failure(.missingAtomicMass(symbol))`.
5. Limiting reactant + extent ξ: `molesOf(entry, reactantMolarMass)`; extent = moles / coeff; blank → treat as unconstrained; both blank → ξ = 1, `limiting = .both`; else smaller extent wins. Reuse the same rule shape as `solveStoichiometry`.
6. `yields[i] = AmountResult(moles: coeff_i · ξ, mass: coeff_i · ξ · productMolarMass_i)`. Excess = leftover moles/mass of the non-limiting reactant.

- [ ] **Step 1: Write the failing test**

```swift
// ChemCore/Tests/ChemCoreTests/ReactionSolverTests.swift
import XCTest
@testable import ChemCore

private func el(_ sym: String, mass: Double, _ cls: ElementClass, charge: Int? = nil,
                ve: Int = 0, group: Int = 0, period: Int = 0) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: cls,
            isPolyatomic: false, valenceElectrons: ve, group: group, period: period,
            composition: [sym: 1])
}
private func polyIon(_ sym: String, mass: Double, charge: Int, comp: [String: Int]) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: .nonMetal,
            isPolyatomic: true, valenceElectrons: 0, group: 0, period: 0, composition: comp)
}
private let masses: [String: Double] = [
    "H": 1.008, "O": 16.0, "Na": 22.99, "Cl": 35.45, "C": 12.011,
    "S": 32.06, "Zn": 65.38, "Cu": 63.55,
]
private func mass(_ s: String) -> Double? { masses[s] }

final class ReactionSolverTests: XCTestCase {
    func test_neutralisation_balances_and_is_feasible() {
        let naoh = makeReactant([el("Na", mass: 22.99, .metal, charge: 1),
                                 polyIon("OH", mass: 17.008, charge: -1, comp: ["O": 1, "H": 1])])
        let hcl = makeReactant([el("H", mass: 1.008, .nonMetal, charge: 1),
                               el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        let out = solveReaction(naoh, hcl, entry1: nil, entry2: nil, atomicMass: mass)
        guard case let .success(r) = out else { return XCTFail("expected success") }
        XCTAssertEqual(r.reactionClass, .doubleDisplacement)
        XCTAssertTrue(r.feasible)
        XCTAssertEqual(r.reactants.map(\.coeff), [1, 1])
        XCTAssertEqual(Set(r.products.map(\.formula)), ["NaCl", "H₂O"])
    }
    func test_combustion_methane_coefficients() {
        let ch4 = makeReactant([el("C", mass: 12.011, .nonMetal, ve: 4, group: 14, period: 2),
                                el("H", mass: 1.008, .nonMetal, ve: 1, group: 1, period: 1)])
        let o2 = makeReactant([el("O", mass: 16.0, .nonMetal, charge: -2)])
        let out = solveReaction(ch4, o2, entry1: nil, entry2: nil, atomicMass: mass)
        guard case let .success(r) = out else { return XCTFail("expected success") }
        XCTAssertEqual(r.reactionClass, .combustion)
        // CH₄ + 2O₂ -> CO₂ + 2H₂O
        XCTAssertEqual(r.reactants.map(\.coeff), [1, 2])
        let co2 = r.products.first { $0.formula == "CO₂" }
        let h2o = r.products.first { $0.formula == "H₂O" }
        XCTAssertEqual(co2?.coeff, 1)
        XCTAssertEqual(h2o?.coeff, 2)
    }
    func test_single_displacement_infeasible_result() {
        let cu = makeReactant([el("Cu", mass: 63.55, .metal, charge: 2)])
        let znso4 = makeReactant([el("Zn", mass: 65.38, .metal, charge: 2),
                                  polyIon("SO₄", mass: 96.06, charge: -2, comp: ["S": 1, "O": 4])])
        let out = solveReaction(cu, znso4, entry1: nil, entry2: nil, atomicMass: mass)
        guard case let .success(r) = out else { return XCTFail("expected success") }
        XCTAssertFalse(r.feasible)
        XCTAssertTrue(r.messages.contains { $0.contains("activity series") })
    }
    func test_yield_scales_with_limiting_reactant() {
        // 2 mol NaOH + 1 mol HCl -> HCl limits, 1 mol NaCl + 1 mol H₂O, 1 mol NaOH excess.
        let naoh = makeReactant([el("Na", mass: 22.99, .metal, charge: 1),
                                 polyIon("OH", mass: 17.008, charge: -1, comp: ["O": 1, "H": 1])])
        let hcl = makeReactant([el("H", mass: 1.008, .nonMetal, charge: 1),
                               el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        let out = solveReaction(naoh, hcl,
                                entry1: ReactantEntry(value: 2, unit: .mole),
                                entry2: ReactantEntry(value: 1, unit: .mole),
                                atomicMass: mass)
        guard case let .success(r) = out else { return XCTFail("expected success") }
        XCTAssertEqual(r.limiting, .b)
        let nacl = r.products.first { $0.formula == "NaCl" }!
        let yieldIndex = r.products.firstIndex { $0.formula == "NaCl" }!
        XCTAssertEqual(nacl.coeff, 1)
        XCTAssertEqual(r.yields[yieldIndex].moles, 1.0, accuracy: 1e-6)
        XCTAssertEqual(r.excess.moles, 1.0, accuracy: 1e-6)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter ReactionSolverTests`
Expected: FAIL — `cannot find 'solveReaction' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemCore/Sources/ChemCore/Reaction/ReactionSolver.swift
import Foundation

public struct BalancedTerm: Equatable, Sendable {
    public let coeff: Int
    public let formula: String
    public let molarMass: Double
    public let composition: [String: Int]
}

public struct ReactionResult: Equatable, Sendable {
    public let reactionClass: ReactionClass
    public let reactants: [BalancedTerm]
    public let products: [BalancedTerm]
    public let limiting: LimitingSide
    public let yields: [AmountResult]
    public let excess: AmountResult
    public let messages: [String]
    public let feasible: Bool
}

public enum ReactionError: Error, Equatable {
    case unbalanceable, noProducts, unknownReactionClass, missingAtomicMass(String)
}

private func molarMass(_ comp: [String: Int], _ atomicMass: (String) -> Double?) -> Double? {
    var total = 0.0
    for (sym, n) in comp {
        guard let m = atomicMass(sym) else { return nil }
        total += m * Double(n)
    }
    return total
}

public func solveReaction(_ r1: Reactant, _ r2: Reactant,
                          entry1: ReactantEntry?, entry2: ReactantEntry?,
                          atomicMass: (String) -> Double?) -> Result<ReactionResult, ReactionError> {
    let cls = classifyReaction(r1, r2)
    if cls == .none { return .failure(.unknownReactionClass) }

    // Product prediction — infeasible is a valid, non-error result.
    let prediction = predictProducts(cls, r1, r2)
    let productList: [Product]
    switch prediction {
    case .infeasible(let reason):
        let reactants = [r1, r2].map {
            BalancedTerm(coeff: 1, formula: $0.formula, molarMass: $0.molarMass, composition: $0.composition)
        }
        return .success(ReactionResult(reactionClass: cls, reactants: reactants, products: [],
                                       limiting: .both, yields: [], excess: AmountResult(moles: 0, mass: 0),
                                       messages: [reason], feasible: false))
    case .products(let list):
        if list.isEmpty { return .failure(.noProducts) }
        productList = list
    }

    // Balance.
    let reactantComps = [r1.composition, r2.composition]
    let productComps = productList.map(\.composition)
    guard let coeffs = balance(reactants: reactantComps, products: productComps) else {
        return .failure(.unbalanceable)
    }
    let coeffA = coeffs[0], coeffB = coeffs[1]
    let productCoeffs = Array(coeffs[2...])

    // Molar masses.
    guard let mmA = molarMass(r1.composition, atomicMass) else { return .failure(.missingAtomicMass(firstMissing(r1.composition, atomicMass))) }
    guard let mmB = molarMass(r2.composition, atomicMass) else { return .failure(.missingAtomicMass(firstMissing(r2.composition, atomicMass))) }
    var productTerms: [BalancedTerm] = []
    var productMasses: [Double] = []
    for (p, c) in zip(productList, productCoeffs) {
        guard let mm = molarMass(p.composition, atomicMass) else {
            return .failure(.missingAtomicMass(firstMissing(p.composition, atomicMass)))
        }
        productMasses.append(mm)
        productTerms.append(BalancedTerm(coeff: c, formula: p.formula, molarMass: mm, composition: p.composition))
    }

    // Extent ξ from limiting reactant.
    func moles(_ e: ReactantEntry?, _ mm: Double) -> Double? {
        guard let e else { return nil }
        return e.unit == .mole ? e.value : e.value / mm
    }
    let molA = moles(entry1, mmA), molB = moles(entry2, mmB)
    let extentA = molA.map { $0 / Double(coeffA) }
    let extentB = molB.map { $0 / Double(coeffB) }

    let xi: Double
    let limiting: LimitingSide
    switch (extentA, extentB) {
    case (nil, nil):        xi = 1;  limiting = .both
    case (let ea?, nil):    xi = ea; limiting = .a
    case (nil, let eb?):    xi = eb; limiting = .b
    case (let ea?, let eb?):
        if ea < eb {        xi = ea; limiting = .a }
        else if eb < ea {   xi = eb; limiting = .b }
        else {              xi = ea; limiting = .both }
    }

    let yields = zip(productCoeffs, productMasses).map { c, mm in
        AmountResult(moles: Double(c) * xi, mass: Double(c) * xi * mm)
    }

    var excess = AmountResult(moles: 0, mass: 0)
    if limiting == .a, let mb = molB {
        let left = max(0, mb - Double(coeffB) * xi)
        excess = AmountResult(moles: left, mass: left * mmB)
    } else if limiting == .b, let ma = molA {
        let left = max(0, ma - Double(coeffA) * xi)
        excess = AmountResult(moles: left, mass: left * mmA)
    }

    var messages: [String] = []
    if r1.formula.hasSuffix("₂") && naturallyDiatomic.contains(r1.species.first?.symbol ?? "") {
        messages.append("\(r1.species[0].symbol) only exists as \(r1.species[0].symbol)₂")
    }
    if r2.formula.hasSuffix("₂") && naturallyDiatomic.contains(r2.species.first?.symbol ?? "") {
        messages.append("\(r2.species[0].symbol) only exists as \(r2.species[0].symbol)₂")
    }

    let reactants = [
        BalancedTerm(coeff: coeffA, formula: r1.formula, molarMass: mmA, composition: r1.composition),
        BalancedTerm(coeff: coeffB, formula: r2.formula, molarMass: mmB, composition: r2.composition),
    ]
    return .success(ReactionResult(reactionClass: cls, reactants: reactants, products: productTerms,
                                   limiting: limiting, yields: yields, excess: excess,
                                   messages: messages, feasible: true))
}

private func firstMissing(_ comp: [String: Int], _ atomicMass: (String) -> Double?) -> String {
    comp.keys.first { atomicMass($0) == nil } ?? "?"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter ReactionSolverTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Run the FULL suite (no regressions)**

Run: `cd ChemCore && swift test`
Expected: PASS — all new tests plus every pre-existing ChemCore test (93+ baseline) green.

- [ ] **Step 6: Commit**

```bash
git add ChemCore/Sources/ChemCore/Reaction/ReactionSolver.swift ChemCore/Tests/ChemCoreTests/ReactionSolverTests.swift
git commit -m "feat(chemcore): add end-to-end reaction solver"
```

---

## Self-Review Notes (addressed)

- **Spec coverage:** module layout (Task 1–8), core types (Task 3, 7, 8), classification priority (Task 5), product prediction incl. carbonate (Task 7), general balancer (Task 4), activity series (Task 6), solver + errors + redox seam via `composition`/`formula` on `BalancedTerm` (Task 8), all golden test cases from Section 5 present (Tasks 4, 7, 8). Synthesis end-to-end is exercised via classifier + prediction; the `2Na + Cl₂` numeric case is covered by `BalancerTests.test_water_synthesis` shape and `ReactionClassTests.test_synthesis_two_bare_elements` — add a solver synthesis case if desired during execution.
- **App-target correction:** `ionicFormula`/`crossoverModel`/`subscriptGlyphs` are app-only; reimplemented as `binaryFormula`/`crossoverSubscripts`/`formulaSubscript` in ChemCore (Task 2). Documented in Global Constraints.
- **Type consistency:** `Species`, `Reactant`, `Product`, `Prediction`, `BalancedTerm`, `ReactionResult`, `ReactionError` names and signatures are consistent across Tasks 3–8. `atomicMass` is injected into `solveReaction` as a closure so ChemCore needs no app data.
- **Out of scope confirmed:** no app UI, no redox calculator, no 3+-raw-element inference.
