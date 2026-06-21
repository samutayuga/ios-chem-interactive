# Compound Name Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the produced compound's name (ionic + covalent) on the bond result.

**Architecture:** A pure `CompoundName.swift` provides `ionicCompoundName` and `covalentCompoundName` (the latter delegating to a count-explicit `covalentName` core so Greek-prefix/elision is testable without `calcStoich`). `BridgeView` (ionic) and `CovalentLewisView` (covalent) each add a name line. No model/reducer change.

**Tech Stack:** Swift, SwiftUI, XCTest. App target `ChemInteractive`, tests `ChemInteractiveTests`, scheme `ChemInteractive`. `PBXFileSystemSynchronizedRootGroup` auto-includes new files. Test simulator: `iPhone 17 Pro`.

## Global Constraints

- No changes to `CanvasModel`, the reducer, or bonding logic. Metallic results get no name.
- Anion -ide roots (by symbol): F Fluoride, Cl Chloride, Br Bromide, I Iodide, O Oxide, S Sulfide, Se Selenide, Te Telluride, N Nitride, P Phosphide, As Arsenide, C Carbide, H Hydride. Unknown → element name.
- Greek prefixes by count: `["", "di", "tri", "tetra", "penta", "hexa", "hepta", "octa", "nona", "deca"]` (count 1 → "" for the first element; "mono" for the second element when count 1).
- Vowel elision: when a prefix ends in `a`/`o` and the following root starts with a vowel, drop the prefix's final vowel (mono+oxide → monoxide, tetra+oxide → tetroxide; di/tri unchanged → dioxide/trioxide).
- Roman numeral when cation is variable-charge (`isTransition || oxidationStates.count > 1`) and `derivedCharge` is set & positive; numerals `I…VIII`.
- Helpers reused (ChemCore, public): `ionicPair(_:_:)`, `calcStoich(veA:veB:) -> (nA:Int,nB:Int,bondOrder:Int)`, `iupacFirst(_:_:) -> Bool`. `Element` has `symbol`,`name`; `PolyatomicIon` has `symbol`,`name`; `ZoneState` has `symbol`,`isPolyatomic`,`isTransition`,`oxidationStates`,`derivedCharge`,`valenceElectrons`.
- Name line style: `.font(.system(size: 14)).foregroundStyle(Theme.text).multilineTextAlignment(.center)`.

---

## File Structure

- New `ChemInteractive/Theme/CompoundName.swift` — `ionicCompoundName`, `covalentName` (count-explicit core), `covalentCompoundName`, plus private prefix/root/elision/roman helpers.
- New test `ChemInteractiveTests/CompoundNameTests.swift`.
- Modify `ChemInteractive/Views/Bridge/BridgeView.swift` — ionic name line.
- Modify `ChemInteractive/Views/Bridge/CovalentLewisView.swift` — `@Environment` model + covalent name line.

---

## Task 1: `CompoundName.swift` + tests

**Files:**
- Create: `ChemInteractive/Theme/CompoundName.swift`
- Test: `ChemInteractiveTests/CompoundNameTests.swift`

**Interfaces:**
- Consumes: `ZoneState`, `Element`, `PolyatomicIon`, `calcStoich`, `iupacFirst`.
- Produces:
  - `func ionicCompoundName(cation: ZoneState, anion: ZoneState, elements: [Element], ions: [PolyatomicIon]) -> String`
  - `func covalentName(firstSymbol: String, firstCount: Int, secondSymbol: String, secondCount: Int, elements: [Element]) -> String`
  - `func covalentCompoundName(slotA: ZoneState, slotB: ZoneState, elements: [Element]) -> String`

- [ ] **Step 1: Write the failing test**

Create `ChemInteractiveTests/CompoundNameTests.swift`:

```swift
import XCTest
import ChemCore
@testable import ChemInteractive

final class CompoundNameTests: XCTestCase {
    private var elements: [Element] { (try? PeriodicTable.load().elements) ?? [] }
    private var ions: [PolyatomicIon] { PolyatomicIon.polyatomicIons }

    private func ion(_ symbol: String, _ cls: ElementClass, ve: Int, charge: Int,
                     transition: Bool = false, oxStates: [Int]? = nil, poly: Bool = false) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: cls, isPolyatomic: poly, isTransition: transition,
                  valenceElectrons: ve, oxidationStates: oxStates ?? [charge],
                  derivedCharge: charge, status: .ionized)
    }

    func test_ionic_fixedCharge() {
        let na = ion("Na", .metal, ve: 1, charge: 1)
        let cl = ion("Cl", .nonMetal, ve: 7, charge: -1)
        XCTAssertEqual(ionicCompoundName(cation: na, anion: cl, elements: elements, ions: ions),
                       "Sodium chloride")
    }

    func test_ionic_variableChargeRomanNumeral() {
        let fe = ion("Fe", .metal, ve: 2, charge: 3, transition: true, oxStates: [2, 3])
        let o = ion("O", .nonMetal, ve: 6, charge: -2)
        XCTAssertEqual(ionicCompoundName(cation: fe, anion: o, elements: elements, ions: ions),
                       "Iron(III) oxide")
    }

    func test_ionic_polyatomicAnion() {
        let na = ion("Na", .metal, ve: 1, charge: 1)
        let oh = ion("OH", .nonMetal, ve: 0, charge: -1, poly: true)
        XCTAssertEqual(ionicCompoundName(cation: na, anion: oh, elements: elements, ions: ions),
                       "Sodium hydroxide")
    }

    func test_covalentName_prefixesAndElision() {
        XCTAssertEqual(covalentName(firstSymbol: "C", firstCount: 1, secondSymbol: "O", secondCount: 2, elements: elements),
                       "Carbon dioxide")
        XCTAssertEqual(covalentName(firstSymbol: "C", firstCount: 1, secondSymbol: "O", secondCount: 1, elements: elements),
                       "Carbon monoxide")
        XCTAssertEqual(covalentName(firstSymbol: "N", firstCount: 2, secondSymbol: "O", secondCount: 4, elements: elements),
                       "Dinitrogen tetroxide")
        XCTAssertEqual(covalentName(firstSymbol: "N", firstCount: 2, secondSymbol: "O", secondCount: 1, elements: elements),
                       "Dinitrogen monoxide")
    }

    func test_covalentCompound_homonuclear() {
        let n = ion("N", .nonMetal, ve: 5, charge: 0)
        XCTAssertEqual(covalentCompoundName(slotA: n, slotB: n, elements: elements), "Nitrogen")
    }

    func test_covalentCompound_integratesStoich() {
        let c = ion("C", .nonMetal, ve: 4, charge: 0)
        let o = ion("O", .nonMetal, ve: 6, charge: 0)
        // calcStoich(C,O) → CO₂; iupacFirst puts C first.
        XCTAssertEqual(covalentCompoundName(slotA: c, slotB: o, elements: elements), "Carbon dioxide")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/CompoundNameTests`
Expected: FAIL — `cannot find 'ionicCompoundName' in scope`.

- [ ] **Step 3: Write the implementation**

Create `ChemInteractive/Theme/CompoundName.swift`:

```swift
import ChemCore

private let anionRoots: [String: String] = [
    "F": "Fluoride", "Cl": "Chloride", "Br": "Bromide", "I": "Iodide",
    "O": "Oxide", "S": "Sulfide", "Se": "Selenide", "Te": "Telluride",
    "N": "Nitride", "P": "Phosphide", "As": "Arsenide",
    "C": "Carbide", "H": "Hydride",
]

private let greekPrefixes = ["", "di", "tri", "tetra", "penta", "hexa", "hepta", "octa", "nona", "deca"]
private let romanNumerals = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII"]

private func roman(_ n: Int) -> String {
    (n >= 1 && n < romanNumerals.count) ? romanNumerals[n] : String(n)
}

private func elementName(_ symbol: String, _ elements: [Element]) -> String {
    elements.first { $0.symbol == symbol }?.name ?? symbol
}

private func anionRoot(_ symbol: String, _ elements: [Element]) -> String {
    anionRoots[symbol] ?? elementName(symbol, elements)
}

/// Greek prefix for a count. `allowMono` adds "mono" for count 1 (second element only).
private func greekPrefix(_ count: Int, allowMono: Bool) -> String {
    if count == 1 { return allowMono ? "mono" : "" }
    return (count >= 0 && count < greekPrefixes.count) ? greekPrefixes[count] : ""
}

/// Join a Greek prefix to a root, eliding the prefix's trailing a/o before a vowel.
private func joinElided(_ prefix: String, _ root: String) -> String {
    guard let first = root.lowercased().first, "aeiou".contains(first),
          let last = prefix.last, last == "a" || last == "o" else {
        return prefix + root
    }
    return String(prefix.dropLast()) + root
}

private func sentenceCased(_ s: String) -> String {
    guard let first = s.first else { return s }
    return first.uppercased() + s.dropFirst()
}

func ionicCompoundName(cation: ZoneState, anion: ZoneState,
                       elements: [Element], ions: [PolyatomicIon]) -> String {
    var cationWord = elementName(cation.symbol, elements)
    let variable = cation.isTransition || cation.oxidationStates.count > 1
    if variable, let c = cation.derivedCharge, c > 0 {
        cationWord += " (\(roman(c)))"
    }
    let anionWord: String
    if anion.isPolyatomic {
        anionWord = ions.first { $0.symbol == anion.symbol }?.name ?? anion.symbol
    } else {
        anionWord = anionRoot(anion.symbol, elements)
    }
    return "\(cationWord) \(anionWord.lowercased())"
}

/// Covalent name from explicit counts (order already decided by the caller).
func covalentName(firstSymbol: String, firstCount: Int,
                  secondSymbol: String, secondCount: Int, elements: [Element]) -> String {
    let firstWord = greekPrefix(firstCount, allowMono: false) + elementName(firstSymbol, elements).lowercased()
    let secondWord = joinElided(greekPrefix(secondCount, allowMono: true),
                                anionRoot(secondSymbol, elements).lowercased())
    return sentenceCased("\(firstWord) \(secondWord)")
}

func covalentCompoundName(slotA: ZoneState, slotB: ZoneState, elements: [Element]) -> String {
    if slotA.symbol == slotB.symbol { return elementName(slotA.symbol, elements) }
    let s = calcStoich(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)
    let aFirst = iupacFirst(slotA.symbol, slotB.symbol)
    return covalentName(firstSymbol: aFirst ? slotA.symbol : slotB.symbol,
                        firstCount: aFirst ? s.nA : s.nB,
                        secondSymbol: aFirst ? slotB.symbol : slotA.symbol,
                        secondCount: aFirst ? s.nB : s.nA,
                        elements: elements)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/CompoundNameTests`
Expected: PASS (6 tests). If the `covalentCompoundName(C,O)` integration assertion fails because `calcStoich` orders/counts differently than CO₂, report it (the prefix/elision unit tests via `covalentName` are the load-bearing ones).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Theme/CompoundName.swift ChemInteractiveTests/CompoundNameTests.swift
git commit -m "feat: add compound naming (ionic + covalent)"
```

---

## Task 2: Name lines in the result views

**Files:**
- Modify: `ChemInteractive/Views/Bridge/BridgeView.swift`
- Modify: `ChemInteractive/Views/Bridge/CovalentLewisView.swift`

**Interfaces:**
- Consumes: `ionicCompoundName(...)`, `covalentCompoundName(...)` (Task 1).
- Produces: finished feature — end of chain.

- [ ] **Step 1: Ionic name line in BridgeView**

In `ChemInteractive/Views/Bridge/BridgeView.swift`, in the `.complete` case, add the name line right after the formula `Text` (inside the same `if let cc..., let ac...` block so it only shows once charges are known). Replace:

```swift
                        if let cc = pair.cation.derivedCharge, let ac = pair.anion.derivedCharge {
                            Text(ionicFormula(cationSymbol: pair.cation.symbol, cationCharge: cc,
                                              anionSymbol: pair.anion.symbol, anionCharge: ac,
                                              anionIsPolyatomic: pair.anion.isPolyatomic))
                                .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                        }
```

with:

```swift
                        if let cc = pair.cation.derivedCharge, let ac = pair.anion.derivedCharge {
                            Text(ionicFormula(cationSymbol: pair.cation.symbol, cationCharge: cc,
                                              anionSymbol: pair.anion.symbol, anionCharge: ac,
                                              anionIsPolyatomic: pair.anion.isPolyatomic))
                                .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                            Text(ionicCompoundName(cation: pair.cation, anion: pair.anion,
                                                   elements: model.elements, ions: model.polyatomicIons))
                                .font(.system(size: 14)).foregroundStyle(Theme.text)
                                .multilineTextAlignment(.center)
                        }
```

- [ ] **Step 2: Covalent name line in CovalentLewisView**

In `ChemInteractive/Views/Bridge/CovalentLewisView.swift`:

Add a model reference. After the line `let slotB: ZoneState` (the stored properties near the top of the struct), add:

```swift
    @Environment(CanvasModel.self) private var model
```

Then in `formula(_:)`, add the name line under the formula `Text`. Replace:

```swift
        return VStack(spacing: 2) {
            Text(text).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            Text("\(label) covalent bond · \(bondOrder) shared pair\(bondOrder > 1 ? "s" : "") per bond")
                .font(.system(size: 9)).tracking(1).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
        }
```

with:

```swift
        return VStack(spacing: 2) {
            Text(text).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            Text(covalentCompoundName(slotA: slotA, slotB: slotB, elements: model.elements))
                .font(.system(size: 14)).foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Text("\(label) covalent bond · \(bondOrder) shared pair\(bondOrder > 1 ? "s" : "") per bond")
                .font(.system(size: 9)).tracking(1).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
        }
```

Note: the `#Preview` at the bottom of `CovalentLewisView.swift` constructs the view without a model in the environment. If the preview crashes/needs it, add `.environment(CanvasModel())` to the preview's modifier chain (the app itself always injects the model at the root, so runtime is fine). Make this preview fix only if the build's preview step requires it.

- [ ] **Step 3: Build + run full suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED; all tests pass (including `CompoundNameTests`).

- [ ] **Step 4: Commit**

```bash
git add ChemInteractive/Views/Bridge/BridgeView.swift ChemInteractive/Views/Bridge/CovalentLewisView.swift
git commit -m "feat: show compound name on ionic and covalent results"
```

---

## Task 3: Manual verification

**Files:** none (verification only).

- [ ] **Step 1: Launch the app.**

- [ ] **Step 2: Ionic fixed** — Na + Cl → reach `.complete` → name "Sodium chloride" under the formula. Mg + O → "Magnesium oxide".

- [ ] **Step 3: Ionic variable** — a transition metal (e.g. Fe) + O, pick the +3 charge → "Iron(III) oxide".

- [ ] **Step 4: Ionic polyatomic** — Na + OH → "Sodium hydroxide".

- [ ] **Step 5: Covalent** — C + O → "Carbon dioxide" under the formula; a homonuclear pair (N + N) → "Nitrogen".

- [ ] **Step 6: Metallic** — Na + Mg → no compound name shown (unchanged).

- [ ] **Step 7: Commit any tweaks** (skip if none).

```bash
git add -A
git commit -m "fix: compound name verification tweaks"
```
