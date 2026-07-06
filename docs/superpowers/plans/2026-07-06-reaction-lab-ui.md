# Reaction Lab App UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add "Reaction Lab" — a new third app mode where the student assembles two compound reactants (1–2 species each) and sees the classified, balanced reaction with yields render live, driven by the ChemCore compound-reactant engine.

**Architecture:** Fully additive to the SwiftUI app. A pure `SpeciesMapping` seam turns placed `ZoneState`s into engine `Species`/`Reactant`s (pair-aware charge assignment); an `@Observable ReactionLabModel` runs `solveReaction`; pure `ReactionLedgerFormat` functions format the result; thin SwiftUI views render it; a segmented `RootModeView` switches between the existing Bonding canvas and Reaction Lab under a shared periodic tray.

**Tech Stack:** Swift 5, SwiftUI (iOS 17), XCTest, `xcodebuild`, Swift Package Manager (ChemCore). Xcode project uses file-system-synchronized folders — new files under `ChemInteractive/` and `ChemInteractiveTests/` join their targets automatically (no `.pbxproj` edits).

## Global Constraints

- **Depends on the ChemCore compound-reactant engine** (branch `feat/compound-reactant-engine`): `solveReaction`, `makeReactant`, `Species`, `Reactant`, `ReactionResult`, `BalancedTerm`, `ReactionError`, `ReactionClass`. Implement this plan on top of that branch (or after it merges).
- **Additive only.** Do NOT modify bonding mode logic, `CanvasModel`, `DropZoneView`, `BridgeView`, or the existing Stoichiometry flow. The one allowed refactor: extract the canvas body out of `ChemCanvasView` into `BondingCanvas` and route the app through a new `RootModeView` (Task 7).
- **ChemCore change is one additive field:** `PolyatomicIon.composition: [String: Int]` (Task 1). All 140 ChemCore tests must stay green.
- **Charge assignment is pair-aware** (the engine treats two species with explicit opposite charges as ionic, to model acids). Rule, per zone: either species polyatomic → ionic; metal+nonmetal → ionic; nonmetal+nonmetal → ionic ONLY for the acid case (H + group-17 halogen), else covalent (charges nil). Single species → carry its ionic charge (needed for later product crossover). Keeps NaCl/NaOH/Na₂SO₄/HCl ionic and CH₄/CO₂ covalent.
- **Placement is drag-and-drop** into the reactant zones (the tray's `TokenTransfer` drag payload is model-agnostic). Tap-to-select-then-place stays bonding-mode-only in v1 (the shared tray remains bound to `CanvasModel`); this is a deliberate scope decision, not an omission to fix.
- **App test command:** `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/<TestClass> 2>&1 | tail -20`. If that simulator is unavailable, pick one from `xcrun simctl list devices available` and use its name. SourceKit "No such module 'ChemCore'/'XCTest'" warnings are IDE-indexing noise — `xcodebuild` is the authoritative gate.
- **App build gate (for view tasks):** `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20` → expect `BUILD SUCCEEDED`.
- **ChemCore test command:** `cd ChemCore && swift test --filter <TestClass>`.
- **Commit message convention:** end body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

- `ChemCore/Sources/ChemCore/State/PolyatomicIon.swift` — **modify**: add `composition`.
- `ChemInteractive/State/SpeciesMapping.swift` — **create**: `ZoneState`→`Species`, pair-aware `buildReactant`.
- `ChemInteractive/State/ReactionLabModel.swift` — **create**: `@Observable` model.
- `ChemInteractive/Theme/ReactionLedgerFormat.swift` — **create**: pure result formatting + `LedgerOutcome`.
- `ChemInteractive/Views/ReactionLab/ReactantZoneView.swift` — **create**: build zone.
- `ChemInteractive/Views/ReactionLab/ReactionTypeBadge.swift`, `NoReactionView.swift`, `ReactionLedgerView.swift` — **create**: result UI.
- `ChemInteractive/Views/ReactionLab/ReactionLabView.swift` — **create**: layout B.
- `ChemInteractive/Views/BondingCanvas.swift` — **create**: extracted bonding canvas.
- `ChemInteractive/Views/RootModeView.swift` — **create**: segmented mode switcher.
- `ChemInteractive/Views/ChemCanvasView.swift` — **delete** (superseded by `RootModeView` + `BondingCanvas`).
- `ChemInteractive/ChemInteractiveApp.swift` — **modify**: host `RootModeView`.
- Tests: `ChemCoreTests/PolyatomicIonCompositionTests.swift`, `ChemInteractiveTests/SpeciesMappingTests.swift`, `ReactionLabModelTests.swift`, `ReactionLedgerFormatTests.swift`.

---

### Task 1: PolyatomicIon.composition (ChemCore)

**Files:**
- Modify: `ChemCore/Sources/ChemCore/State/PolyatomicIon.swift`
- Test: `ChemCore/Tests/ChemCoreTests/PolyatomicIonCompositionTests.swift`

**Interfaces:**
- Produces: `PolyatomicIon.composition: [String: Int]` (new stored property + init parameter), populated for all 6 ions.

- [ ] **Step 1: Write the failing test**

```swift
// ChemCore/Tests/ChemCoreTests/PolyatomicIonCompositionTests.swift
import XCTest
@testable import ChemCore

final class PolyatomicIonCompositionTests: XCTestCase {
    private func ion(_ symbol: String) -> PolyatomicIon {
        PolyatomicIon.polyatomicIons.first { $0.symbol == symbol }!
    }
    func test_hydroxide() { XCTAssertEqual(ion("OH").composition, ["O": 1, "H": 1]) }
    func test_sulfate()   { XCTAssertEqual(ion("SO₄").composition, ["S": 1, "O": 4]) }
    func test_nitrate()   { XCTAssertEqual(ion("NO₃").composition, ["N": 1, "O": 3]) }
    func test_carbonate() { XCTAssertEqual(ion("CO₃").composition, ["C": 1, "O": 3]) }
    func test_phosphate() { XCTAssertEqual(ion("PO₄").composition, ["P": 1, "O": 4]) }
    func test_ammonium()  { XCTAssertEqual(ion("NH₄").composition, ["N": 1, "H": 4]) }
    func test_zoneState_still_builds() {
        let z = ZoneState(polyatomic: ion("SO₄"))
        XCTAssertEqual(z.symbol, "SO₄")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter PolyatomicIonCompositionTests`
Expected: FAIL — `value of type 'PolyatomicIon' has no member 'composition'`.

- [ ] **Step 3: Write minimal implementation**

Replace the contents of `ChemCore/Sources/ChemCore/State/PolyatomicIon.swift` with:

```swift
public struct PolyatomicIon: Equatable, Sendable {
    public let symbol: String
    public let name: String
    public let charge: Int
    public let formula: String
    public let composition: [String: Int]

    public init(symbol: String, name: String, charge: Int, formula: String, composition: [String: Int]) {
        self.symbol = symbol; self.name = name; self.charge = charge
        self.formula = formula; self.composition = composition
    }

    public static let polyatomicIons: [PolyatomicIon] = [
        PolyatomicIon(symbol: "OH",  name: "Hydroxide", charge: -1, formula: "OH⁻",  composition: ["O": 1, "H": 1]),
        PolyatomicIon(symbol: "NO₃", name: "Nitrate",   charge: -1, formula: "NO₃⁻", composition: ["N": 1, "O": 3]),
        PolyatomicIon(symbol: "SO₄", name: "Sulfate",   charge: -2, formula: "SO₄²⁻", composition: ["S": 1, "O": 4]),
        PolyatomicIon(symbol: "CO₃", name: "Carbonate", charge: -2, formula: "CO₃²⁻", composition: ["C": 1, "O": 3]),
        PolyatomicIon(symbol: "PO₄", name: "Phosphate", charge: -3, formula: "PO₄³⁻", composition: ["P": 1, "O": 4]),
        PolyatomicIon(symbol: "NH₄", name: "Ammonium",  charge: 1,  formula: "NH₄⁺",  composition: ["N": 1, "H": 4]),
    ]
}
```

- [ ] **Step 4: Run the new test + the full ChemCore suite**

Run: `cd ChemCore && swift test --filter PolyatomicIonCompositionTests`
Expected: PASS (7 tests).
Run: `cd ChemCore && swift test`
Expected: PASS — all 140 prior tests + 7 new stay green.

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/State/PolyatomicIon.swift ChemCore/Tests/ChemCoreTests/PolyatomicIonCompositionTests.swift
git commit -m "feat(chemcore): add element composition to PolyatomicIon"
```

---

### Task 2: SpeciesMapping (ZoneState → Species/Reactant)

**Files:**
- Create: `ChemInteractive/State/SpeciesMapping.swift`
- Test: `ChemInteractiveTests/SpeciesMappingTests.swift`

**Interfaces:**
- Consumes: `PolyatomicIon.composition` (Task 1); ChemCore `Species`, `Reactant`, `makeReactant`, `ZoneState`, `Element`, `ElementClass`.
- Produces: `enum SpeciesMapping` with `static func buildReactant(_ zones: [ZoneState], elements: [Element], ions: [PolyatomicIon]) -> Reactant?`, plus helpers `toSpecies`, `atomicMass(for:...)`, `composition(for:...)`, `ionicCharge(_:)`, `isIonicPair(_:_:)`, `isAcidPair(_:_:)`.

- [ ] **Step 1: Write the failing test**

```swift
// ChemInteractiveTests/SpeciesMappingTests.swift
import XCTest
import ChemCore
@testable import ChemInteractive

final class SpeciesMappingTests: XCTestCase {
    private let elements = try! PeriodicTable.load().elements
    private let ions = PolyatomicIon.polyatomicIons

    private func el(_ symbol: String) -> ZoneState {
        ZoneState(element: elements.first { $0.symbol == symbol }!)
    }
    private func ion(_ symbol: String) -> ZoneState {
        ZoneState(polyatomic: ions.first { $0.symbol == symbol }!)
    }
    private func build(_ zones: [ZoneState]) -> Reactant? {
        SpeciesMapping.buildReactant(zones, elements: elements, ions: ions)
    }

    func test_bare_metal_carries_charge() {
        let r = build([el("Na")])
        XCTAssertEqual(r?.formula, "Na")
        XCTAssertEqual(r?.species.first?.charge, 1)
        XCTAssertTrue(r?.isBareElement == true)
    }
    func test_ionic_nacl() {
        let r = build([el("Na"), el("Cl")])
        XCTAssertEqual(r?.formula, "NaCl")
        XCTAssertEqual(r?.cation?.symbol, "Na")
        XCTAssertEqual(r?.anion?.symbol, "Cl")
    }
    func test_acid_hcl_is_ionic() {
        let r = build([el("H"), el("Cl")])
        XCTAssertEqual(r?.formula, "HCl")
        XCTAssertEqual(r?.cation?.symbol, "H")
        XCTAssertEqual(r?.anion?.symbol, "Cl")
    }
    func test_methane_is_covalent() {
        let r = build([el("C"), el("H")])
        XCTAssertEqual(r?.composition, ["C": 1, "H": 4])
        XCTAssertNil(r?.cation)     // covalent: no ionic pair
    }
    func test_ionic_with_polyatomic() {
        let r = build([el("Na"), ion("SO₄")])
        XCTAssertEqual(r?.formula, "Na₂SO₄")
        XCTAssertEqual(r?.composition, ["Na": 2, "S": 1, "O": 4])
    }
    func test_pending_transition_metal_returns_nil() {
        // Fe placed but no charge picked yet → cannot build.
        var fe = el("Fe")
        XCTAssertTrue(fe.isTransition)
        fe.derivedCharge = nil
        XCTAssertNil(build([fe, ion("SO₄")]))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/SpeciesMappingTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'SpeciesMapping' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemInteractive/State/SpeciesMapping.swift
import Foundation
import ChemCore

/// Pure conversion from placed ZoneStates to ChemCore reaction inputs. Charge
/// assignment is pair-aware so acids (HCl) read ionic while covalent fuels (CH₄) do not.
enum SpeciesMapping {
    static func composition(for z: ZoneState, ions: [PolyatomicIon]) -> [String: Int] {
        if z.isPolyatomic {
            return ions.first { $0.symbol == z.symbol }?.composition ?? [:]
        }
        return [z.symbol: 1]
    }

    static func atomicMass(for z: ZoneState, elements: [Element], ions: [PolyatomicIon]) -> Double? {
        if z.isPolyatomic {
            guard let ion = ions.first(where: { $0.symbol == z.symbol }) else { return nil }
            var total = 0.0
            for (sym, n) in ion.composition {
                guard let m = elements.first(where: { $0.symbol == sym })?.atomicMass else { return nil }
                total += m * Double(n)
            }
            return total
        }
        return elements.first { $0.symbol == z.symbol }?.atomicMass
    }

    static func toSpecies(_ z: ZoneState, charge: Int?, elements: [Element], ions: [PolyatomicIon]) -> Species? {
        guard let m = atomicMass(for: z, elements: elements, ions: ions) else { return nil }
        return Species(symbol: z.symbol, atomicMass: m, charge: charge,
                       elementClass: z.elementClass, isPolyatomic: z.isPolyatomic,
                       valenceElectrons: z.valenceElectrons, group: z.group, period: z.period,
                       composition: composition(for: z, ions: ions))
    }

    /// The charge a species carries when its zone is ionic (or a bare element whose
    /// charge a later product crossover needs).
    static func ionicCharge(_ z: ZoneState) -> Int? {
        if z.isPolyatomic { return z.oxidationStates.first }        // ZoneState(polyatomic:) stores [charge]
        if z.isTransition { return z.derivedCharge }
        if z.symbol == "H" { return 1 }
        if z.elementClass == .metal { return z.derivedCharge ?? z.oxidationStates.first { $0 > 0 } }
        return z.oxidationStates.first { $0 < 0 }                   // nonmetal anion
    }

    static func isAcidPair(_ a: ZoneState, _ b: ZoneState) -> Bool {
        (a.symbol == "H" && b.group == 17) || (b.symbol == "H" && a.group == 17)
    }

    static func isIonicPair(_ a: ZoneState, _ b: ZoneState) -> Bool {
        if a.isPolyatomic || b.isPolyatomic { return true }
        let metals = [a, b].filter { $0.elementClass == .metal }.count
        if metals == 1 { return true }
        if metals == 2 { return false }
        return isAcidPair(a, b)
    }

    static func buildReactant(_ zones: [ZoneState], elements: [Element], ions: [PolyatomicIon]) -> Reactant? {
        guard !zones.isEmpty, zones.count <= 2 else { return nil }
        for z in zones where z.isTransition && z.derivedCharge == nil { return nil }

        let charges: [Int?]
        if zones.count == 1 {
            charges = [ionicCharge(zones[0])]
        } else if isIonicPair(zones[0], zones[1]) {
            charges = [ionicCharge(zones[0]), ionicCharge(zones[1])]
        } else {
            charges = [nil, nil]   // covalent path
        }

        let specs = zip(zones, charges).compactMap {
            toSpecies($0.0, charge: $0.1, elements: elements, ions: ions)
        }
        guard specs.count == zones.count else { return nil }
        return makeReactant(specs)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/SpeciesMappingTests 2>&1 | tail -20`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/State/SpeciesMapping.swift ChemInteractiveTests/SpeciesMappingTests.swift
git commit -m "feat(app): add pair-aware SpeciesMapping ZoneState->Reactant"
```

---

### Task 3: ReactionLabModel

**Files:**
- Create: `ChemInteractive/State/ReactionLabModel.swift`
- Test: `ChemInteractiveTests/ReactionLabModelTests.swift`

**Interfaces:**
- Consumes: `SpeciesMapping.buildReactant` (Task 2); `TokenTransfer` (existing, in `CanvasModel.swift`); ChemCore `solveReaction`, `ReactionResult`, `ReactionError`, `ReactantEntry`, `ZoneState`, `PeriodicTable`.
- Produces: `@Observable final class ReactionLabModel` with `zone1/zone2: [ZoneState]`, `quantity1/quantity2: ReactantEntry?`, `pendingCharge: PendingCharge?` (`struct PendingCharge { let zone: Int; let index: Int }`), methods `zoneState(for:)`, `place(_:inZone:)`, `pickCharge(_:)`, `removeToken(zone:index:)`, `setQuantity(_:zone:)`, `reset()`, and computed `reactant1/reactant2: Reactant?`, `result: Result<ReactionResult, ReactionError>?`.

- [ ] **Step 1: Write the failing test**

```swift
// ChemInteractiveTests/ReactionLabModelTests.swift
import XCTest
import ChemCore
@testable import ChemInteractive

final class ReactionLabModelTests: XCTestCase {
    private func token(_ symbol: String, poly: Bool = false) -> TokenTransfer {
        TokenTransfer(symbol: symbol, isPolyatomic: poly)
    }

    func test_neutralisation_feasible() {
        let m = ReactionLabModel()
        m.place(token("Na"), inZone: 1); m.place(token("OH", poly: true), inZone: 1)
        m.place(token("H"), inZone: 2);  m.place(token("Cl"), inZone: 2)
        guard case .success(let r)? = m.result else { return XCTFail("expected success") }
        XCTAssertEqual(r.reactionClass, .doubleDisplacement)
        XCTAssertTrue(r.feasible)
        XCTAssertEqual(Set(r.products.map(\.formula)), ["NaCl", "H₂O"])
    }

    func test_carbonate_three_products() {
        let m = ReactionLabModel()
        m.place(token("H"), inZone: 1); m.place(token("Cl"), inZone: 1)
        m.place(token("Na"), inZone: 2); m.place(token("CO₃", poly: true), inZone: 2)
        guard case .success(let r)? = m.result else { return XCTFail("expected success") }
        XCTAssertEqual(Set(r.products.map(\.formula)), ["NaCl", "CO₂", "H₂O"])
    }

    func test_combustion() {
        let m = ReactionLabModel()
        m.place(token("C"), inZone: 1); m.place(token("H"), inZone: 1)
        m.place(token("O"), inZone: 2)
        guard case .success(let r)? = m.result else { return XCTFail("expected success") }
        XCTAssertEqual(r.reactionClass, .combustion)
    }

    func test_not_classified() {
        let m = ReactionLabModel()
        m.place(token("C"), inZone: 1); m.place(token("O"), inZone: 1)   // CO₂
        m.place(token("C"), inZone: 2); m.place(token("H"), inZone: 2)   // CH₄
        guard case .failure(let e)? = m.result else { return XCTFail("expected failure") }
        XCTAssertEqual(e, .unknownReactionClass)
    }

    func test_transition_metal_pending_blocks_result() {
        let m = ReactionLabModel()
        m.place(token("Cu"), inZone: 1); m.place(token("SO₄", poly: true), inZone: 1)
        m.place(token("Zn"), inZone: 2)
        XCTAssertNotNil(m.pendingCharge)      // Cu awaits a charge
        XCTAssertNil(m.result)
    }

    func test_single_displacement_infeasible_with_message() {
        let m = ReactionLabModel()
        m.place(token("Cu"), inZone: 1); m.pickCharge(2)                 // free Cu²⁺
        m.place(token("Zn"), inZone: 2); m.pickCharge(2)
        m.place(token("SO₄", poly: true), inZone: 2)                     // ZnSO₄
        guard case .success(let r)? = m.result else { return XCTFail("expected success") }
        XCTAssertFalse(r.feasible)
        XCTAssertTrue(r.messages.contains { $0.contains("activity series") })
    }

    func test_yield_limiting_excess() {
        let m = ReactionLabModel()
        m.place(token("Na"), inZone: 1); m.place(token("OH", poly: true), inZone: 1)
        m.place(token("H"), inZone: 2);  m.place(token("Cl"), inZone: 2)
        m.setQuantity(ReactantEntry(value: 2, unit: .mole), zone: 1)     // 2 mol NaOH
        m.setQuantity(ReactantEntry(value: 1, unit: .mole), zone: 2)     // 1 mol HCl
        guard case .success(let r)? = m.result else { return XCTFail("expected success") }
        XCTAssertEqual(r.limiting, .b)
        XCTAssertEqual(r.excess.moles, 1.0, accuracy: 1e-6)
        let naclIdx = r.products.firstIndex { $0.formula == "NaCl" }!
        XCTAssertEqual(r.yields[naclIdx].moles, 1.0, accuracy: 1e-6)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/ReactionLabModelTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'ReactionLabModel' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemInteractive/State/ReactionLabModel.swift
import Foundation
import Observation
import ChemCore

@Observable
final class ReactionLabModel {
    let elements: [Element]
    let polyatomicIons: [PolyatomicIon] = PolyatomicIon.polyatomicIons

    private(set) var zone1: [ZoneState] = []
    private(set) var zone2: [ZoneState] = []
    var quantity1: ReactantEntry?
    var quantity2: ReactantEntry?
    private(set) var pendingCharge: PendingCharge?

    struct PendingCharge: Equatable { let zone: Int; let index: Int }

    init() {
        let pt = try! PeriodicTable.load()
        self.elements = pt.elements
    }

    private func tokens(_ zone: Int) -> [ZoneState] { zone == 1 ? zone1 : zone2 }
    private func setTokens(_ v: [ZoneState], _ zone: Int) { if zone == 1 { zone1 = v } else { zone2 = v } }

    func zoneState(for token: TokenTransfer) -> ZoneState? {
        if token.isPolyatomic {
            guard let ion = polyatomicIons.first(where: { $0.symbol == token.symbol }) else { return nil }
            return ZoneState(polyatomic: ion)
        }
        guard let el = elements.first(where: { $0.symbol == token.symbol }) else { return nil }
        return ZoneState(element: el)
    }

    func place(_ token: TokenTransfer, inZone zone: Int) {
        guard pendingCharge == nil, let z = zoneState(for: token) else { return }
        var arr = tokens(zone)
        guard arr.count < 2 else { return }
        arr.append(z)
        setTokens(arr, zone)
        if z.isTransition && z.derivedCharge == nil {
            pendingCharge = PendingCharge(zone: zone, index: arr.count - 1)
        }
    }

    func pickCharge(_ charge: Int) {
        guard let p = pendingCharge else { return }
        var arr = tokens(p.zone)
        if p.index < arr.count {
            arr[p.index].derivedCharge = charge
            arr[p.index].status = .ionized
            setTokens(arr, p.zone)
        }
        pendingCharge = nil
    }

    func removeToken(zone: Int, index: Int) {
        var arr = tokens(zone)
        guard index < arr.count else { return }
        arr.remove(at: index)
        setTokens(arr, zone)
        if pendingCharge?.zone == zone { pendingCharge = nil }
    }

    func setQuantity(_ entry: ReactantEntry?, zone: Int) {
        if zone == 1 { quantity1 = entry } else { quantity2 = entry }
    }

    func reset() {
        zone1 = []; zone2 = []; quantity1 = nil; quantity2 = nil; pendingCharge = nil
    }

    var reactant1: Reactant? { buildReactant(zone1) }
    var reactant2: Reactant? { buildReactant(zone2) }

    private func buildReactant(_ zones: [ZoneState]) -> Reactant? {
        guard pendingCharge == nil else { return nil }
        return SpeciesMapping.buildReactant(zones, elements: elements, ions: polyatomicIons)
    }

    var result: Result<ReactionResult, ReactionError>? {
        guard pendingCharge == nil, let r1 = reactant1, let r2 = reactant2 else { return nil }
        return solveReaction(r1, r2, entry1: quantity1, entry2: quantity2) { [elements] sym in
            elements.first { $0.symbol == sym }?.atomicMass
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/ReactionLabModelTests 2>&1 | tail -20`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/State/ReactionLabModel.swift ChemInteractiveTests/ReactionLabModelTests.swift
git commit -m "feat(app): add ReactionLabModel driving solveReaction"
```

---

### Task 4: ReactionLedgerFormat (pure result formatting)

**Files:**
- Create: `ChemInteractive/Theme/ReactionLedgerFormat.swift`
- Test: `ChemInteractiveTests/ReactionLedgerFormatTests.swift`

**Interfaces:**
- Consumes: ChemCore `ReactionResult`, `ReactionError`, `ReactionClass`, `BalancedTerm`.
- Produces: `enum LedgerOutcome: Equatable { case reaction(ReactionResult); case noReaction(String); case notClassified(String); case cannotBalance(String) }`; `enum ReactionLedgerFormat` with `outcome(_:) -> LedgerOutcome?`, `classLabel(_:) -> String`, `equation(_:) -> String`, `productLines(_:) -> [String]`, `footer(_:) -> String`, `notClassifiedNudge: String`.

- [ ] **Step 1: Write the failing test**

```swift
// ChemInteractiveTests/ReactionLedgerFormatTests.swift
import XCTest
import ChemCore
@testable import ChemInteractive

final class ReactionLedgerFormatTests: XCTestCase {
    private func solved(_ z1: [(String, Bool)], _ z2: [(String, Bool)],
                        q1: ReactantEntry? = nil, q2: ReactantEntry? = nil,
                        picks: [Int] = []) -> Result<ReactionResult, ReactionError>? {
        let m = ReactionLabModel()
        for (s, p) in z1 { m.place(TokenTransfer(symbol: s, isPolyatomic: p), inZone: 1) }
        for (s, p) in z2 { m.place(TokenTransfer(symbol: s, isPolyatomic: p), inZone: 2) }
        for c in picks { m.pickCharge(c) }
        if let q1 { m.setQuantity(q1, zone: 1) }
        if let q2 { m.setQuantity(q2, zone: 2) }
        return m.result
    }

    func test_classLabel() {
        XCTAssertEqual(ReactionLedgerFormat.classLabel(.doubleDisplacement), "Double displacement")
        XCTAssertEqual(ReactionLedgerFormat.classLabel(.combustion), "Combustion")
    }

    func test_equation_with_coefficients() {
        let res = solved([("H", false), ("Cl", false)], [("Na", false), ("CO₃", true)])!
        guard case .success(let r) = res else { return XCTFail() }
        XCTAssertEqual(ReactionLedgerFormat.equation(r), "2HCl + Na₂CO₃ → 2NaCl + CO₂ + H₂O")
    }

    func test_productLines_and_footer() {
        let res = solved([("Na", false), ("OH", true)], [("H", false), ("Cl", false)],
                         q1: ReactantEntry(value: 2, unit: .mole),
                         q2: ReactantEntry(value: 1, unit: .mole))!
        guard case .success(let r) = res else { return XCTFail() }
        let lines = ReactionLedgerFormat.productLines(r)
        XCTAssertTrue(lines.contains { $0.hasPrefix("1 NaCl — 1.00 mol") })
        XCTAssertTrue(ReactionLedgerFormat.footer(r).contains("limiting: HCl"))
        XCTAssertTrue(ReactionLedgerFormat.footer(r).contains("NaOH excess 1.00 mol"))
    }

    func test_outcome_noReaction() {
        let res = solved([("Cu", false)], [("Zn", false), ("SO₄", true)], picks: [2, 2])!
        guard case .noReaction(let msg)? = ReactionLedgerFormat.outcome(res) else { return XCTFail() }
        XCTAssertTrue(msg.contains("activity series"))
    }

    func test_outcome_notClassified() {
        let res = solved([("C", false), ("O", false)], [("C", false), ("H", false)])!
        guard case .notClassified? = ReactionLedgerFormat.outcome(res) else { return XCTFail() }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/ReactionLedgerFormatTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'ReactionLedgerFormat' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// ChemInteractive/Theme/ReactionLedgerFormat.swift
import ChemCore

enum LedgerOutcome: Equatable {
    case reaction(ReactionResult)
    case noReaction(String)
    case notClassified(String)
    case cannotBalance(String)
}

enum ReactionLedgerFormat {
    static let notClassifiedNudge =
        "These two don’t form a reaction this lab can predict. Try an acid + base, a metal + salt, or a fuel + O₂."

    static func outcome(_ result: Result<ReactionResult, ReactionError>?) -> LedgerOutcome? {
        guard let result else { return nil }
        switch result {
        case .success(let r):
            return r.feasible ? .reaction(r) : .noReaction(r.messages.first ?? "No reaction occurs.")
        case .failure(let e):
            switch e {
            case .unknownReactionClass, .noProducts: return .notClassified(notClassifiedNudge)
            case .unbalanceable, .missingAtomicMass: return .cannotBalance("This reaction can’t be balanced here.")
            }
        }
    }

    static func classLabel(_ c: ReactionClass) -> String {
        switch c {
        case .synthesis: return "Synthesis"
        case .doubleDisplacement: return "Double displacement"
        case .singleDisplacement: return "Single displacement"
        case .combustion: return "Combustion"
        case .none: return "Not classified"
        }
    }

    static func equation(_ r: ReactionResult) -> String {
        let lhs = r.reactants.map(term).joined(separator: " + ")
        let rhs = r.products.map(term).joined(separator: " + ")
        return "\(lhs) → \(rhs)"
    }
    private static func term(_ t: BalancedTerm) -> String {
        t.coeff > 1 ? "\(t.coeff)\(t.formula)" : t.formula
    }

    static func productLines(_ r: ReactionResult) -> [String] {
        zip(r.products, r.yields).map { p, y in
            "\(p.coeff) \(p.formula) — \(num(y.moles)) mol · \(num(y.mass)) g"
        }
    }

    static func footer(_ r: ReactionResult) -> String {
        let lim: String
        switch r.limiting {
        case .a:    lim = "limiting: \(r.reactants[0].formula)"
        case .b:    lim = "limiting: \(r.reactants[1].formula)"
        case .both: lim = "stoichiometric — no limiting reactant"
        }
        if r.excess.moles > 0 {
            let exFormula = r.limiting == .a ? r.reactants[1].formula : r.reactants[0].formula
            return "\(lim) · \(exFormula) excess \(num(r.excess.moles)) mol"
        }
        return lim
    }

    private static func num(_ v: Double) -> String { String(format: "%.2f", v) }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/ReactionLedgerFormatTests 2>&1 | tail -20`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Theme/ReactionLedgerFormat.swift ChemInteractiveTests/ReactionLedgerFormatTests.swift
git commit -m "feat(app): add pure ReactionLedgerFormat result formatting"
```

---

### Task 5: ReactantZoneView

**Files:**
- Create: `ChemInteractive/Views/ReactionLab/ReactantZoneView.swift`

**Interfaces:**
- Consumes: `ReactionLabModel` (Task 3, from `@Environment`); existing `TokenTransfer`, `ReactantQuantityPopover(symbol:entry:)`, `TransitionMetalPickerView(zone:onPick:)`, `Theme`.
- Produces: `struct ReactantZoneView: View { let zone: Int }`.

This task has no unit test (pure SwiftUI); the gate is that the app **builds** with the new view compiled into the synchronized target.

- [ ] **Step 1: Verify the app builds BEFORE adding the file (baseline green)**

Run: `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2: Create the view**

```swift
// ChemInteractive/Views/ReactionLab/ReactantZoneView.swift
import SwiftUI
import ChemCore

struct ReactantZoneView: View {
    let zone: Int
    @Environment(ReactionLabModel.self) private var model
    @State private var isTargeted = false
    @State private var showQuantity = false

    private var tokens: [ZoneState] { zone == 1 ? model.zone1 : model.zone2 }
    private var reactant: Reactant? { zone == 1 ? model.reactant1 : model.reactant2 }
    private var quantity: ReactantEntry? { zone == 1 ? model.quantity1 : model.quantity2 }
    private var pendingIndex: Int? { model.pendingCharge?.zone == zone ? model.pendingCharge?.index : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reactant \(zone)").font(.caption2).foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { idx, z in
                    tokenPill(z, index: idx)
                }
                if tokens.count < 2 {
                    Text(tokens.isEmpty ? "drop element / ion" : "＋ add 2nd")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            if let r = reactant {
                Text("\(r.formula) · \(String(format: "%.2f", r.molarMass)) g/mol")
                    .font(.headline).foregroundStyle(.primary)
                quantityButton
            }

            if let i = pendingIndex, i < tokens.count {
                TransitionMetalPickerView(zone: tokens[i]) { model.pickCharge($0) }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(isTargeted ? 0.16 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5])))
        .dropDestination(for: TokenTransfer.self) { items, _ in
            guard let t = items.first else { return false }
            model.place(t, inZone: zone)
            return true
        } isTargeted: { isTargeted = $0 }
    }

    private func tokenPill(_ z: ZoneState, index: Int) -> some View {
        Text(z.symbol)
            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill(z.isPolyatomic ? Color.blue : Color.green))
            .overlay(alignment: .topTrailing) {
                Button {
                    model.removeToken(zone: zone, index: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12)).foregroundStyle(.red)
                }
                .offset(x: 5, y: -5)
            }
    }

    private var quantityButton: some View {
        Button { showQuantity = true } label: {
            Text(quantity.map { "\(String(format: "%.2f", $0.value)) \($0.unit == .mole ? "mol" : "g") ▾" } ?? "set amount ▾")
                .font(.caption).padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(.black.opacity(0.4))).foregroundStyle(.white)
        }
        .popover(isPresented: $showQuantity) {
            ReactantQuantityPopover(
                symbol: reactant?.formula ?? "",
                entry: Binding(get: { quantity }, set: { model.setQuantity($0, zone: zone) })
            )
        }
    }
}
```

- [ ] **Step 3: Verify the app still builds with the new view**

Run: `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add ChemInteractive/Views/ReactionLab/ReactantZoneView.swift
git commit -m "feat(app): add ReactantZoneView build zone"
```

---

### Task 6: Result ledger views

**Files:**
- Create: `ChemInteractive/Views/ReactionLab/ReactionTypeBadge.swift`
- Create: `ChemInteractive/Views/ReactionLab/NoReactionView.swift`
- Create: `ChemInteractive/Views/ReactionLab/ReactionLedgerView.swift`

**Interfaces:**
- Consumes: `LedgerOutcome`, `ReactionLedgerFormat` (Task 4); `Theme`.
- Produces: `struct ReactionTypeBadge: View { let text: String }`; `struct NoReactionView: View { enum Tone { case warn, neutral }; let badge: String; let message: String; let tone: Tone }`; `struct ReactionLedgerView: View { let outcome: LedgerOutcome }`.

Pure SwiftUI; gate is the app build.

- [ ] **Step 1: Create the three views**

```swift
// ChemInteractive/Views/ReactionLab/ReactionTypeBadge.swift
import SwiftUI

struct ReactionTypeBadge: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(Capsule().fill(Theme.accent.opacity(0.3)))
            .foregroundStyle(.white)
    }
}
```

```swift
// ChemInteractive/Views/ReactionLab/NoReactionView.swift
import SwiftUI

struct NoReactionView: View {
    enum Tone { case warn, neutral }
    let badge: String
    let message: String
    let tone: Tone

    var body: some View {
        VStack(spacing: 8) {
            ReactionTypeBadge(text: badge)
            Text(message)
                .font(.footnote).multilineTextAlignment(.center)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill((tone == .warn ? Color.red : Color.gray).opacity(0.15)))
        }
        .frame(maxWidth: .infinity)
    }
}
```

```swift
// ChemInteractive/Views/ReactionLab/ReactionLedgerView.swift
import SwiftUI
import ChemCore

struct ReactionLedgerView: View {
    let outcome: LedgerOutcome

    var body: some View {
        switch outcome {
        case .reaction(let r):
            VStack(spacing: 8) {
                ReactionTypeBadge(text: ReactionLedgerFormat.classLabel(r.reactionClass))
                Text(ReactionLedgerFormat.equation(r))
                    .font(.system(size: 16, weight: .bold))
                    .multilineTextAlignment(.center).foregroundStyle(.white)
                ForEach(ReactionLedgerFormat.productLines(r), id: \.self) { line in
                    Text(line).font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.5)))
                }
                Text(ReactionLedgerFormat.footer(r)).font(.caption2).foregroundStyle(.secondary)
            }
        case .noReaction(let msg):
            NoReactionView(badge: "No reaction", message: msg, tone: .warn)
        case .notClassified(let msg):
            NoReactionView(badge: "Not classified", message: msg, tone: .neutral)
        case .cannotBalance(let msg):
            NoReactionView(badge: "Can’t balance", message: msg, tone: .neutral)
        }
    }
}
```

- [ ] **Step 2: Verify the app builds**

Run: `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/ReactionLab/ReactionTypeBadge.swift ChemInteractive/Views/ReactionLab/NoReactionView.swift ChemInteractive/Views/ReactionLab/ReactionLedgerView.swift
git commit -m "feat(app): add reaction result ledger views"
```

---

### Task 7: ReactionLabView + mode switcher + app wiring

**Files:**
- Create: `ChemInteractive/Views/ReactionLab/ReactionLabView.swift`
- Create: `ChemInteractive/Views/BondingCanvas.swift`
- Create: `ChemInteractive/Views/RootModeView.swift`
- Delete: `ChemInteractive/Views/ChemCanvasView.swift`
- Modify: `ChemInteractive/ChemInteractiveApp.swift`

**Interfaces:**
- Consumes: `ReactantZoneView` (Task 5), `ReactionLedgerView` + `ReactionLedgerFormat` (Tasks 4/6), `ReactionLabModel` (Task 3); existing `DropZoneView`, `BridgeView`, `ElementTrayView`, `ExplanationModalView`, `CanvasModel`, `SoundFX`, `ReactionBurst`, `Theme`.
- Produces: `struct ReactionLabView: View`; `struct BondingCanvas: View`; `struct RootModeView: View`.

Integration task; gate is a full app build + the entire `ChemInteractiveTests` suite passing (no regressions), plus the ChemCore suite.

- [ ] **Step 1: Create ReactionLabView (layout B + live fire FX)**

```swift
// ChemInteractive/Views/ReactionLab/ReactionLabView.swift
import SwiftUI
import ChemCore

struct ReactionLabView: View {
    @Environment(ReactionLabModel.self) private var model
    @State private var pulse = false

    private var fireKey: String {
        "\(model.quantity1?.unit.rawValue ?? "-")|\(model.quantity2?.unit.rawValue ?? "-")"
    }
    private var bothSet: Bool { model.quantity1 != nil && model.quantity2 != nil }

    var body: some View {
        VStack(spacing: 12) {
            ReactantZoneView(zone: 1)
            Text("+").font(.title3).foregroundStyle(.secondary)
            ReactantZoneView(zone: 2)
            Text("↓").font(.title2).foregroundStyle(Theme.accent.opacity(0.7))

            if let outcome = ReactionLedgerFormat.outcome(model.result) {
                ReactionLedgerView(outcome: outcome)
                    .scaleEffect(pulse ? 1.05 : 1)
                    .overlay { if pulse { ReactionBurst() } }
            } else {
                Text("Add a reactant to each side.")
                    .font(.footnote).foregroundStyle(.secondary).padding()
            }

            Button { model.reset() } label: {
                Label("Reset", systemImage: "arrow.counterclockwise").font(.caption)
            }
        }
        .onChange(of: fireKey) { _, _ in if bothSet { fire() } }
    }

    private func fire() {
        SoundFX.reaction()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.3)) { pulse = false }
        }
    }
}
```

- [ ] **Step 2: Extract BondingCanvas from ChemCanvasView**

```swift
// ChemInteractive/Views/BondingCanvas.swift
import SwiftUI
import ChemCore

/// The bonding-mode canvas (flasks + bridge), extracted from the former
/// ChemCanvasView so RootModeView can host the shared tray above it.
struct BondingCanvas: View {
    @Environment(CanvasModel.self) private var model

    var body: some View {
        if model.state.canvasPhase == .stoichiometry {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    DropZoneView(slot: .a).frame(maxWidth: .infinity)
                    DropZoneView(slot: .b).frame(maxWidth: .infinity)
                }
                BridgeView().frame(maxWidth: .infinity)
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                DropZoneView(slot: .a).frame(maxWidth: .infinity)
                BridgeView().frame(maxWidth: .infinity)
                DropZoneView(slot: .b).frame(maxWidth: .infinity)
            }
        }
    }
}
```

- [ ] **Step 3: Create RootModeView (segmented switcher + shared tray)**

```swift
// ChemInteractive/Views/RootModeView.swift
import SwiftUI
import ChemCore

struct RootModeView: View {
    enum AppMode: String, CaseIterable { case bonding = "Bonding", reactionLab = "Reaction Lab" }

    let bondingModel: CanvasModel
    @State private var reactionModel = ReactionLabModel()
    @State private var mode: AppMode = .bonding

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(AppMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12).padding(.top, 8)

                // Shared periodic tray. Its drag payload (TokenTransfer) is
                // mode-agnostic; it stays bound to the bonding model as the catalog.
                ElementTrayView()
                    .environment(bondingModel)
                    .frame(height: geo.size.height * 0.42)

                ScrollView {
                    Group {
                        switch mode {
                        case .bonding:
                            BondingCanvas().environment(bondingModel)
                        case .reactionLab:
                            ReactionLabView().environment(reactionModel)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay { if mode == .bonding { ExplanationModalView().environment(bondingModel) } }
        .onChange(of: mode) { _, _ in bondingModel.clearSelection() }
    }
}
```

- [ ] **Step 4: Delete ChemCanvasView and rewire the app**

Delete the file:

```bash
git rm ChemInteractive/Views/ChemCanvasView.swift
```

Replace `ChemInteractive/ChemInteractiveApp.swift` with:

```swift
import SwiftUI

@main
struct ChemInteractiveApp: App {
    @State private var model = CanvasModel()

    var body: some Scene {
        WindowGroup {
            RootModeView(bondingModel: model)
                .preferredColorScheme(.dark)
                .task {
                    #if DEBUG
                    if let preview = CanvasModel.debugPreviewArgument(ProcessInfo.processInfo.arguments) {
                        model.debugSeed(preview)
                    }
                    #endif
                }
        }
    }
}
```

- [ ] **Step 5: Build the app**

Run: `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -8`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Run the FULL app test suite (no regressions)**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -12`
Expected: all `ChemInteractiveTests` pass — the 68 pre-existing plus the new `SpeciesMappingTests`, `ReactionLabModelTests`, `ReactionLedgerFormatTests`.

- [ ] **Step 7: Run the ChemCore suite**

Run: `cd ChemCore && swift test 2>&1 | grep "Executed" | tail -1`
Expected: `Executed 147 tests, with 0 failures` (140 prior + 7 from Task 1).

- [ ] **Step 8: Commit**

```bash
git add ChemInteractive/Views/ReactionLab/ReactionLabView.swift ChemInteractive/Views/BondingCanvas.swift ChemInteractive/Views/RootModeView.swift ChemInteractive/ChemInteractiveApp.swift
git commit -m "feat(app): add Reaction Lab mode with segmented switcher"
```

---

## Self-Review Notes (addressed)

- **Spec coverage:** mode switcher + shared tray (Task 7), vertical ledger layout B (Tasks 6–7), zone with 1–2 tokens / tap-× / live formula / in-zone quantity / diatomic (Task 5 + engine's `makeReactant` diatomic handling), live compute + sound/burst (Task 7), result states incl. no-reaction + not-classified (Tasks 4/6), transition-metal charge picker reuse (Tasks 3/5), main-group auto charge + pair-aware acid/covalent rule (Task 2), `PolyatomicIon.composition` (Task 1). All spec test cases mapped to `ReactionLabModelTests`/`ReactionLedgerFormatTests`.
- **Charge-rule clarification** (from the spec update): implemented in Task 2 `isIonicPair`/`ionicCharge`, tested via `test_acid_hcl_is_ionic` + `test_methane_is_covalent`.
- **Type consistency:** `ReactionLabModel`, `SpeciesMapping`, `LedgerOutcome`, `ReactionLedgerFormat`, `ReactantZoneView`, `ReactionLedgerView`, `RootModeView`, `BondingCanvas` names/signatures consistent across tasks. `ReactantQuantityPopover(symbol:entry:)` and `TransitionMetalPickerView(zone:onPick:)` match existing app APIs.
- **v1 scope note surfaced:** tap-to-place is bonding-only; Reaction Lab uses drag-and-drop. Documented in Global Constraints.
- **Xcode integration:** synchronized folders mean no `.pbxproj` edits; `xcodebuild` is the authoritative gate over SourceKit noise.
