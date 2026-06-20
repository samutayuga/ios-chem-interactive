# ChemInteractive — Result Diagrams Implementation Plan (Plan 3 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the three Plan-2 stub diagrams with the real animated SwiftUI result diagrams — ionic crossover + Lewis electron-transfer, covalent Lewis structure, and the metallic electron-sea — completing the app.

**Architecture:** A pure, unit-tested geometry layer (`LewisLayout.swift`) computes every chemistry-meaningful count and position from `ChemCore` values; four composed SwiftUI views render them (atoms as `Circle`+`Text`, dots as small `Circle`s, bonds as `Path`s), using `withAnimation` for the discrete ionic crossover and `TimelineView(.animation)`+`Canvas` for the continuous metallic electron drift. `BridgeView` routes the result phases to these views; a `DEBUG`-only launch argument seeds each diagram state for screenshots. The app adds no chemistry logic — all bonding math stays in `ChemCore`.

**Tech Stack:** Swift 5 language mode, SwiftUI (iOS 17: `TimelineView`, `Canvas`, `withAnimation`, `.task`), XCTest, `xcodebuild`. Consumes the existing `ChemCore` package and the Plan-2 app helpers.

## Global Constraints

- **Deployment / language:** iOS 17.0, Swift 5 language mode, portrait iPhone — unchanged from Plan 2.
- **No chemistry logic in the app.** All bonding math comes from `ChemCore`: `gcd(_:_:)`, `calcStoich(veA:veB:) -> (nA:Int, nB:Int, bondOrder:Int)`, `metallicElectronCount(veA:veB:poolSize:) -> Int`, `iupacFirst(_:_:) -> Bool`. New app code is presentation geometry + rendering only.
- **Animation is behavioral/approximate, not pixel-exact.** Match the reference's information and feel; exact timing/easing/coordinates are approximations.
- **`ChemCore` is consumed as-is** — do not modify the package.
- **File-system-synchronized targets:** new `.swift` files under `ChemInteractive/` and `ChemInteractiveTests/` are auto-discovered; never edit `project.pbxproj`.
- **Type-ambiguity gotcha:** if the compiler reports a bare type name (`ZoneState`, `Category`, `CanvasState`, etc.) as "ambiguous for type lookup" against an iOS SDK type, qualify it `ChemCore.<Type>`.
- **Transient SourceKit warnings** ("No such module 'ChemCore'/'XCTest'") after adding files are IDE-indexing noise — the authoritative gate is `xcodebuild`.
- **Reference source** (fidelity, not to be shipped): `~/Developer/codews/chem-interactive/src/bridge/{CrossoverAnimator,BondingDiagram,CovalentView,MetallicView}.tsx`.
- **Existing app helpers available** (Plan 2): `Theme` (`.bg/.cation/.anion/.muted/.surface`, `Color(hex:)`), `subscriptGlyphs(_:)`, `ionicFormula(cationSymbol:cationCharge:anionSymbol:anionCharge:anionIsPolyatomic:)`, `superscript(_:)`, `CanvasModel` (`@Observable`, `state`, `place(_:in:)`, `send(_:)`), `TokenTransfer(symbol:isPolyatomic:)`.
- **`ChemCore.ZoneState`** fields: `symbol`, `elementClass: ElementClass` (`.metal/.nonMetal/.metalloid`), `isPolyatomic: Bool`, `isTransition: Bool`, `valenceElectrons: Int`, `oxidationStates: [Int]`, `derivedCharge: Int?`, `wrongCount: Int`, `status: ZoneStatus`. Full init: `ZoneState(symbol:elementClass:isPolyatomic:isTransition:valenceElectrons:oxidationStates:derivedCharge:wrongCount:status:)` (trailing args default).
- Commit after every task. Commit prefixes: `feat:`, `fix:`, `chore:`, `test:` (no scopes).

## File Structure

```
ChemInteractive/
├── Diagrams/LewisLayout.swift              # NEW (Tasks 1–2) — pure geometry/counts (tested)
├── Views/Bridge/
│   ├── ResetButton.swift                   # NEW (Task 3) — shared Reset button
│   ├── CrossoverAnimatorView.swift         # NEW (Task 4)
│   ├── BondingDiagramView.swift            # NEW (Task 5)
│   ├── CovalentLewisView.swift             # NEW (Task 6)
│   ├── MetallicSeaView.swift               # NEW (Task 7)
│   ├── ExplanationModalView.swift          # MODIFY (Task 3) — use shared ionicPair
│   ├── BridgeView.swift                    # MODIFY (Task 8) — route to real diagrams
│   └── DiagramPlaceholders.swift           # DELETE (Task 8)
├── State/CanvasModel.swift                 # MODIFY (Task 9) — DEBUG seed seam
└── ChemInteractiveApp.swift                # MODIFY (Task 9) — read DEBUG launch arg
ChemInteractiveTests/
└── LewisLayoutTests.swift                  # NEW (Tasks 1–2)
```

---

### Task 1: LewisLayout — ionic geometry helpers (shared ionicPair, crossover, Lewis transfer, dot ring)

**Files:**
- Create: `ChemInteractive/Diagrams/LewisLayout.swift`
- Test: `ChemInteractiveTests/LewisLayoutTests.swift`

**Interfaces:**
- Consumes: `ChemCore` (`ZoneState`, `ElementClass`, `gcd`).
- Produces (internal, app-wide):
  - `func ionicPair(_ a: ZoneState, _ b: ZoneState) -> (cation: ZoneState, anion: ZoneState)`
  - `enum CrossoverStep { case isolate, crisscross, brackets, gcdReduce, done }`
  - `struct CrossoverModel: Equatable { cationSymbol, anionSymbol: String; cationSub, anionSub, gcdValue: Int; showBrackets, showGcd: Bool; steps: [CrossoverStep] }`
  - `func crossoverModel(cation: ZoneState, anion: ZoneState) -> CrossoverModel`
  - `struct LewisTransfer: Equatable { cCount, aCount, eMoved, anionAfterDots: Int }`
  - `func lewisTransfer(cation: ZoneState, anion: ZoneState) -> LewisTransfer`
  - `func dotPositions(_ n: Int) -> [(dx: CGFloat, dy: CGFloat)]`

- [ ] **Step 1: Write the failing test `ChemInteractiveTests/LewisLayoutTests.swift`**

```swift
import XCTest
import ChemCore
@testable import ChemInteractive

final class LewisLayoutTests: XCTestCase {
    // Helpers to build ionized cation/anion zones.
    private func ion(_ symbol: String, _ cls: ElementClass, ve: Int, charge: Int, poly: Bool = false) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: cls, isPolyatomic: poly, isTransition: false,
                  valenceElectrons: ve, oxidationStates: [charge], derivedCharge: charge, status: .ionized)
    }

    func test_ionicPair_byChargeSign() {
        let na = ion("Na", .metal, ve: 1, charge: 1)
        let cl = ion("Cl", .nonMetal, ve: 7, charge: -1)
        let p = ionicPair(cl, na)            // pass anion first
        XCTAssertEqual(p.cation.symbol, "Na")
        XCTAssertEqual(p.anion.symbol, "Cl")
    }

    func test_crossover_NaCl_noBracketsNoGcd() {
        let m = crossoverModel(cation: ion("Na", .metal, ve: 1, charge: 1),
                               anion: ion("Cl", .nonMetal, ve: 7, charge: -1))
        XCTAssertEqual(m.cationSub, 1)
        XCTAssertEqual(m.anionSub, 1)
        XCTAssertFalse(m.showBrackets)
        XCTAssertFalse(m.showGcd)
        XCTAssertEqual(m.steps, [.isolate, .crisscross, .done])
    }

    func test_crossover_MgCl2_AndAl2O3_subscripts() {
        let mg = crossoverModel(cation: ion("Mg", .metal, ve: 2, charge: 2),
                                anion: ion("Cl", .nonMetal, ve: 7, charge: -1))
        XCTAssertEqual([mg.cationSub, mg.anionSub], [1, 2])
        let al = crossoverModel(cation: ion("Al", .metal, ve: 3, charge: 3),
                                anion: ion("O", .nonMetal, ve: 6, charge: -2))
        XCTAssertEqual([al.cationSub, al.anionSub], [2, 3])
    }

    func test_crossover_CaCO3_showsGcd() {
        let m = crossoverModel(cation: ion("Ca", .metal, ve: 2, charge: 2),
                               anion: ion("CO₃", .nonMetal, ve: 0, charge: -2, poly: true))
        XCTAssertEqual([m.cationSub, m.anionSub], [1, 1])
        XCTAssertTrue(m.showGcd)
        XCTAssertFalse(m.showBrackets)
        XCTAssertEqual(m.steps, [.isolate, .crisscross, .gcdReduce, .done])
    }

    func test_crossover_MgOH2_showsBrackets() {
        let m = crossoverModel(cation: ion("Mg", .metal, ve: 2, charge: 2),
                               anion: ion("OH", .nonMetal, ve: 0, charge: -1, poly: true))
        XCTAssertEqual([m.cationSub, m.anionSub], [1, 2])
        XCTAssertTrue(m.showBrackets)
        XCTAssertFalse(m.showGcd)
        XCTAssertEqual(m.steps, [.isolate, .crisscross, .brackets, .done])
    }

    func test_lewisTransfer_NaCl_andAl2O3() {
        let nacl = lewisTransfer(cation: ion("Na", .metal, ve: 1, charge: 1),
                                 anion: ion("Cl", .nonMetal, ve: 7, charge: -1))
        XCTAssertEqual(nacl.cCount, 1)
        XCTAssertEqual(nacl.aCount, 1)
        XCTAssertEqual(nacl.eMoved, 1)
        XCTAssertEqual(nacl.anionAfterDots, 8)        // min(7 + 1, 8)
        let al2o3 = lewisTransfer(cation: ion("Al", .metal, ve: 3, charge: 3),
                                  anion: ion("O", .nonMetal, ve: 6, charge: -2))
        XCTAssertEqual(al2o3.cCount, 2)
        XCTAssertEqual(al2o3.aCount, 3)
        XCTAssertEqual(al2o3.eMoved, 3)
        XCTAssertEqual(al2o3.anionAfterDots, 8)       // min(6 + 2, 8)
    }

    func test_dotPositions_count() {
        XCTAssertEqual(dotPositions(3).count, 3)
        XCTAssertEqual(dotPositions(10).count, 8)     // capped at 8
        XCTAssertEqual(dotPositions(0).count, 0)
        XCTAssertEqual(dotPositions(1).first?.dx, 22) // first slot = right
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/LewisLayoutTests 2>&1 | tail -20`
Expected: FAIL — `ionicPair`/`crossoverModel`/`lewisTransfer`/`dotPositions` not found.

- [ ] **Step 3: Create `ChemInteractive/Diagrams/LewisLayout.swift`**

```swift
import CoreGraphics
import Foundation
import ChemCore

// MARK: - Cation/anion ordering (shared by ionic diagrams + ExplanationModalView)

/// Prefer derivedCharge sign (positive = cation); otherwise Metal/Metalloid is the cation.
func ionicPair(_ a: ZoneState, _ b: ZoneState) -> (cation: ZoneState, anion: ZoneState) {
    if let ca = a.derivedCharge, let cb = b.derivedCharge, ca != 0 || cb != 0 {
        return ca > 0 ? (a, b) : (b, a)
    }
    let aCation = a.elementClass == .metal || a.elementClass == .metalloid
    return aCation ? (a, b) : (b, a)
}

// MARK: - Crossover model (ionic animation)

enum CrossoverStep: Equatable { case isolate, crisscross, brackets, gcdReduce, done }

struct CrossoverModel: Equatable {
    let cationSymbol: String
    let anionSymbol: String
    let cationSub: Int       // gcd-reduced cation subscript
    let anionSub: Int        // gcd-reduced anion subscript
    let gcdValue: Int
    let showBrackets: Bool
    let showGcd: Bool
    let steps: [CrossoverStep]
}

/// Subscripts cross over (each charge → the other ion's subscript), reduced by their gcd.
func crossoverModel(cation: ZoneState, anion: ZoneState) -> CrossoverModel {
    let cc = abs(cation.derivedCharge ?? 0)
    let ac = abs(anion.derivedCharge ?? 0)
    let g = max(1, gcd(ac, cc))
    let cationSub = ac / g
    let anionSub = cc / g
    let showBrackets = anion.isPolyatomic && anionSub > 1
    let showGcd = g > 1
    var steps: [CrossoverStep] = [.isolate, .crisscross]
    if showBrackets { steps.append(.brackets) }
    if showGcd { steps.append(.gcdReduce) }
    steps.append(.done)
    return CrossoverModel(cationSymbol: cation.symbol, anionSymbol: anion.symbol,
                          cationSub: cationSub, anionSub: anionSub, gcdValue: g,
                          showBrackets: showBrackets, showGcd: showGcd, steps: steps)
}

// MARK: - Lewis electron-transfer model (ionic, both regular elements)

struct LewisTransfer: Equatable {
    let cCount: Int          // number of cations in the formula unit
    let aCount: Int          // number of anions
    let eMoved: Int          // electrons transferred per cation
    let anionAfterDots: Int  // anion's outer dots after gaining electrons (capped at 8)
}

func lewisTransfer(cation: ZoneState, anion: ZoneState) -> LewisTransfer {
    let cc = cation.derivedCharge ?? 0
    let ac = anion.derivedCharge ?? 0
    let g = max(1, gcd(abs(cc), abs(ac)))
    return LewisTransfer(cCount: abs(ac) / g, aCount: abs(cc) / g, eMoved: abs(cc),
                         anionAfterDots: min(anion.valenceElectrons + abs(ac), 8))
}

// MARK: - Electron dot ring

private let dotRing: [(dx: CGFloat, dy: CGFloat)] = [
    (22, 0), (0, -22), (-22, 0), (0, 22),     // right, top, left, bottom
    (22, -8), (8, -22), (-22, -8), (-8, 22),  // then paired
]

/// First `min(n, 8)` Lewis-dot offsets around an atom centre.
func dotPositions(_ n: Int) -> [(dx: CGFloat, dy: CGFloat)] {
    Array(dotRing.prefix(max(0, min(n, 8))))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/LewisLayoutTests 2>&1 | tail -20`
Expected: `TEST SUCCEEDED` (7 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Diagrams/LewisLayout.swift ChemInteractiveTests/LewisLayoutTests.swift
git commit -m "feat: add ionic Lewis-layout geometry helpers"
```

---

### Task 2: LewisLayout — covalent & metallic geometry helpers

**Files:**
- Modify: `ChemInteractive/Diagrams/LewisLayout.swift` (append)
- Modify: `ChemInteractiveTests/LewisLayoutTests.swift` (append a test class)

**Interfaces:**
- Consumes: `ChemCore` (`ZoneState`, `calcStoich`, `metallicElectronCount`).
- Produces:
  - `struct CovalentLayout: Equatable { centralIsA: Bool; nPeripheral, bondOrder, centralLone, peripheralLone: Int }`
  - `func covalentLayout(slotA: ZoneState, slotB: ZoneState) -> CovalentLayout`
  - `func peripheralPositions(_ n: Int, center: CGPoint, distance: CGFloat) -> [CGPoint]`
  - `func lonePairAngles(bondAngles: [Double], count: Int) -> [Double]`
  - `let metallicIonIndexPattern: [Int]`
  - `func metallicElectronsShown(slotA: ZoneState, slotB: ZoneState) -> Int`

- [ ] **Step 1: Append the failing tests to `ChemInteractiveTests/LewisLayoutTests.swift`**

```swift
final class CovalentMetallicLayoutTests: XCTestCase {
    private func atom(_ symbol: String, ve: Int) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                  valenceElectrons: ve, oxidationStates: [], derivedCharge: nil, status: .neutral)
    }
    private func metal(_ symbol: String, ve: Int) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: .metal, isPolyatomic: false, isTransition: false,
                  valenceElectrons: ve, oxidationStates: [], derivedCharge: nil, status: .neutral)
    }

    func test_covalent_CO2() {
        let l = covalentLayout(slotA: atom("C", ve: 4), slotB: atom("O", ve: 6))
        XCTAssertTrue(l.centralIsA)          // C is central
        XCTAssertEqual(l.nPeripheral, 2)
        XCTAssertEqual(l.bondOrder, 2)
        XCTAssertEqual(l.centralLone, 0)
        XCTAssertEqual(l.peripheralLone, 2)
    }

    func test_covalent_H2O() {
        let l = covalentLayout(slotA: atom("H", ve: 1), slotB: atom("O", ve: 6))
        XCTAssertFalse(l.centralIsA)         // O is central
        XCTAssertEqual(l.nPeripheral, 2)     // 2 H
        XCTAssertEqual(l.bondOrder, 1)
        XCTAssertEqual(l.centralLone, 2)
        XCTAssertEqual(l.peripheralLone, 0)
    }

    func test_covalent_N2_triple() {
        let l = covalentLayout(slotA: atom("N", ve: 5), slotB: atom("N", ve: 5))
        XCTAssertEqual(l.nPeripheral, 1)
        XCTAssertEqual(l.bondOrder, 3)
        XCTAssertEqual(l.centralLone, 1)
        XCTAssertEqual(l.peripheralLone, 1)
    }

    func test_peripheralPositions_counts() {
        let c = CGPoint(x: 100, y: 100)
        XCTAssertEqual(peripheralPositions(1, center: c, distance: 50).count, 1)
        XCTAssertEqual(peripheralPositions(2, center: c, distance: 50).count, 2)
        XCTAssertEqual(peripheralPositions(3, center: c, distance: 50).count, 3)
        XCTAssertEqual(peripheralPositions(4, center: c, distance: 50).count, 4)
        XCTAssertEqual(peripheralPositions(5, center: c, distance: 50).count, 1) // 5+ simplified
    }

    func test_lonePairAngles_avoidsBond() {
        let angles = lonePairAngles(bondAngles: [0], count: 2)
        XCTAssertEqual(angles.count, 2)
        // None coincides with the bond direction (0); the farthest slot (π) is chosen.
        XCTAssertFalse(angles.contains { abs($0) < 0.01 })
        XCTAssertTrue(angles.contains { abs($0 - Double.pi) < 0.01 })
    }

    func test_metallic_electronCount_andPattern() {
        XCTAssertEqual(metallicElectronsShown(slotA: metal("Na", ve: 1), slotB: metal("Na", ve: 1)), 6)
        XCTAssertEqual(metallicElectronsShown(slotA: metal("Al", ve: 3), slotB: metal("Al", ve: 3)), 12) // capped
        XCTAssertEqual(metallicIonIndexPattern, [0, 1, 0, 1, 0, 1])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/CovalentMetallicLayoutTests 2>&1 | tail -20`
Expected: FAIL — `covalentLayout`/`peripheralPositions`/`lonePairAngles`/`metallicIonIndexPattern`/`metallicElectronsShown` not found.

- [ ] **Step 3: Append to `ChemInteractive/Diagrams/LewisLayout.swift`**

```swift
// MARK: - Covalent layout

struct CovalentLayout: Equatable {
    let centralIsA: Bool      // is slotA the central atom?
    let nPeripheral: Int
    let bondOrder: Int
    let centralLone: Int      // lone pairs on the central atom
    let peripheralLone: Int   // lone pairs on each peripheral atom
}

func covalentLayout(slotA: ZoneState, slotB: ZoneState) -> CovalentLayout {
    let s = calcStoich(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)
    let centralIsA = s.nA <= s.nB                 // central = the smaller-count atom
    let central = centralIsA ? slotA : slotB
    let peripheral = centralIsA ? slotB : slotA
    let nPeripheral = centralIsA ? s.nB : s.nA
    let centralLone = max(0, (central.valenceElectrons - s.bondOrder * nPeripheral) / 2)
    let peripheralLone = max(0, (peripheral.valenceElectrons - s.bondOrder) / 2)
    return CovalentLayout(centralIsA: centralIsA, nPeripheral: nPeripheral,
                          bondOrder: s.bondOrder, centralLone: centralLone, peripheralLone: peripheralLone)
}

/// Peripheral-atom centres for 1–4 atoms; 5+ collapses to a single atom (view adds an ×N badge).
func peripheralPositions(_ n: Int, center: CGPoint, distance d: CGFloat) -> [CGPoint] {
    switch n {
    case 1:
        return [CGPoint(x: center.x + d, y: center.y)]
    case 2:
        return [CGPoint(x: center.x - d, y: center.y), CGPoint(x: center.x + d, y: center.y)]
    case 3:
        let a = CGFloat.pi / 3
        return [CGPoint(x: center.x - d, y: center.y),
                CGPoint(x: center.x + d * cos(a), y: center.y - d * sin(a)),
                CGPoint(x: center.x + d * cos(a), y: center.y + d * sin(a))]
    case 4:
        return [CGPoint(x: center.x, y: center.y - d), CGPoint(x: center.x + d, y: center.y),
                CGPoint(x: center.x, y: center.y + d), CGPoint(x: center.x - d, y: center.y)]
    default:
        return [CGPoint(x: center.x + d, y: center.y)]
    }
}

/// `count` lone-pair directions chosen from the 8 cardinal/diagonal slots, farthest from all bonds.
func lonePairAngles(bondAngles: [Double], count: Int) -> [Double] {
    guard count > 0 else { return [] }
    let candidates = (0..<8).map { Double($0) * .pi / 4 }
    let scored = candidates.map { a -> (angle: Double, dist: Double) in
        let minDist = bondAngles.reduce(Double.pi) { m, ba in
            let diff = abs((a - ba + 3 * .pi).truncatingRemainder(dividingBy: 2 * .pi) - .pi)
            return Swift.min(m, diff)
        }
        return (a, minDist)
    }
    return scored.sorted { $0.dist > $1.dist }.prefix(count).map { $0.angle }
}

// MARK: - Metallic layout

/// A/B alternation over the 3×2 cation lattice (homonuclear → both indices map to the same symbol).
let metallicIonIndexPattern: [Int] = [0, 1, 0, 1, 0, 1]

/// Delocalised-electron count for the sea (capped at the 12-slot pool), via ChemCore.
func metallicElectronsShown(slotA: ZoneState, slotB: ZoneState) -> Int {
    metallicElectronCount(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/CovalentMetallicLayoutTests 2>&1 | tail -20`
Expected: `TEST SUCCEEDED` (6 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Diagrams/LewisLayout.swift ChemInteractiveTests/LewisLayoutTests.swift
git commit -m "feat: add covalent and metallic layout helpers"
```

---

### Task 3: Refactor ExplanationModalView onto the shared ionicPair

**Files:**
- Modify: `ChemInteractive/Views/Bridge/ExplanationModalView.swift:11-18` (remove its private `ionicPair`)

**Interfaces:**
- Consumes: `ionicPair` (Task 1).
- Produces: nothing new.

Note: the shared `ResetButton` view is **not** created here — it would collide with the file-private `ResetButton` still living in `DiagramPlaceholders.swift` (a `private` and an `internal` top-level type of the same name are an "invalid redeclaration" in Swift, and `DiagramPlaceholders` cannot be deleted until `BridgeView` is rewired off its placeholder structs). `ResetButton.swift` is therefore created in **Task 8**, immediately after `DiagramPlaceholders.swift` is deleted. The diagram views (Tasks 4–7) do not use `ResetButton` — `BridgeView` wraps them with it in Task 8.

`ExplanationModalView`'s `ionicPair` is a struct **method** (not a free function), so it simply shadows the free `ionicPair` until removed — there is no overload ambiguity, and removing it is safe with `DiagramPlaceholders.swift` still present.

- [ ] **Step 1: Remove the private `ionicPair` from `ExplanationModalView.swift`**

Delete these lines (currently `ExplanationModalView.swift:11-18`):

```swift
    // Cation/anion ordering — prefer derivedCharge, else Metal/Metalloid is the cation.
    private func ionicPair(_ a: ZoneState, _ b: ZoneState) -> (cation: ZoneState, anion: ZoneState) {
        if let ca = a.derivedCharge, let cb = b.derivedCharge, ca != 0 || cb != 0 {
            return ca > 0 ? (a, b) : (b, a)
        }
        let aCation = a.elementClass == .metal || a.elementClass == .metalloid
        return aCation ? (a, b) : (b, a)
    }
```

The remaining call sites in that file (`let pair = ionicPair(a, b)`) now resolve to the internal `ionicPair` from `LewisLayout.swift` — identical behavior.

- [ ] **Step 2: Verify it compiles and all tests still pass**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -12`
Expected: `TEST SUCCEEDED` (full suite still green; `ExplanationModalView` now uses the shared helper).

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Bridge/ExplanationModalView.swift
git commit -m "refactor: use shared ionicPair in ExplanationModalView"
```

---

### Task 4: CrossoverAnimatorView — the ionic 4-step crossover

**Files:**
- Create: `ChemInteractive/Views/Bridge/CrossoverAnimatorView.swift`

**Interfaces:**
- Consumes: `crossoverModel`, `CrossoverStep` (Task 1), `Theme`, `Color(hex:)`, `subscriptGlyphs` (Plan 2), `ChemCore.ZoneState`.
- Produces: `struct CrossoverAnimatorView: View` — `init(cation: ZoneState, anion: ZoneState, onComplete: @escaping () -> Void)`. Animates the reduced formula appearing step-by-step and calls `onComplete()` exactly once at the end.

Verified by compilation (no unit test). The `#Preview` renders it for inspection.

- [ ] **Step 1: Create `ChemInteractive/Views/Bridge/CrossoverAnimatorView.swift`**

```swift
import SwiftUI
import ChemCore

struct CrossoverAnimatorView: View {
    let cation: ZoneState
    let anion: ZoneState
    let onComplete: () -> Void

    @State private var stepIndex = 0

    private var model: CrossoverModel { crossoverModel(cation: cation, anion: anion) }

    /// Has the animation advanced to/past the frame for `step` (monotonic).
    private func reached(_ step: CrossoverStep) -> Bool {
        guard let idx = model.steps.firstIndex(of: step) else { return false }
        return stepIndex >= idx
    }

    var body: some View {
        let m = model
        HStack(alignment: .bottom, spacing: 2) {
            Text(m.cationSymbol).font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.cation)
            if m.cationSub > 1 { subscriptLabel(m.cationSub) }
            if m.showBrackets { bracket("(") }
            Text(m.anionSymbol).font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.anion)
            if m.showBrackets { bracket(")") }
            if m.anionSub > 1 { subscriptLabel(m.anionSub) }
        }
        .overlay(alignment: .top) {
            if m.showGcd, model.steps.indices.contains(stepIndex), model.steps[stepIndex] == .gcdReduce {
                Text("÷\(m.gcdValue)")
                    .font(.system(size: 12)).foregroundStyle(Color(hex: 0xfde047))
                    .offset(y: -24)
            }
        }
        .task { await runSteps() }
    }

    private func subscriptLabel(_ n: Int) -> some View {
        Text(subscriptGlyphs(n))
            .font(.system(size: 16)).foregroundStyle(.white)
            .opacity(reached(.crisscross) ? 1 : 0)
            .offset(y: reached(.crisscross) ? 0 : -12)
    }

    private func bracket(_ s: String) -> some View {
        Text(s).font(.system(size: 30)).foregroundStyle(Theme.anion)
            .opacity(reached(.brackets) ? 1 : 0)
    }

    private func runSteps() async {
        let durationNs: [CrossoverStep: UInt64] = [
            .isolate: 200_000_000, .crisscross: 600_000_000,
            .brackets: 300_000_000, .gcdReduce: 400_000_000, .done: 0,
        ]
        for i in model.steps.indices {
            withAnimation(.easeOut(duration: 0.25)) { stepIndex = i }
            let step = model.steps[i]
            if step == .done { break }
            try? await Task.sleep(nanoseconds: durationNs[step] ?? 400_000_000)
        }
        onComplete()   // always fires at the end → phase machine cannot softlock
    }
}

#Preview {
    CrossoverAnimatorView(
        cation: ZoneState(symbol: "Al", elementClass: .metal, isPolyatomic: false, isTransition: false,
                          valenceElectrons: 3, oxidationStates: [3], derivedCharge: 3, status: .ionized),
        anion: ZoneState(symbol: "O", elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                         valenceElectrons: 6, oxidationStates: [-2], derivedCharge: -2, status: .ionized),
        onComplete: {}
    )
    .padding(40)
    .background(Theme.bg)
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -scheme ChemInteractive -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Bridge/CrossoverAnimatorView.swift
git commit -m "feat: add ionic crossover animator view"
```

---

### Task 5: BondingDiagramView — ionic Lewis electron-transfer

**Files:**
- Create: `ChemInteractive/Views/Bridge/BondingDiagramView.swift`

**Interfaces:**
- Consumes: `ionicPair`, `lewisTransfer`, `dotPositions` (Tasks 1), `Theme`, `ChemCore` (`ZoneState`, `gcd`).
- Produces: `struct BondingDiagramView: View` — `init(cation: ZoneState, anion: ZoneState)`. Lewis electron-transfer for two regular elements; simpler charged-ion view if either is polyatomic.

Verified by compilation. Includes a private `AtomCircleView` and a `#Preview`.

- [ ] **Step 1: Create `ChemInteractive/Views/Bridge/BondingDiagramView.swift`**

```swift
import SwiftUI
import ChemCore

private func chargeSuperscript(_ n: Int) -> String {
    let a = abs(n); let sign = n > 0 ? "+" : "−"
    return a == 1 ? sign : "\(a)\(sign)"
}

/// An atom circle with Lewis dots, optional charge, optional [ ] brackets.
private struct AtomCircleView: View {
    let symbol: String
    let dots: Int
    var charge: Int? = nil
    var bracketed: Bool = false
    let color: Color

    var body: some View {
        let r: CGFloat = 20
        let w: CGFloat = bracketed ? 84 : 60
        ZStack {
            Circle().fill(color.opacity(0.08))
                .overlay(Circle().stroke(color.opacity(0.45), lineWidth: 1.5))
                .frame(width: r * 2, height: r * 2)
            Text(symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            ForEach(Array(dotPositions(dots).enumerated()), id: \.offset) { _, off in
                Circle().fill(color.opacity(0.85)).frame(width: 5, height: 5).offset(x: off.dx, y: off.dy)
            }
            if bracketed {
                HStack {
                    Text("[").font(.system(size: 24, weight: .ultraLight, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("]").font(.system(size: 24, weight: .ultraLight, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                }
                .frame(width: w)
            }
            if let c = charge, c != 0 {
                Text(chargeSuperscript(c)).font(.system(size: 9)).foregroundStyle(color)
                    .offset(x: bracketed ? w / 2 - 2 : r + 8, y: -r - 2)
            }
        }
        .frame(width: w, height: 60)
    }
}

struct BondingDiagramView: View {
    let cation: ZoneState
    let anion: ZoneState

    var body: some View {
        let pair = ionicPair(cation, anion)
        if !pair.cation.isPolyatomic && !pair.anion.isPolyatomic {
            lewisTransferView(pair.cation, pair.anion)
        } else {
            simpleIonView(pair.cation, pair.anion)
        }
    }

    @ViewBuilder private func coeff(_ n: Int, _ color: Color) -> some View {
        if n > 1 { Text("\(n)").font(.system(size: 14, weight: .bold)).foregroundStyle(color) }
    }

    private func lewisTransferView(_ cat: ZoneState, _ an: ZoneState) -> some View {
        let t = lewisTransfer(cation: cat, anion: an)
        return VStack(spacing: 6) {
            Text("BEFORE").font(.system(size: 8)).tracking(2).foregroundStyle(.white.opacity(0.35))
            HStack(spacing: 4) {
                AtomCircleView(symbol: cat.symbol, dots: cat.valenceElectrons, color: Theme.cation)
                Text("+").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                AtomCircleView(symbol: an.symbol, dots: an.valenceElectrons, color: Theme.anion)
            }
            HStack(spacing: 4) {
                Text("\(t.eMoved)e⁻").font(.system(size: 9)).foregroundStyle(Theme.cation.opacity(0.7))
                Text("→").font(.system(size: 16)).foregroundStyle(.white.opacity(0.75))
            }
            Text("AFTER").font(.system(size: 8)).tracking(2).foregroundStyle(.white.opacity(0.35))
            HStack(spacing: 4) {
                coeff(t.cCount, Theme.cation)
                AtomCircleView(symbol: cat.symbol, dots: 0, charge: cat.derivedCharge, color: Theme.cation)
                Text("+").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                coeff(t.aCount, Theme.anion)
                AtomCircleView(symbol: an.symbol, dots: t.anionAfterDots, charge: an.derivedCharge, bracketed: true, color: Theme.anion)
            }
            Text("IONIC BOND").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(.white.opacity(0.45))
        }
    }

    private func simpleIonView(_ cat: ZoneState, _ an: ZoneState) -> some View {
        let g = max(1, gcd(abs(cat.derivedCharge ?? 0), abs(an.derivedCharge ?? 0)))
        let cCount = abs(an.derivedCharge ?? 0) / g
        let aCount = abs(cat.derivedCharge ?? 0) / g
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                coeff(cCount, Theme.cation)
                AtomCircleView(symbol: cat.symbol, dots: 0, charge: cat.derivedCharge, color: Theme.cation)
                Text("↔").font(.system(size: 18)).foregroundStyle(.white.opacity(0.75))
                coeff(aCount, Theme.anion)
                AtomCircleView(symbol: an.symbol, dots: 0, charge: an.derivedCharge, bracketed: true, color: Theme.anion)
            }
            Text("IONIC BOND").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(.white.opacity(0.45))
        }
    }
}

#Preview {
    BondingDiagramView(
        cation: ZoneState(symbol: "Na", elementClass: .metal, isPolyatomic: false, isTransition: false,
                          valenceElectrons: 1, oxidationStates: [1], derivedCharge: 1, status: .ionized),
        anion: ZoneState(symbol: "Cl", elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                         valenceElectrons: 7, oxidationStates: [-1], derivedCharge: -1, status: .ionized)
    )
    .padding(40)
    .background(Theme.bg)
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -scheme ChemInteractive -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Bridge/BondingDiagramView.swift
git commit -m "feat: add ionic Lewis electron-transfer diagram"
```

---

### Task 6: CovalentLewisView — covalent Lewis structure

**Files:**
- Create: `ChemInteractive/Views/Bridge/CovalentLewisView.swift`

**Interfaces:**
- Consumes: `covalentLayout`, `peripheralPositions`, `lonePairAngles` (Task 2), `Theme`, `Color(hex:)`, `subscriptGlyphs`, `iupacFirst`, `calcStoich`, `ChemCore.ZoneState`.
- Produces: `struct CovalentLewisView: View` — `init(slotA: ZoneState, slotB: ZoneState)`.

Verified by compilation + `#Preview`. All positioned elements live in one `ZStack` so `.position(...)` resolves in a single 280×220 coordinate space.

- [ ] **Step 1: Create `ChemInteractive/Views/Bridge/CovalentLewisView.swift`**

```swift
import SwiftUI
import ChemCore

struct CovalentLewisView: View {
    let slotA: ZoneState
    let slotB: ZoneState

    private let lpColor = Color(hex: 0xc8d2ff)
    private let canvas = CGSize(width: 280, height: 220)

    var body: some View {
        let layout = covalentLayout(slotA: slotA, slotB: slotB)
        let central = layout.centralIsA ? slotA : slotB
        let peripheral = layout.centralIsA ? slotB : slotA
        let centralColor = layout.centralIsA ? Theme.cation : Theme.anion
        let peripheralColor = layout.centralIsA ? Theme.anion : Theme.cation

        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let rC: CGFloat = 38
        let rP: CGFloat = layout.nPeripheral == 1 ? 34 : 28
        let dCP = rC + rP - 14
        let positions = peripheralPositions(layout.nPeripheral, center: center, distance: dCP)
        let centralBondAngles = positions.map { atan2(Double($0.y - center.y), Double($0.x - center.x)) }

        return VStack(spacing: 8) {
            Text("COVALENT BOND").font(.system(size: 9)).tracking(2).foregroundStyle(.white.opacity(0.35))
            ZStack {
                ForEach(Array(positions.enumerated()), id: \.offset) { _, p in
                    bond(from: center, to: p)
                    sharedPairs(from: center, to: p, order: layout.bondOrder,
                                c1: centralColor, c2: peripheralColor)
                }
                ForEach(Array(positions.enumerated()), id: \.offset) { _, p in
                    atom(peripheral.symbol, color: peripheralColor, r: rP).position(p)
                    let bondFromP = atan2(Double(center.y - p.y), Double(center.x - p.x))
                    ForEach(Array(lonePairAngles(bondAngles: [bondFromP], count: layout.peripheralLone).enumerated()), id: \.offset) { _, a in
                        lonePair(at: p, angle: a, r: rP)
                    }
                }
                atom(central.symbol, color: centralColor, r: rC).position(center)
                ForEach(Array(lonePairAngles(bondAngles: centralBondAngles, count: layout.centralLone).enumerated()), id: \.offset) { _, a in
                    lonePair(at: center, angle: a, r: rC)
                }
                if layout.nPeripheral > 4 {
                    Text("×\(layout.nPeripheral)").font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                        .position(x: canvas.width - 18, y: 14)
                }
            }
            .frame(width: canvas.width, height: canvas.height)
            formula(layout.bondOrder)
        }
    }

    private func bond(from a: CGPoint, to b: CGPoint) -> some View {
        Path { p in p.move(to: a); p.addLine(to: b) }.stroke(.white.opacity(0.25), lineWidth: 1)
    }

    @ViewBuilder
    private func sharedPairs(from a: CGPoint, to b: CGPoint, order: Int, c1: Color, c2: Color) -> some View {
        let ang = atan2(b.y - a.y, b.x - a.x)
        let nx = -sin(ang) * 3, ny = cos(ang) * 3
        ForEach(0..<order, id: \.self) { k in
            let frac = CGFloat(k + 1) / CGFloat(order + 1)
            let bx = a.x + (b.x - a.x) * frac
            let by = a.y + (b.y - a.y) * frac
            Group {
                Circle().fill(c1).frame(width: 5, height: 5).position(x: bx - nx, y: by - ny)
                Circle().fill(c2).frame(width: 5, height: 5).position(x: bx + nx, y: by + ny)
            }
        }
    }

    private func atom(_ symbol: String, color: Color, r: CGFloat) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.10)).overlay(Circle().stroke(color.opacity(0.55), lineWidth: 1.8))
            Text(symbol).font(.system(size: r < 32 ? 11 : 13, weight: .bold)).foregroundStyle(color)
        }
        .frame(width: r * 2, height: r * 2)
    }

    @ViewBuilder
    private func lonePair(at p: CGPoint, angle: Double, r: CGFloat) -> some View {
        let d = r + 9
        let x = p.x + CGFloat(cos(angle)) * d
        let y = p.y + CGFloat(sin(angle)) * d
        let px = CGFloat(-sin(angle)) * 3.2, py = CGFloat(cos(angle)) * 3.2
        Group {
            Circle().fill(lpColor.opacity(0.8)).frame(width: 5, height: 5).position(x: x - px, y: y - py)
            Circle().fill(lpColor.opacity(0.8)).frame(width: 5, height: 5).position(x: x + px, y: y + py)
        }
    }

    private func formula(_ bondOrder: Int) -> some View {
        let s = calcStoich(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)
        let homo = slotA.symbol == slotB.symbol
        let aFirst = iupacFirst(slotA.symbol, slotB.symbol)
        let fst = aFirst ? slotA.symbol : slotB.symbol
        let fstN = aFirst ? s.nA : s.nB
        let snd = aFirst ? slotB.symbol : slotA.symbol
        let sndN = aFirst ? s.nB : s.nA
        let text = homo
            ? "\(slotA.symbol)\((s.nA + s.nB) > 1 ? subscriptGlyphs(s.nA + s.nB) : "")"
            : "\(fst)\(fstN > 1 ? subscriptGlyphs(fstN) : "")\(snd)\(sndN > 1 ? subscriptGlyphs(sndN) : "")"
        let label = bondOrder == 1 ? "Single" : bondOrder == 2 ? "Double" : "Triple"
        return VStack(spacing: 2) {
            Text(text).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            Text("\(label) covalent bond · \(bondOrder) shared pair\(bondOrder > 1 ? "s" : "") per bond")
                .font(.system(size: 9)).tracking(1).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center)
        }
    }
}

#Preview {
    CovalentLewisView(
        slotA: ZoneState(symbol: "C", elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                         valenceElectrons: 4, oxidationStates: [], derivedCharge: nil, status: .neutral),
        slotB: ZoneState(symbol: "O", elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                         valenceElectrons: 6, oxidationStates: [], derivedCharge: nil, status: .neutral)
    )
    .padding(20)
    .background(Theme.bg)
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -scheme ChemInteractive -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Bridge/CovalentLewisView.swift
git commit -m "feat: add covalent Lewis structure view"
```

---

### Task 7: MetallicSeaView — cation lattice + animated electron sea

**Files:**
- Create: `ChemInteractive/Views/Bridge/MetallicSeaView.swift`

**Interfaces:**
- Consumes: `metallicElectronsShown`, `metallicIonIndexPattern` (Task 2), `Theme`, `Color(hex:)`, `ChemCore.ZoneState`.
- Produces: `struct MetallicSeaView: View` — `init(slotA: ZoneState, slotB: ZoneState)`. A 3×2 cation lattice with a continuously drifting electron sea via `TimelineView(.animation)` + `Canvas`.

Verified by compilation + `#Preview`.

- [ ] **Step 1: Create `ChemInteractive/Views/Bridge/MetallicSeaView.swift`**

```swift
import SwiftUI
import ChemCore

struct MetallicSeaView: View {
    let slotA: ZoneState
    let slotB: ZoneState

    private let ionPositions: [CGPoint] = [
        CGPoint(x: 40, y: 36), CGPoint(x: 100, y: 36), CGPoint(x: 160, y: 36),
        CGPoint(x: 40, y: 90), CGPoint(x: 100, y: 90), CGPoint(x: 160, y: 90),
    ]
    private let electronPool: [(x0: CGFloat, y0: CGFloat, dx: CGFloat, dy: CGFloat)] = [
        (70, 18, 55, 38), (130, 15, -48, 52), (22, 58, 82, -18), (178, 52, -72, 28),
        (52, 110, 88, -42), (150, 108, -58, -46), (88, 60, 48, -40), (14, 88, 62, -32),
        (186, 80, -58, -28), (100, 115, -32, -52), (62, 42, 70, 42), (138, 80, -65, -35),
    ]
    private let ionColors = [Color(hex: 0xf97316), Color(hex: 0xfb923c)]
    private let electronColor = Color(hex: 0xfde047)

    var body: some View {
        let symbols = [slotA.symbol, slotB.symbol]
        let homo = slotA.symbol == slotB.symbol
        let electrons = Array(electronPool.prefix(metallicElectronsShown(slotA: slotA, slotB: slotB)))

        return VStack(spacing: 8) {
            Text("METALLIC BOND").font(.system(size: 9)).tracking(2).foregroundStyle(.white.opacity(0.35))
            ZStack {
                ForEach(Array(ionPositions.enumerated()), id: \.offset) { i, pos in
                    let idx = metallicIonIndexPattern[i]
                    let clr = ionColors[idx]
                    ZStack {
                        Circle().fill(clr.opacity(0.12))
                            .overlay(Circle().stroke(clr.opacity(0.4), lineWidth: 1.5)).frame(width: 36, height: 36)
                        Text(symbols[idx]).font(.system(size: 11, weight: .bold)).foregroundStyle(clr)
                        Text("+").font(.system(size: 7)).foregroundStyle(clr.opacity(0.7)).offset(x: 13, y: -10)
                    }
                    .position(pos)
                }
                TimelineView(.animation) { tl in
                    Canvas { ctx, _ in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        for (i, e) in electrons.enumerated() {
                            let period = 3.0 + Double(i % 3) * 0.8
                            let phase = (t / period + Double(i) * 0.12).truncatingRemainder(dividingBy: 1)
                            let s = 0.5 * (1 - cos(phase * 2 * .pi))   // smooth 0→1→0
                            let ex = e.x0 + e.dx * s
                            let ey = e.y0 + e.dy * s * 0.85
                            ctx.fill(Path(ellipseIn: CGRect(x: ex - 4, y: ey - 4, width: 8, height: 8)),
                                     with: .color(electronColor.opacity(0.9)))
                        }
                    }
                }
            }
            .frame(width: 200, height: 126)
            .background(.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))

            HStack(spacing: 16) {
                legend(Color(hex: 0xf97316), "Positive metal ion")
                legend(electronColor, "Delocalised e⁻")
            }
            .font(.system(size: 8)).foregroundStyle(.white.opacity(0.5))

            VStack(spacing: 2) {
                Text(homo ? slotA.symbol : "\(slotA.symbol) + \(slotB.symbol)")
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                Text(homo ? "Pure metal · metallic bond" : "Alloy · metallic bond")
                    .font(.system(size: 9)).tracking(1).foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 8, height: 8); Text(t) }
    }
}

#Preview {
    MetallicSeaView(
        slotA: ZoneState(symbol: "Na", elementClass: .metal, isPolyatomic: false, isTransition: false,
                         valenceElectrons: 1, oxidationStates: [], derivedCharge: nil, status: .neutral),
        slotB: ZoneState(symbol: "Mg", elementClass: .metal, isPolyatomic: false, isTransition: false,
                         valenceElectrons: 2, oxidationStates: [], derivedCharge: nil, status: .neutral)
    )
    .padding(20)
    .background(Theme.bg)
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -scheme ChemInteractive -destination 'generic/platform=iOS Simulator' 2>&1 | tail -15`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Bridge/MetallicSeaView.swift
git commit -m "feat: add metallic electron-sea view"
```

---

### Task 8: Wire the diagrams into BridgeView and delete the placeholders

**Files:**
- Delete: `ChemInteractive/Views/Bridge/DiagramPlaceholders.swift`
- Create: `ChemInteractive/Views/Bridge/ResetButton.swift` (after the delete — frees the `ResetButton` name)
- Modify: `ChemInteractive/Views/Bridge/BridgeView.swift`

**Interfaces:**
- Consumes: `CrossoverAnimatorView` (Task 4), `BondingDiagramView` (Task 5), `CovalentLewisView` (Task 6), `MetallicSeaView` (Task 7), `ionicPair` (Task 1), `ionicFormula` (Plan 2), `Theme`, `ChemCore` (`CanvasState`, `CanvasPhase`, `CanvasAction`).
- Produces: `struct ResetButton: View` (internal, `init(action: () -> Void)`) and a `BridgeView` whose result phases render the real diagrams.

**Order matters:** delete `DiagramPlaceholders.swift` (Step 1) *before* creating `ResetButton.swift` (Step 2) — `DiagramPlaceholders` holds a file-private `ResetButton` that would otherwise be an "invalid redeclaration" against the new internal one.

- [ ] **Step 1: Delete the placeholder file**

Run: `git rm ChemInteractive/Views/Bridge/DiagramPlaceholders.swift`
Expected: the file is removed. Its `ResetButton`, `ionicPair`, and three placeholder structs are replaced by the shared helpers and the real diagrams. (At this point `BridgeView` will not compile until Step 3 — that's expected within this task; the build gate is Step 4.)

- [ ] **Step 2: Create `ChemInteractive/Views/Bridge/ResetButton.swift`**

```swift
import SwiftUI

/// The small "Reset" capsule shown under each result diagram.
struct ResetButton: View {
    let action: () -> Void
    var body: some View {
        Button("Reset", action: action)
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .overlay(Capsule().stroke(Theme.muted.opacity(0.6), lineWidth: 1))
    }
}
```

- [ ] **Step 3: Replace the body of `ChemInteractive/Views/Bridge/BridgeView.swift`**

Replace the whole file with:

```swift
import SwiftUI
import ChemCore

struct BridgeView: View {
    @Environment(CanvasModel.self) private var model

    private var state: CanvasState { model.state }

    var body: some View {
        VStack(spacing: 16) {
            Text("⇌").font(.system(size: 28)).foregroundStyle(Theme.accent.opacity(0.6))

            switch state.canvasPhase {
            case .animatingCrossover:
                if let a = state.slotA, let b = state.slotB {
                    let pair = ionicPair(a, b)
                    CrossoverAnimatorView(cation: pair.cation, anion: pair.anion) {
                        model.send(.crossoverComplete)
                    }
                }

            case .complete:
                if let a = state.slotA, let b = state.slotB {
                    let pair = ionicPair(a, b)
                    VStack(spacing: 12) {
                        if let cc = pair.cation.derivedCharge, let ac = pair.anion.derivedCharge {
                            Text(ionicFormula(cationSymbol: pair.cation.symbol, cationCharge: cc,
                                              anionSymbol: pair.anion.symbol, anionCharge: ac,
                                              anionIsPolyatomic: pair.anion.isPolyatomic))
                                .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                        }
                        BondingDiagramView(cation: pair.cation, anion: pair.anion)
                        ResetButton { model.send(.reset) }
                    }
                }

            case .showingCovalent:
                if let a = state.slotA, let b = state.slotB {
                    VStack(spacing: 12) {
                        CovalentLewisView(slotA: a, slotB: b)
                        ResetButton { model.send(.reset) }
                    }
                }

            case .showingMetallic:
                if let a = state.slotA, let b = state.slotB {
                    VStack(spacing: 12) {
                        MetallicSeaView(slotA: a, slotB: b)
                        ResetButton { model.send(.reset) }
                    }
                }

            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
```

- [ ] **Step 4: Build, boot, and confirm the app launches without crashing**

Run:
```bash
xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -12
xcrun simctl boot "iPhone 17" 2>/dev/null; sleep 1
APP=$(find ~/Library/Developer/Xcode/DerivedData -name ChemInteractive.app -path '*Debug-iphonesimulator*' | head -1)
xcrun simctl install "iPhone 17" "$APP"
xcrun simctl launch "iPhone 17" com.cheminteractive.app
```
Expected: `BUILD SUCCEEDED`; the launch prints `com.cheminteractive.app: <PID>` (no crash; initial tray/zones screen unchanged).

- [ ] **Step 5: Run the full test suite (regression gate)**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -12`
Expected: `TEST SUCCEEDED` — all suites pass (LewisLayout, CovalentMetallicLayout, Smoke, CanvasModel, Theme, IonFormat).

- [ ] **Step 6: Commit**

```bash
git add ChemInteractive/Views/Bridge/BridgeView.swift ChemInteractive/Views/Bridge/ResetButton.swift
git rm --cached ChemInteractive/Views/Bridge/DiagramPlaceholders.swift 2>/dev/null; true
git commit -m "feat: route bridge phases to real result diagrams"
```

---

### Task 9: DEBUG direct-to-diagram launch argument + per-diagram screenshots

**Files:**
- Modify: `ChemInteractive/State/CanvasModel.swift` (append a `#if DEBUG` extension)
- Modify: `ChemInteractive/ChemInteractiveApp.swift`

**Interfaces:**
- Consumes: `CanvasModel.place(_:in:)`, `CanvasModel.send(_:)`, `TokenTransfer`, `ChemCore.Slot`/`CanvasAction`.
- Produces (DEBUG only): `CanvasModel.DiagramPreview`, `CanvasModel.debugSeed(_:)`, `CanvasModel.debugPreviewArgument(_:)`.

This is the final gate. The seed **replays real reducer actions** (no bespoke state), so it cannot drift from real behavior. It is compiled out of Release.

- [ ] **Step 1: Append the DEBUG seam to `ChemInteractive/State/CanvasModel.swift`**

Add at the end of the file:

```swift
#if DEBUG
extension CanvasModel {
    enum DiagramPreview: String {
        case crossover, ionic, covalent, metallic
    }

    /// Replays real reducer actions to land in a terminal diagram state (for screenshots).
    func debugSeed(_ which: DiagramPreview) {
        func drop(_ symbol: String, _ slot: Slot, _ poly: Bool = false) {
            place(TokenTransfer(symbol: symbol, isPolyatomic: poly), in: slot)
        }
        switch which {
        case .crossover:
            drop("Na", .a); drop("Cl", .b); send(.dismissExplanation)            // .animatingCrossover (auto-advances)
        case .ionic:
            drop("Na", .a); drop("Cl", .b); send(.dismissExplanation); send(.crossoverComplete)  // .complete
        case .covalent:
            drop("O", .a); drop("O", .b); send(.dismissExplanation)              // .showingCovalent
        case .metallic:
            drop("Na", .a); drop("Mg", .b); send(.dismissExplanation)            // .showingMetallic
        }
    }

    /// Parses `-diagramPreview <name>` from launch arguments.
    static func debugPreviewArgument(_ args: [String]) -> DiagramPreview? {
        guard let i = args.firstIndex(of: "-diagramPreview"), i + 1 < args.count else { return nil }
        return DiagramPreview(rawValue: args[i + 1])
    }
}
#endif
```

- [ ] **Step 2: Wire the launch argument in `ChemInteractive/ChemInteractiveApp.swift`**

Replace the file with:

```swift
import SwiftUI

@main
struct ChemInteractiveApp: App {
    @State private var model = CanvasModel()

    var body: some Scene {
        WindowGroup {
            ChemCanvasView()
                .environment(model)
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

- [ ] **Step 3: Build + boot into each diagram and screenshot**

Run:
```bash
xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -8
xcrun simctl boot "iPhone 17" 2>/dev/null; sleep 1
APP=$(find ~/Library/Developer/Xcode/DerivedData -name ChemInteractive.app -path '*Debug-iphonesimulator*' | head -1)
xcrun simctl install "iPhone 17" "$APP"
for d in ionic covalent metallic; do
  xcrun simctl terminate "iPhone 17" com.cheminteractive.app 2>/dev/null; true
  xcrun simctl launch "iPhone 17" com.cheminteractive.app --args -diagramPreview "$d"
  sleep 2
  xcrun simctl io booted screenshot "/tmp/diagram-$d.png"
done
```
Then Read `/tmp/diagram-ionic.png`, `/tmp/diagram-covalent.png`, `/tmp/diagram-metallic.png` and confirm each shows the expected diagram (ionic → NaCl Lewis transfer with dots/charges; covalent → O₂/CO₂-style central+peripheral with dots; metallic → orange cation lattice with yellow electrons). A blank/black screen or a crash is a FAILURE — investigate via `xcrun simctl spawn booted log show --last 1m --predicate 'process == "ChemInteractive"'` and fix. (The `crossover` preview is intentionally transient — it auto-advances to `.complete` — so it is not screenshotted here; it's covered by the human pass.)

- [ ] **Step 4: Run the full test suite (final regression gate)**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -12`
Expected: `TEST SUCCEEDED` — all suites pass.

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/State/CanvasModel.swift ChemInteractive/ChemInteractiveApp.swift
git commit -m "feat: add DEBUG direct-to-diagram launch argument"
```

- [ ] **Step 6: Human interactive pass (note in the commit/PR, not CLI-automatable)**

In the simulator, drag through each flow and confirm the animations: Na + Cl → watch the **crossover** animate (subscripts cross, ÷gcd where applicable) → **NaCl Lewis transfer**; a TM case (Fe + Cl → pick a charge); O + O and a CO₂-style pair → **covalent** Lewis structure; Na + Mg → **metallic** electron sea drifting continuously; Reset returns to SELECTING from each.

---

## Self-Review

**Spec coverage** (against `2026-06-20-chem-interactive-result-diagrams-design.md`):
- §4 pure helpers (ionicPair, crossover model, Lewis transfer, dot ring, covalent layout, peripheral positions, lone-pair angles, metallic count/pattern) → Tasks 1–2, all unit-tested. ✅
- §5.1 `CrossoverAnimatorView` (4-step, fires `onComplete`) → Task 4. ✅
- §5.2 `BondingDiagramView` (Lewis transfer / simple-ion) → Task 5. ✅
- §5.3 `CovalentLewisView` (central/peripheral, shared+lone dots, ×N for >4) → Task 6. ✅
- §5.4 `MetallicSeaView` (lattice + `TimelineView`+`Canvas` sea) → Task 7. ✅
- §6 `BridgeView` rewiring + delete `DiagramPlaceholders` + shared `ResetButton`/`ionicPair` → Tasks 3 & 8. ✅
- §7 testing (LewisLayoutTests vectors; build/boot/#Preview; human pass) → Tasks 1–2 & 8–9. ✅
- §8 DEBUG launch argument → Task 9. ✅

**Placeholder scan:** no TBD/TODO; every code step is complete; the only "placeholder" removed is the literal Plan-2 stub file (intended).

**Type consistency:** `ionicPair`, `crossoverModel`/`CrossoverModel`/`CrossoverStep`, `lewisTransfer`/`LewisTransfer`, `dotPositions`, `covalentLayout`/`CovalentLayout`, `peripheralPositions`, `lonePairAngles`, `metallicIonIndexPattern`, `metallicElectronsShown` are defined once (Tasks 1–2) and consumed with identical signatures in Tasks 4–8. View initializers (`CrossoverAnimatorView(cation:anion:onComplete:)`, `BondingDiagramView(cation:anion:)`, `CovalentLewisView(slotA:slotB:)`, `MetallicSeaView(slotA:slotB:)`, `ResetButton(action:)`) match their call sites in `BridgeView` (Task 8). `ChemCore` symbols (`gcd`, `calcStoich`, `metallicElectronCount`, `iupacFirst`, `ZoneState`) and Plan-2 helpers (`ionicFormula`, `subscriptGlyphs`, `Theme`, `Color(hex:)`) match their established signatures.
</content>
