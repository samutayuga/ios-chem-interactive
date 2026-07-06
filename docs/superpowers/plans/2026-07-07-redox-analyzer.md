# Redox Analyzer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a pure ChemCore `analyzeRedox` function that takes a solved `ReactionResult`, computes each element's oxidation state before/after, decides redox vs non-redox, names the oxidising and reducing agents, and builds the redox.md template narrative.

**Architecture:** Two additive files in `ChemCore/Sources/ChemCore/Reaction/`. `OxidationState.swift` assigns oxidation numbers to a compound's flat composition (free-element, polyatomic-ion factoring against the `PolyatomicIon` table, and element-rule solve-by-difference). `RedoxAnalysis.swift` calls it per reactant/product term, compares each element across the reaction, and emits the structured verdict + narrative. `solveReaction` is untouched.

**Tech Stack:** Swift 5, XCTest, Swift Package Manager (ChemCore).

## Global Constraints

- **Depends on the compound-reactant engine** (branch `feat/compound-reactant-engine`): `ReactionResult`, `BalancedTerm`, `AmountResult`, `PolyatomicIon` (with `composition`). Implement on top of that branch.
- **ChemCore is a standalone SPM package.** It MUST NOT depend on the ChemInteractive app target.
- **Additive only.** Do NOT modify `ReactionSolver.swift`, `ProductPrediction.swift`, `PolyatomicIon.swift`, or any existing file/test. All existing ChemCore tests (147 baseline) must stay green.
- **Oxidation-state rules (standard, no exceptions):** F=−1, O=−2, H=+1, halogen(Cl/Br/I)=−1, group 1(Li/Na/K/Rb/Cs/Fr)=+1, group 2(Be/Mg/Ca/Sr/Ba/Ra)=+2, free element=0, monatomic/remaining element solved by difference so a neutral compound sums to 0. No peroxide/hydride/OF₂ special cases.
- **Indeterminate:** if a compound leaves ≥2 elements unresolved, `oxidationState` returns `nil`; the analyzer records that formula in `indeterminate` and excludes it from the verdict (never guesses, never crashes).
- **Known limitation (document, do not engineer around):** a compound holding the same element in two oxidation environments (e.g. NH₄NO₃ with N at −3 and +5) has only one composition entry for that element, so the rules yield a single averaged value. This can mis-analyze such a product. It is not produced by the common reaction set and is out of school scope; leave a code comment noting it.
- **Signed rendering:** oxidation integers render in the narrative with an explicit sign — `+7`, `0`, and negatives with the Unicode minus `−` (e.g. `−2`).
- **Test command:** `cd ChemCore && swift test --filter <TestClass>` (single class) or `cd ChemCore && swift test` (full suite). Tests use `@testable import ChemCore`, which exposes the internal memberwise inits of `BalancedTerm`/`ReactionResult`.
- **Commit convention:** end body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

- `ChemCore/Sources/ChemCore/Reaction/OxidationState.swift` — **create**: `oxidationState(of:)` assignment.
- `ChemCore/Sources/ChemCore/Reaction/RedoxAnalysis.swift` — **create**: types + `analyzeRedox`.
- Tests: `ChemCore/Tests/ChemCoreTests/OxidationStateTests.swift`, `RedoxAnalysisTests.swift`.

Two tasks, in order: OxidationState (algorithm) → RedoxAnalysis (verdict + narrative, consumes it).

---

### Task 1: Oxidation-state assignment

**Files:**
- Create: `ChemCore/Sources/ChemCore/Reaction/OxidationState.swift`
- Test: `ChemCore/Tests/ChemCoreTests/OxidationStateTests.swift`

**Interfaces:**
- Consumes: `PolyatomicIon.polyatomicIons` (each has `composition: [String: Int]` and `charge: Int`).
- Produces: `func oxidationState(of composition: [String: Int]) -> [String: Int]?` — element→oxidation state for a neutral compound, or `nil` if indeterminate.

- [ ] **Step 1: Write the failing test**

```swift
// ChemCore/Tests/ChemCoreTests/OxidationStateTests.swift
import XCTest
@testable import ChemCore

final class OxidationStateTests: XCTestCase {
    func test_free_element_is_zero() {
        XCTAssertEqual(oxidationState(of: ["Zn": 1]), ["Zn": 0])
        XCTAssertEqual(oxidationState(of: ["O": 2]), ["O": 0])   // O₂
    }
    func test_binary_ionic() {
        XCTAssertEqual(oxidationState(of: ["Na": 1, "Cl": 1]), ["Na": 1, "Cl": -1])
        XCTAssertEqual(oxidationState(of: ["Mg": 1, "O": 1]), ["Mg": 2, "O": -2])
    }
    func test_solve_by_difference() {
        XCTAssertEqual(oxidationState(of: ["C": 1, "O": 2]), ["C": 4, "O": -2])          // CO₂
        XCTAssertEqual(oxidationState(of: ["K": 1, "Mn": 1, "O": 4]), ["K": 1, "Mn": 7, "O": -2]) // KMnO₄
        XCTAssertEqual(oxidationState(of: ["Fe": 1, "Cl": 3]), ["Fe": 3, "Cl": -1])       // FeCl₃
    }
    func test_water_uses_element_rules() {
        XCTAssertEqual(oxidationState(of: ["H": 2, "O": 1]), ["H": 1, "O": -2])
    }
    func test_polyatomic_factoring() {
        XCTAssertEqual(oxidationState(of: ["Na": 1, "O": 1, "H": 1]), ["Na": 1, "O": -2, "H": 1]) // NaOH
        XCTAssertEqual(oxidationState(of: ["Na": 2, "S": 1, "O": 4]), ["Na": 1, "S": 6, "O": -2]) // Na₂SO₄
        XCTAssertEqual(oxidationState(of: ["Cu": 1, "S": 1, "O": 4]), ["Cu": 2, "S": 6, "O": -2]) // CuSO₄
        XCTAssertEqual(oxidationState(of: ["Na": 2, "C": 1, "O": 3]), ["Na": 1, "C": 4, "O": -2]) // Na₂CO₃
        XCTAssertEqual(oxidationState(of: ["N": 1, "H": 4, "Cl": 1]), ["N": -3, "H": 1, "Cl": -1]) // NH₄Cl
    }
    func test_indeterminate_returns_nil() {
        XCTAssertNil(oxidationState(of: ["Cu": 1, "S": 1]))   // CuS: two rule-less elements
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter OxidationStateTests`
Expected: FAIL — `cannot find 'oxidationState' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemCore/Sources/ChemCore/Reaction/OxidationState.swift
import Foundation

private let group1: Set<String> = ["Li", "Na", "K", "Rb", "Cs", "Fr"]
private let group2: Set<String> = ["Be", "Mg", "Ca", "Sr", "Ba", "Ra"]
private let halogensMinusOne: Set<String> = ["Cl", "Br", "I"]

/// The fixed oxidation state for elements governed by a simple rule, else nil.
/// No peroxide/hydride exceptions — this engine never produces them.
private func fixedState(_ symbol: String) -> Int? {
    switch symbol {
    case "F": return -1
    case "O": return -2
    case "H": return 1
    default:
        if halogensMinusOne.contains(symbol) { return -1 }
        if group1.contains(symbol) { return 1 }
        if group2.contains(symbol) { return 2 }
        return nil
    }
}

private func atomCount(_ c: [String: Int]) -> Int { c.values.reduce(0, +) }

/// Largest k with comp ⊇ k·ion, or nil if the ion is not wholly contained.
private func maxMultiple(_ comp: [String: Int], _ ion: [String: Int]) -> Int? {
    var k = Int.max
    for (sym, n) in ion {
        let have = comp[sym] ?? 0
        if have < n { return nil }
        k = min(k, have / n)
    }
    return k == Int.max ? nil : k
}

/// Oxidation states inside a polyatomic ion: O/H fixed, the central atom solved so
/// the ion's atoms sum to its charge. nil if not resolvable to a single unknown.
private func statesWithinIon(_ ion: PolyatomicIon) -> [String: Int]? {
    var states: [String: Int] = [:]
    var assignedSum = 0
    var unknown: String?
    for (sym, n) in ion.composition {
        if let fx = fixedState(sym) { states[sym] = fx; assignedSum += fx * n }
        else if unknown == nil { unknown = sym }
        else { return nil }
    }
    if let u = unknown {
        let count = ion.composition[u]!
        let need = ion.charge - assignedSum
        guard need % count == 0 else { return nil }
        states[u] = need / count
    } else if assignedSum != ion.charge {
        return nil
    }
    return states
}

/// Try to read the compound as (counter-ion)·(known polyatomic ion): factor the ion
/// out, assign the disjoint remainder element the charge that balances it.
private func factorPolyatomic(_ comp: [String: Int]) -> [String: Int]? {
    let ions = PolyatomicIon.polyatomicIons.sorted { atomCount($0.composition) > atomCount($1.composition) }
    for ion in ions {
        guard let k = maxMultiple(comp, ion.composition), k >= 1 else { continue }
        var remainder = comp
        for (sym, n) in ion.composition {
            remainder[sym, default: 0] -= n * k
            if remainder[sym] == 0 { remainder[sym] = nil }
        }
        // Remainder must be a single element, disjoint from the ion's elements.
        guard remainder.count == 1, let (counterSym, counterCount) = remainder.first,
              Set(remainder.keys).isDisjoint(with: ion.composition.keys),
              let ionStates = statesWithinIon(ion) else { continue }
        let counterTotal = -ion.charge * k
        guard counterCount != 0, counterTotal % counterCount == 0 else { continue }
        var result = ionStates
        result[counterSym] = counterTotal / counterCount
        return result
    }
    return nil
}

/// Element rules + solve the single remaining unknown so a neutral compound sums to 0.
private func byElementRules(_ comp: [String: Int]) -> [String: Int]? {
    var states: [String: Int] = [:]
    var assignedSum = 0
    var unknowns: [String] = []
    for (sym, n) in comp {
        if let fx = fixedState(sym) { states[sym] = fx; assignedSum += fx * n }
        else { unknowns.append(sym) }
    }
    guard unknowns.count <= 1 else { return nil }
    if let u = unknowns.first {
        let count = comp[u]!
        let need = -assignedSum
        guard need % count == 0 else { return nil }
        states[u] = need / count
    } else if assignedSum != 0 {
        return nil
    }
    return states
}

/// Oxidation state of every element in a NEUTRAL compound, or nil if the standard
/// rules leave it under-determined.
/// Known limitation: a compound with the same element in two oxidation environments
/// (e.g. NH₄NO₃) collapses to one composition entry and yields a single averaged
/// value rather than nil — out of scope for this engine's reaction set.
public func oxidationState(of composition: [String: Int]) -> [String: Int]? {
    if composition.count == 1, let sym = composition.keys.first {
        return [sym: 0]                                  // free element
    }
    if let byIon = factorPolyatomic(composition) { return byIon }
    return byElementRules(composition)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter OxidationStateTests`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Reaction/OxidationState.swift ChemCore/Tests/ChemCoreTests/OxidationStateTests.swift
git commit -m "feat(chemcore): add oxidation-state assignment for compounds"
```

---

### Task 2: Redox analysis (verdict, agents, narrative)

**Files:**
- Create: `ChemCore/Sources/ChemCore/Reaction/RedoxAnalysis.swift`
- Test: `ChemCore/Tests/ChemCoreTests/RedoxAnalysisTests.swift`

**Interfaces:**
- Consumes: `oxidationState(of:)` (Task 1); `ReactionResult`, `BalancedTerm` (existing).
- Produces:
  - `enum OxidationChange: Equatable, Sendable { case oxidised, reduced, unchanged }`
  - `struct ElementRedox: Equatable, Sendable { let symbol: String; let before: Int; let after: Int; let change: OxidationChange; let reactantFormula: String; let productFormula: String }`
  - `struct RedoxAnalysis: Equatable, Sendable { let isRedox: Bool; let oxidisingAgent: String?; let reducingAgent: String?; let changes: [ElementRedox]; let oxidationStates: [String: [String: Int]]; let indeterminate: [String]; let narrative: [String] }`
  - `func analyzeRedox(_ result: ReactionResult, name: (String) -> String? = { _ in nil }) -> RedoxAnalysis`

- [ ] **Step 1: Write the failing test**

```swift
// ChemCore/Tests/ChemCoreTests/RedoxAnalysisTests.swift
import XCTest
@testable import ChemCore

final class RedoxAnalysisTests: XCTestCase {
    private func term(_ coeff: Int, _ formula: String, _ comp: [String: Int]) -> BalancedTerm {
        BalancedTerm(coeff: coeff, formula: formula, molarMass: 0, composition: comp)
    }
    private func result(_ reactants: [BalancedTerm], _ products: [BalancedTerm],
                        feasible: Bool = true) -> ReactionResult {
        ReactionResult(reactionClass: .singleDisplacement, reactants: reactants, products: products,
                       limiting: .both, yields: [], excess: AmountResult(moles: 0, mass: 0),
                       messages: [], feasible: feasible)
    }

    func test_synthesis_is_redox() {
        let r = result([term(2, "Na", ["Na": 1]), term(1, "Cl₂", ["Cl": 2])],
                       [term(2, "NaCl", ["Na": 1, "Cl": 1])])
        let a = analyzeRedox(r)
        XCTAssertTrue(a.isRedox)
        XCTAssertEqual(a.reducingAgent, "Na")     // Na 0 → +1 (oxidised)
        XCTAssertEqual(a.oxidisingAgent, "Cl₂")   // Cl 0 → −1 (reduced)
        XCTAssertEqual(Set(a.changes.map(\.symbol)), ["Na", "Cl"])
    }

    func test_single_displacement_agents() {
        let r = result([term(1, "Zn", ["Zn": 1]), term(1, "CuSO₄", ["Cu": 1, "S": 1, "O": 4])],
                       [term(1, "ZnSO₄", ["Zn": 1, "S": 1, "O": 4]), term(1, "Cu", ["Cu": 1])])
        let a = analyzeRedox(r)
        XCTAssertTrue(a.isRedox)
        XCTAssertEqual(a.reducingAgent, "Zn")
        XCTAssertEqual(a.oxidisingAgent, "CuSO₄")
        let zn = a.changes.first { $0.symbol == "Zn" }!
        XCTAssertEqual([zn.before, zn.after], [0, 2])
        XCTAssertFalse(a.changes.contains { $0.symbol == "S" || $0.symbol == "O" }) // unchanged
    }

    func test_combustion_is_redox() {
        let r = result([term(1, "CH₄", ["C": 1, "H": 4]), term(2, "O₂", ["O": 2])],
                       [term(1, "CO₂", ["C": 1, "O": 2]), term(2, "H₂O", ["H": 2, "O": 1])])
        let a = analyzeRedox(r)
        XCTAssertTrue(a.isRedox)
        XCTAssertEqual(a.reducingAgent, "CH₄")    // C −4 → +4
        XCTAssertEqual(a.oxidisingAgent, "O₂")    // O 0 → −2
    }

    func test_neutralisation_is_non_redox() {
        let r = result([term(1, "NaOH", ["Na": 1, "O": 1, "H": 1]), term(1, "HCl", ["H": 1, "Cl": 1])],
                       [term(1, "NaCl", ["Na": 1, "Cl": 1]), term(1, "H₂O", ["H": 2, "O": 1])])
        let a = analyzeRedox(r)
        XCTAssertFalse(a.isRedox)
        XCTAssertNil(a.oxidisingAgent)
        XCTAssertNil(a.reducingAgent)
        XCTAssertTrue(a.changes.isEmpty)
        XCTAssertEqual(a.narrative, ["This is a non-redox reaction — no oxidation states change."])
    }

    func test_infeasible_is_empty() {
        let r = result([term(1, "Cu", ["Cu": 1])], [], feasible: false)
        let a = analyzeRedox(r)
        XCTAssertFalse(a.isRedox)
        XCTAssertTrue(a.changes.isEmpty && a.narrative.isEmpty)
    }

    func test_narrative_and_name_closure() {
        let r = result([term(1, "Zn", ["Zn": 1]), term(1, "CuSO₄", ["Cu": 1, "S": 1, "O": 4])],
                       [term(1, "ZnSO₄", ["Zn": 1, "S": 1, "O": 4]), term(1, "Cu", ["Cu": 1])])
        let a = analyzeRedox(r) { $0 == "CuSO₄" ? "copper(II) sulfate" : nil }
        // A per-element line uses signed states and the substituted name.
        XCTAssertTrue(a.narrative.contains { $0.contains("Zn is oxidised") && $0.contains("from 0 in Zn to +2 in ZnSO₄") })
        XCTAssertTrue(a.narrative.contains { $0.contains("copper(II) sulfate is the oxidising agent") })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter RedoxAnalysisTests`
Expected: FAIL — `cannot find 'analyzeRedox' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemCore/Sources/ChemCore/Reaction/RedoxAnalysis.swift
import Foundation

public enum OxidationChange: Equatable, Sendable { case oxidised, reduced, unchanged }

public struct ElementRedox: Equatable, Sendable {
    public let symbol: String
    public let before: Int
    public let after: Int
    public let change: OxidationChange
    public let reactantFormula: String
    public let productFormula: String
}

public struct RedoxAnalysis: Equatable, Sendable {
    public let isRedox: Bool
    public let oxidisingAgent: String?
    public let reducingAgent: String?
    public let changes: [ElementRedox]
    public let oxidationStates: [String: [String: Int]]
    public let indeterminate: [String]
    public let narrative: [String]
}

private func signed(_ n: Int) -> String {
    if n > 0 { return "+\(n)" }
    if n < 0 { return "−\(-n)" }   // U+2212 minus
    return "0"
}

private let empty = RedoxAnalysis(isRedox: false, oxidisingAgent: nil, reducingAgent: nil,
                                  changes: [], oxidationStates: [:], indeterminate: [], narrative: [])

/// Oxidation-state analysis of a solved reaction: redox verdict, oxidising/reducing
/// agents, per-element changes, and a template narrative. `name` maps a formula to a
/// display name (nil ⇒ use the formula). Only feasible reactions with products are analysed.
public func analyzeRedox(_ result: ReactionResult,
                         name: (String) -> String? = { _ in nil }) -> RedoxAnalysis {
    guard result.feasible, !result.products.isEmpty else { return empty }

    // Oxidation states per compound; unresolved compounds are recorded and skipped.
    var statesByFormula: [String: [String: Int]] = [:]
    var indeterminate: [String] = []
    for term in result.reactants + result.products {
        if let states = oxidationState(of: term.composition) {
            statesByFormula[term.formula] = states
        } else {
            indeterminate.append(term.formula)
        }
    }

    // element → [(formula, state)] on each side.
    func occurrences(_ terms: [BalancedTerm]) -> [String: [(formula: String, state: Int)]] {
        var map: [String: [(String, Int)]] = [:]
        for t in terms {
            guard let states = statesByFormula[t.formula] else { continue }
            for (sym, s) in states { map[sym, default: []].append((t.formula, s)) }
        }
        return map
    }
    let reactantOcc = occurrences(result.reactants)
    let productOcc = occurrences(result.products)

    var changes: [ElementRedox] = []
    for sym in Set(reactantOcc.keys).intersection(productOcc.keys).sorted() {
        let beforeStates = Set(reactantOcc[sym]!.map(\.state))
        let afterStates = Set(productOcc[sym]!.map(\.state))
        guard beforeStates.count == 1, afterStates.count == 1 else { continue } // ambiguous → skip
        let before = beforeStates.first!, after = afterStates.first!
        guard before != after else { continue }
        changes.append(ElementRedox(
            symbol: sym, before: before, after: after,
            change: after > before ? .oxidised : .reduced,
            reactantFormula: reactantOcc[sym]!.first!.formula,
            productFormula: productOcc[sym]!.first!.formula))
    }

    let isRedox = !changes.isEmpty
    let reducing = changes.first { $0.change == .oxidised }
    let oxidising = changes.first { $0.change == .reduced }

    func display(_ f: String) -> String { name(f) ?? f }
    var narrative: [String] = []
    if !isRedox {
        narrative.append("This is a non-redox reaction — no oxidation states change.")
    } else {
        for c in changes {
            let verb = c.change == .oxidised ? "oxidised" : "reduced"
            let dir = c.change == .oxidised ? "increases" : "decreases"
            narrative.append("\(display(c.reactantFormula)) is \(verb) because \(c.symbol)'s oxidation state \(dir) from \(signed(c.before)) in \(display(c.reactantFormula)) to \(signed(c.after)) in \(display(c.productFormula)).")
        }
        if let ox = oxidising, let red = reducing {
            narrative.append("\(display(ox.reactantFormula)) is the oxidising agent — it oxidises \(display(red.reactantFormula)) and is itself reduced, its oxidation state decreasing from \(signed(ox.before)) to \(signed(ox.after)).")
            narrative.append("\(display(red.reactantFormula)) is the reducing agent — it reduces \(display(ox.reactantFormula)) and is itself oxidised, its oxidation state increasing from \(signed(red.before)) to \(signed(red.after)).")
        }
    }

    return RedoxAnalysis(
        isRedox: isRedox,
        oxidisingAgent: oxidising?.reactantFormula,
        reducingAgent: reducing?.reactantFormula,
        changes: changes,
        oxidationStates: statesByFormula,
        indeterminate: indeterminate,
        narrative: narrative)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter RedoxAnalysisTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Run the full ChemCore suite (no regressions)**

Run: `cd ChemCore && swift test 2>&1 | grep "Executed" | tail -1`
Expected: `Executed 160 tests, with 0 failures` (147 baseline + 7 OxidationState + 6 RedoxAnalysis).

- [ ] **Step 6: Commit**

```bash
git add ChemCore/Sources/ChemCore/Reaction/RedoxAnalysis.swift ChemCore/Tests/ChemCoreTests/RedoxAnalysisTests.swift
git commit -m "feat(chemcore): add redox analysis over solved reactions"
```

---

## Self-Review Notes (addressed)

- **Spec coverage:** oxidation-state rules + polyatomic factoring + solve-by-difference + free element (Task 1); redox verdict, agents, per-element changes, oxidationStates map, indeterminate list, narrative + name closure, non-redox and infeasible handling (Task 2). All worked cases from the spec appear as tests (synthesis, single displacement, combustion, neutralisation, infeasible; carbonate is the same non-redox path as neutralisation and covered structurally).
- **Provenance:** handled via `factorPolyatomic` against `PolyatomicIon.composition` — no engine change, per the spec's key insight.
- **Placeholder scan:** none.
- **Type consistency:** `oxidationState(of:)`, `RedoxAnalysis`, `ElementRedox`, `OxidationChange`, `analyzeRedox(_:name:)` names/signatures consistent across tasks and with the spec.
- **Documented limitation:** the same-element-two-environments case (NH₄NO₃) is noted in Global Constraints and as a code comment on `oxidationState`.
- **Signed rendering:** `signed(_:)` emits `+n` / `0` / `−n` (Unicode minus), matching the spec.
