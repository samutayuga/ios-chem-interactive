# Orbital-Mismatch Covalent Stoichiometry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When two non-metals of the same group but different periods would form a 1:1 double bond by the octet rule (only Group 16 qualifies), predict the XO₂ structure instead (e.g. S + O → SO₂) and explain why.

**Architecture:** All chemistry stays in the `ChemCore` Swift package; the app target only consumes it. A new pure predicate + wrapper around the existing `calcStoich` implements the rule; `ZoneState` gains `group`/`period` so the app can pass them through; three app consumers swap `calcStoich` → `covalentStoich`; the covalent explanation gains one orbital-mismatch sentence.

**Tech Stack:** Swift 5, SwiftUI, XCTest. ChemCore tests run with `swift test`; app tests run with `xcodebuild test` on an iOS 17 simulator.

## Global Constraints

- Chemistry logic lives ONLY in `ChemCore`. The app target never computes chemistry — it reads `ChemCore` output. (README "Architecture".)
- iOS 17.0+, Swift 5 language mode, portrait iPhone.
- Commit messages: `feat:`/`fix:`/`chore:` prefix, colon + space, NO scope parentheses. Body lines < 70 chars.
- The orbital-mismatch rule is a deliberate divergence from the original Rust `pt-domain` port; `GoldenFidelityTests` only validates per-element fields and is unaffected (must stay green).
- New `ZoneState.group`/`.period` default to `0` so existing call sites and test fixtures keep compiling.

**Test commands (used throughout):**
- ChemCore single suite: `cd ChemCore && swift test --filter CovalentStoichTests`
- ChemCore full: `cd ChemCore && swift test`
- App single suite: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/LewisLayoutTests`
- App full: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17'`

---

### Task 1: ChemCore — orbital-mismatch predicate + `covalentStoich` wrapper

**Files:**
- Modify: `ChemCore/Sources/ChemCore/Engine/CovalentStoich.swift` (append after `calcStoich`, currently ends line 9)
- Test: `ChemCore/Tests/ChemCoreTests/CovalentStoichTests.swift` (append cases before the closing brace, currently line 27)

**Interfaces:**
- Consumes: existing `calcStoich(veA:veB:) -> (nA:Int, nB:Int, bondOrder:Int)`.
- Produces:
  - `isOrbitalMismatchDoubleBond(groupA:Int, periodA:Int, veA:Int, groupB:Int, periodB:Int, veB:Int) -> Bool`
  - `covalentStoich(veA:Int, groupA:Int, periodA:Int, veB:Int, groupB:Int, periodB:Int) -> (nA:Int, nB:Int, bondOrder:Int)`

- [ ] **Step 1: Write the failing tests**

Append inside `final class CovalentStoichTests` in `ChemCore/Tests/ChemCoreTests/CovalentStoichTests.swift` (before the final `}`):

```swift
    func test_covalentStoich_SO2_centralSulfur() {
        // S (group 16, period 3) + O (group 16, period 2) → S central ×1, O ×2, double bond.
        let s = covalentStoich(veA: 6, groupA: 16, periodA: 3, veB: 6, groupB: 16, periodB: 2)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 2); XCTAssertEqual(s.bondOrder, 2)
    }
    func test_covalentStoich_SO2_slotOrderIndependent() {
        // O in slot A, S in slot B → still SO₂ (S central, count 1).
        let s = covalentStoich(veA: 6, groupA: 16, periodA: 2, veB: 6, groupB: 16, periodB: 3)
        XCTAssertEqual(s.nA, 2); XCTAssertEqual(s.nB, 1); XCTAssertEqual(s.bondOrder, 2)
    }
    func test_covalentStoich_SeS2() {
        // Se (period 4) central, S (period 3) ×2.
        let s = covalentStoich(veA: 6, groupA: 16, periodA: 4, veB: 6, groupB: 16, periodB: 3)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 2); XCTAssertEqual(s.bondOrder, 2)
    }
    func test_covalentStoich_O2_samePeriod_unchanged() {
        // O + O: same group AND same period → rule off → octet 1:1 double bond.
        let s = covalentStoich(veA: 6, groupA: 16, periodA: 2, veB: 6, groupB: 16, periodB: 2)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 1); XCTAssertEqual(s.bondOrder, 2)
    }
    func test_covalentStoich_ClF_singleBond_unchanged() {
        // Group 17, different periods → octet gives single bond (not double) → rule off.
        let s = covalentStoich(veA: 7, groupA: 17, periodA: 3, veB: 7, groupB: 17, periodB: 2)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 1); XCTAssertEqual(s.bondOrder, 1)
    }
    func test_covalentStoich_NP_tripleBond_unchanged() {
        // Group 15, different periods → octet gives triple (not double) → rule off.
        let s = covalentStoich(veA: 5, groupA: 15, periodA: 3, veB: 5, groupB: 15, periodB: 2)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 1); XCTAssertEqual(s.bondOrder, 3)
    }
    func test_covalentStoich_differentGroup_unchanged() {
        // C (group 14) + O (group 16) → different group → octet CO₂.
        let s = covalentStoich(veA: 4, groupA: 14, periodA: 2, veB: 6, groupB: 16, periodB: 2)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 2); XCTAssertEqual(s.bondOrder, 2)
    }
    func test_isOrbitalMismatchDoubleBond_truthTable() {
        XCTAssertTrue(isOrbitalMismatchDoubleBond(groupA: 16, periodA: 3, veA: 6,
                                                  groupB: 16, periodB: 2, veB: 6))   // S+O
        XCTAssertFalse(isOrbitalMismatchDoubleBond(groupA: 16, periodA: 2, veA: 6,
                                                   groupB: 16, periodB: 2, veB: 6))  // O+O same period
        XCTAssertFalse(isOrbitalMismatchDoubleBond(groupA: 17, periodA: 3, veA: 7,
                                                   groupB: 17, periodB: 2, veB: 7))  // halogens single
        XCTAssertFalse(isOrbitalMismatchDoubleBond(groupA: 14, periodA: 2, veA: 4,
                                                   groupB: 16, periodB: 2, veB: 6))  // different group
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ChemCore && swift test --filter CovalentStoichTests`
Expected: FAIL — "cannot find 'covalentStoich' in scope" / "cannot find 'isOrbitalMismatchDoubleBond' in scope".

- [ ] **Step 3: Implement the predicate and wrapper**

Append to `ChemCore/Sources/ChemCore/Engine/CovalentStoich.swift` immediately after the `calcStoich` function (after line 9, before the `iupacOrder` declaration):

```swift
/// True when two non-metals of the same group but different periods would, by the
/// octet rule alone, form a 1:1 double bond. Orbital-size mismatch makes that simple
/// double bond inefficient, so the structure resolves to one central + two peripheral
/// atoms. The "1:1 double bond" condition is only satisfiable by valence-6 (Group 16)
/// atoms, so groups 14/15/17 are excluded automatically — no hardcoded group check.
public func isOrbitalMismatchDoubleBond(groupA: Int, periodA: Int, veA: Int,
                                        groupB: Int, periodB: Int, veB: Int) -> Bool {
    guard groupA == groupB, periodA != periodB else { return false }
    let base = calcStoich(veA: veA, veB: veB)
    return base.nA == 1 && base.nB == 1 && base.bondOrder == 2
}

/// Covalent stoichiometry with the orbital-mismatch "double-bond rule" applied.
/// When the rule fires, the larger atom (higher period) is central (count 1) and the
/// smaller atom is peripheral (count 2), each bond a double bond. Otherwise this is
/// the pure octet `calcStoich`.
public func covalentStoich(veA: Int, groupA: Int, periodA: Int,
                           veB: Int, groupB: Int, periodB: Int) -> (nA: Int, nB: Int, bondOrder: Int) {
    if isOrbitalMismatchDoubleBond(groupA: groupA, periodA: periodA, veA: veA,
                                   groupB: groupB, periodB: periodB, veB: veB) {
        return periodA > periodB ? (nA: 1, nB: 2, bondOrder: 2)
                                 : (nA: 2, nB: 1, bondOrder: 2)
    }
    return calcStoich(veA: veA, veB: veB)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ChemCore && swift test --filter CovalentStoichTests`
Expected: PASS (all CovalentStoichTests, including the 5 pre-existing `calcStoich`/`iupacFirst` tests).

- [ ] **Step 5: Run the full ChemCore suite (no regressions)**

Run: `cd ChemCore && swift test`
Expected: PASS — all 61+ tests including `GoldenFidelityTests` (unaffected).

- [ ] **Step 6: Commit**

```bash
git add ChemCore/Sources/ChemCore/Engine/CovalentStoich.swift ChemCore/Tests/ChemCoreTests/CovalentStoichTests.swift
git commit -m "feat: orbital-mismatch covalent stoichiometry rule"
```

---

### Task 2: ChemCore — add `group`/`period` to `ZoneState`

**Files:**
- Modify: `ChemCore/Sources/ChemCore/State/ZoneState.swift`
- Test: `ChemCore/Tests/ChemCoreTests/ZoneStateTests.swift` (append before closing brace, currently line 37)

**Interfaces:**
- Consumes: existing `Element.group`, `Element.period` (already public on `Element`).
- Produces: `ZoneState.group: Int`, `ZoneState.period: Int` (stored, public); designated init gains `group: Int = 0, period: Int = 0` as trailing parameters; `init(element:)` populates them.

- [ ] **Step 1: Write the failing test**

Append inside `final class ZoneStateTests` in `ChemCore/Tests/ChemCoreTests/ZoneStateTests.swift` (before the final `}`):

```swift
    func test_zoneFromElement_carriesGroupAndPeriod() throws {
        let pt = try PeriodicTable.load()
        let s = try XCTUnwrap(pt.bySymbol("S"))
        let zone = ZoneState(element: s)
        XCTAssertEqual(zone.group, 16)
        XCTAssertEqual(zone.period, 3)
    }
    func test_zoneFromElement_oxygen_period2() throws {
        let pt = try PeriodicTable.load()
        let o = try XCTUnwrap(pt.bySymbol("O"))
        let zone = ZoneState(element: o)
        XCTAssertEqual(zone.group, 16)
        XCTAssertEqual(zone.period, 2)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter ZoneStateTests`
Expected: FAIL — "value of type 'ZoneState' has no member 'group'".

- [ ] **Step 3: Add the stored properties**

In `ChemCore/Sources/ChemCore/State/ZoneState.swift`, add two properties after `public var status: ZoneStatus` (line 9):

```swift
    public var group: Int
    public var period: Int
```

- [ ] **Step 4: Extend the designated initializer**

Replace the designated initializer (lines 12-19) with this version (adds two trailing defaulted params + their assignments):

```swift
    public init(symbol: String, elementClass: ElementClass, isPolyatomic: Bool,
                isTransition: Bool, valenceElectrons: Int, oxidationStates: [Int],
                derivedCharge: Int? = nil, wrongCount: Int = 0, status: ZoneStatus = .neutral,
                group: Int = 0, period: Int = 0) {
        self.symbol = symbol; self.elementClass = elementClass; self.isPolyatomic = isPolyatomic
        self.isTransition = isTransition; self.valenceElectrons = valenceElectrons
        self.oxidationStates = oxidationStates; self.derivedCharge = derivedCharge
        self.wrongCount = wrongCount; self.status = status
        self.group = group; self.period = period
    }
```

- [ ] **Step 5: Populate from `Element`**

Replace the `init(element:)` body (lines 21-30) so the `self.init` call passes `group`/`period`:

```swift
    public init(element: Element) {
        self.init(
            symbol: element.symbol,
            elementClass: element.elementClass,
            isPolyatomic: false,
            isTransition: element.block == .d,
            valenceElectrons: parseValenceElectrons(config: element.electronConfiguration, group: element.group),
            oxidationStates: element.oxidationStates,
            group: element.group,
            period: element.period
        )
    }
```

Leave `init(polyatomic:)` unchanged — it omits `group`/`period`, which default to `0` (polyatomics never reach the covalent path).

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd ChemCore && swift test --filter ZoneStateTests`
Expected: PASS.

- [ ] **Step 7: Run the full ChemCore suite (no regressions)**

Run: `cd ChemCore && swift test`
Expected: PASS — all tests green.

- [ ] **Step 8: Commit**

```bash
git add ChemCore/Sources/ChemCore/State/ZoneState.swift ChemCore/Tests/ChemCoreTests/ZoneStateTests.swift
git commit -m "feat: carry group and period on ZoneState"
```

---

### Task 3: App — route covalent consumers through `covalentStoich`

**Files:**
- Modify: `ChemInteractive/Diagrams/LewisLayout.swift:89` (`covalentLayout`)
- Modify: `ChemInteractive/Theme/CompoundName.swift:78` (`covalentCompoundName`)
- Modify: `ChemInteractive/Views/Bridge/CovalentLewisView.swift:95` (`formula`)
- Test: `ChemInteractiveTests/LewisLayoutTests.swift` (extend `atom` helper + add case in `CovalentMetallicLayoutTests`)
- Test: `ChemInteractiveTests/CompoundNameTests.swift` (extend `ion` helper + add case)

**Interfaces:**
- Consumes: `covalentStoich(veA:groupA:periodA:veB:groupB:periodB:)` (Task 1), `ZoneState.group`/`.period` (Task 2).
- Produces: no new public API. `covalentLayout`, `covalentCompoundName`, and `CovalentLewisView.formula` now reflect the orbital-mismatch rule. `CovalentLayout` struct shape is unchanged.

- [ ] **Step 1: Write the failing tests**

In `ChemInteractiveTests/LewisLayoutTests.swift`, replace the `atom` helper in `final class CovalentMetallicLayoutTests` (lines 88-91) with a version that accepts group/period:

```swift
    private func atom(_ symbol: String, ve: Int, group: Int = 0, period: Int = 0) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                  valenceElectrons: ve, oxidationStates: [], derivedCharge: nil, status: .neutral,
                  group: group, period: period)
    }
```

Then add this test method inside the same class (after `test_covalent_N2_triple`, around line 121):

```swift
    func test_covalent_SO2_orbitalMismatch() {
        let l = covalentLayout(slotA: atom("S", ve: 6, group: 16, period: 3),
                               slotB: atom("O", ve: 6, group: 16, period: 2))
        XCTAssertTrue(l.centralIsA)            // S is central
        XCTAssertEqual(l.nPeripheral, 2)       // 2 O
        XCTAssertEqual(l.bondOrder, 2)         // double bonds
        XCTAssertEqual(l.centralLone, 1)       // S: (6 − 2·2)/2
        XCTAssertEqual(l.peripheralLone, 2)    // each O: (6 − 2)/2
    }
```

In `ChemInteractiveTests/CompoundNameTests.swift`, replace the `ion` helper (lines 9-14) with a version that accepts group/period:

```swift
    private func ion(_ symbol: String, _ cls: ElementClass, ve: Int, charge: Int,
                     transition: Bool = false, oxStates: [Int]? = nil, poly: Bool = false,
                     group: Int = 0, period: Int = 0) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: cls, isPolyatomic: poly, isTransition: transition,
                  valenceElectrons: ve, oxidationStates: oxStates ?? [charge],
                  derivedCharge: charge, status: .ionized, group: group, period: period)
    }
```

Then add this test method (after `test_covalentCompound_integratesStoich`, around line 65):

```swift
    func test_covalentCompound_orbitalMismatch_SO2() {
        let s = ion("S", .nonMetal, ve: 6, charge: 0, group: 16, period: 3)
        let o = ion("O", .nonMetal, ve: 6, charge: 0, group: 16, period: 2)
        XCTAssertEqual(covalentCompoundName(slotA: s, slotB: o, elements: elements), "Sulfur dioxide")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/CovalentMetallicLayoutTests -only-testing:ChemInteractiveTests/CompoundNameTests`
Expected: FAIL — `test_covalent_SO2_orbitalMismatch` reports `centralIsA`/`nPeripheral` wrong (current code returns the SO 1:1 double bond) and `test_covalentCompound_orbitalMismatch_SO2` returns "Sulfur monoxide".

- [ ] **Step 3: Update `covalentLayout`**

In `ChemInteractive/Diagrams/LewisLayout.swift`, replace line 89:

```swift
    let s = calcStoich(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)
```

with:

```swift
    let s = covalentStoich(veA: slotA.valenceElectrons, groupA: slotA.group, periodA: slotA.period,
                           veB: slotB.valenceElectrons, groupB: slotB.group, periodB: slotB.period)
```

- [ ] **Step 4: Update `covalentCompoundName`**

In `ChemInteractive/Theme/CompoundName.swift`, replace line 78:

```swift
    let s = calcStoich(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)
```

with:

```swift
    let s = covalentStoich(veA: slotA.valenceElectrons, groupA: slotA.group, periodA: slotA.period,
                           veB: slotB.valenceElectrons, groupB: slotB.group, periodB: slotB.period)
```

- [ ] **Step 5: Update `CovalentLewisView.formula`**

In `ChemInteractive/Views/Bridge/CovalentLewisView.swift`, replace line 95:

```swift
        let s = calcStoich(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)
```

with:

```swift
        let s = covalentStoich(veA: slotA.valenceElectrons, groupA: slotA.group, periodA: slotA.period,
                               veB: slotB.valenceElectrons, groupB: slotB.group, periodB: slotB.period)
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/CovalentMetallicLayoutTests -only-testing:ChemInteractiveTests/CompoundNameTests`
Expected: PASS — including pre-existing `test_covalent_CO2`, `test_covalent_H2O`, `test_covalent_N2_triple`, `test_covalentCompound_integratesStoich` (all use default group/period `0` → same period → rule off → unchanged).

- [ ] **Step 7: Commit**

```bash
git add ChemInteractive/Diagrams/LewisLayout.swift ChemInteractive/Theme/CompoundName.swift ChemInteractive/Views/Bridge/CovalentLewisView.swift ChemInteractiveTests/LewisLayoutTests.swift ChemInteractiveTests/CompoundNameTests.swift
git commit -m "feat: apply orbital-mismatch rule to covalent diagrams"
```

---

### Task 4: App — orbital-mismatch educational sentence

**Files:**
- Modify: `ChemInteractive/Views/Bridge/BondingExplanation.swift` (covalent branch, line 32; add helper after `covalentPairSummary`)
- Test: `ChemInteractiveTests/BondingExplanationTests.swift` (extend `z` helper + add 2 cases)

**Interfaces:**
- Consumes: `isOrbitalMismatchDoubleBond(...)` (Task 1), `ZoneState.group`/`.period`/`.symbol` (Task 2).
- Produces: `orbitalMismatchNote(_ a: ZoneState, _ b: ZoneState) -> String` (returns the sentence, or `""` when the rule does not fire).

- [ ] **Step 1: Write the failing tests**

In `ChemInteractiveTests/BondingExplanationTests.swift`, replace the `z` helper (lines 6-11) with a version that accepts group/period:

```swift
    private func z(_ symbol: String, _ cls: ElementClass, ve: Int, charge: Int? = nil,
                   status: ZoneStatus = .neutral, poly: Bool = false,
                   group: Int = 0, period: Int = 0) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: cls, isPolyatomic: poly, isTransition: false,
                  valenceElectrons: ve, oxidationStates: charge.map { [$0] } ?? [],
                  derivedCharge: charge, status: status, group: group, period: period)
    }
```

Then add these two test methods (before the closing brace, currently line 42):

```swift
    func test_covalentExplanation_orbitalMismatchNote_SO2() {
        let s = z("S", .nonMetal, ve: 6, group: 16, period: 3)
        let o = z("O", .nonMetal, ve: 6, group: 16, period: 2)
        let text = bondingExplanation(.covalent, s, o)
        XCTAssertTrue(text.contains("Group 16"), text)
        XCTAssertTrue(text.contains("different periods"), text)
        XCTAssertTrue(text.contains("two O atoms"), text)
    }
    func test_covalentExplanation_noNote_whenRuleOff() {
        let c = z("C", .nonMetal, ve: 4, group: 14, period: 2)
        let o = z("O", .nonMetal, ve: 6, group: 16, period: 2)
        let text = bondingExplanation(.covalent, c, o)
        XCTAssertFalse(text.contains("orbitals differ"), text)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/BondingExplanationTests`
Expected: FAIL — `test_covalentExplanation_orbitalMismatchNote_SO2` fails (text has no "Group 16" sentence yet).

- [ ] **Step 3: Add the note helper**

In `ChemInteractive/Views/Bridge/BondingExplanation.swift`, add this function immediately after `covalentPairSummary` (after line 52, the closing brace of that function):

```swift
/// Orbital-size-mismatch note appended to a covalent explanation when the
/// "double-bond rule" applies (same group, different period, octet 1:1 double bond).
/// Returns "" otherwise.
func orbitalMismatchNote(_ a: ZoneState, _ b: ZoneState) -> String {
    guard isOrbitalMismatchDoubleBond(groupA: a.group, periodA: a.period, veA: a.valenceElectrons,
                                      groupB: b.group, periodB: b.period, veB: b.valenceElectrons)
    else { return "" }
    let larger = a.period > b.period ? a : b
    let smaller = a.period > b.period ? b : a
    return " \(larger.symbol) and \(smaller.symbol) are both Group \(larger.group) but in different periods, "
        + "so their orbitals differ in size and can't overlap efficiently for a simple 1:1 double bond — "
        + "\(larger.symbol) (larger, period \(larger.period)) instead bonds to two \(smaller.symbol) atoms."
}
```

- [ ] **Step 4: Wire it into the covalent explanation**

In the same file, replace line 32:

```swift
        return share + " " + covalentPairSummary(a, b)
```

with:

```swift
        return share + " " + covalentPairSummary(a, b) + orbitalMismatchNote(a, b)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ChemInteractiveTests/BondingExplanationTests`
Expected: PASS — including pre-existing `test_covalentExplanation_includesPairSummary` and `test_covalentPairSummary_matchesLayout` (C+O use default group/period `0` → rule off → note empty).

- [ ] **Step 6: Run the full app suite (no regressions)**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: PASS — all app-target tests green.

- [ ] **Step 7: Commit**

```bash
git add ChemInteractive/Views/Bridge/BondingExplanation.swift ChemInteractiveTests/BondingExplanationTests.swift
git commit -m "feat: explain orbital mismatch in covalent bonding"
```

---

## Final verification

- [ ] `cd ChemCore && swift test` — all ChemCore tests pass (incl. golden fidelity, unaffected).
- [ ] `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17'` — all app tests pass.
- [ ] Manual simulator check: drop S and O → result shows **SO₂**, S central with two double-bonded O, name "Sulfur dioxide", and the bond explanation includes the orbital-mismatch sentence.

## Self-review notes

- **Spec coverage:** rule predicate + wrapper (Task 1) ✓; trigger table / Group-16-only behavior verified by Task 1 negative cases (ClF, NP, CO) ✓; ZoneState group/period (Task 2) ✓; three consumers rewired (Task 3) ✓; educational sentence (Task 4) ✓; golden-fidelity checkpoint (Task 1 Step 5 / Final) ✓; out-of-scope items not implemented ✓.
- **Type consistency:** `covalentStoich` and `isOrbitalMismatchDoubleBond` signatures identical across Tasks 1, 3, 4. `ZoneState` trailing params `group`/`period` consistent across all helper rewrites.
- **No placeholders:** every step has concrete code and exact commands.
