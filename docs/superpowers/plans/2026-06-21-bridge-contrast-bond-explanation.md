# Bridge Contrast + Bond-Type Explanation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise contrast of the Bridge result diagrams and make the bond-type label a tappable control that opens a shared-text explanation card (covalent shows bonding/lone-pair counts).

**Architecture:** Extract the existing private `CardChrome` into a shared file; add a pure `bondingExplanation` provider (refactored out of `ExplanationModalView`); add `BondingInfoCard` (uses CardChrome + provider) and `BondTypeLabel` (tappable label owning the card overlay); wire the label into the three diagrams and bump faint text. No model/reducer changes.

**Tech Stack:** Swift, SwiftUI, XCTest. App target `ChemInteractive`, tests `ChemInteractiveTests`, scheme `ChemInteractive`. `PBXFileSystemSynchronizedRootGroup` — new files auto-include.

## Global Constraints

- No changes to `CanvasModel`, the reducer, `CrossoverAnimatorView`, `ResetButton`, or any bonding logic.
- `BondingType` cases (verbatim): `.ionic`, `.covalent`, `.metallic`.
- `CovalentLayout` fields (verbatim): `centralIsA: Bool`, `nPeripheral: Int`, `bondOrder: Int`, `centralLone: Int`, `peripheralLone: Int`; built by `covalentLayout(slotA: ZoneState, slotB: ZoneState) -> CovalentLayout`.
- Reused helpers (verbatim): `electronsNeeded(_ valenceElectrons: Int) -> Int`, `ionicPair(_:_:)`, `ionicFormula(cationSymbol:cationCharge:anionSymbol:anionCharge:anionIsPolyatomic:)`, `chargeExplanation(_:)`. `ZoneState` has `symbol`, `valenceElectrons`, `derivedCharge: Int?`, `status` (`.ionized`), `isPolyatomic`.
- Theme colors: `Theme.text` (light `0xe0d0ff`), `Theme.accent`, `Theme.surface`, `Theme.cation`, `Theme.anion`.
- Contrast targets: BEFORE/AFTER `0.35 → 0.6`; formula sublines `0.4 → 0.7`; legends `0.5 → 0.7`; connectors (`+`,`→`,`↔`) `0.7 → 0.85`; covalent bond lines `0.25 → 0.4`. Decorative dots/lone-pairs/atom strokes unchanged.
- Test simulator: `iPhone 17 Pro`.

---

## File Structure

- New `ChemInteractive/Views/Shared/CardChrome.swift` — extracted internal `CardChrome`.
- New `ChemInteractive/Views/Bridge/BondingExplanation.swift` — `bondingTitle`, `bondingExplanation`, `covalentPairSummary` (pure).
- New `ChemInteractive/Views/Bridge/BondingInfoCard.swift` — `BondingInfoCard`.
- New `ChemInteractive/Views/Bridge/BondTypeLabel.swift` — `BondTypeLabel`.
- Modify `ElementDetailCard.swift` (drop private CardChrome), `ExplanationModalView.swift` (use provider), `BondingDiagramView.swift`, `CovalentLewisView.swift`, `MetallicSeaView.swift` (labels + contrast).
- New test `ChemInteractiveTests/BondingExplanationTests.swift`.

---

## Task 1: Extract shared CardChrome

**Files:**
- Create: `ChemInteractive/Views/Shared/CardChrome.swift`
- Modify: `ChemInteractive/Views/Tray/ElementDetailCard.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `struct CardChrome<Content: View>: View { init(onClose: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) }` (internal).

- [ ] **Step 1: Create the shared file**

Create `ChemInteractive/Views/Shared/CardChrome.swift`:

```swift
import SwiftUI

/// Shared dimmed backdrop + card chrome. Tapping the backdrop closes.
struct CardChrome<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(16)
            .frame(width: 260)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(8)
            }
            .shadow(radius: 20)
        }
    }
}
```

- [ ] **Step 2: Remove the private CardChrome from ElementDetailCard**

In `ChemInteractive/Views/Tray/ElementDetailCard.swift`, delete the entire `private struct CardChrome<Content: View>: View { ... }` block (the first type in the file, lines starting `/// Shared dimmed backdrop + card chrome.` through its closing brace). Leave the rest of the file unchanged — `ElementDetailCard` and `PolyatomicDetailCard` already call `CardChrome(onClose:) { ... }`, which now resolves to the shared internal type.

- [ ] **Step 3: Build + run full suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED; all tests pass (no behavior change; pure refactor).

- [ ] **Step 4: Commit**

```bash
git add ChemInteractive/Views/Shared/CardChrome.swift ChemInteractive/Views/Tray/ElementDetailCard.swift
git commit -m "refactor: extract shared CardChrome from ElementDetailCard"
```

---

## Task 2: BondingExplanation provider + ExplanationModalView refactor

**Files:**
- Create: `ChemInteractive/Views/Bridge/BondingExplanation.swift`
- Modify: `ChemInteractive/Views/Bridge/ExplanationModalView.swift`
- Test: `ChemInteractiveTests/BondingExplanationTests.swift`

**Interfaces:**
- Consumes: `BondingType`, `ZoneState`, `covalentLayout`, `ionicPair`, `ionicFormula`, `electronsNeeded`.
- Produces:
  - `func bondingTitle(_ b: BondingType) -> String`
  - `func bondingExplanation(_ bonding: BondingType, _ a: ZoneState, _ b: ZoneState) -> String`
  - `func covalentPairSummary(_ a: ZoneState, _ b: ZoneState) -> String`

- [ ] **Step 1: Write the failing test**

Create `ChemInteractiveTests/BondingExplanationTests.swift`:

```swift
import XCTest
import ChemCore
@testable import ChemInteractive

final class BondingExplanationTests: XCTestCase {
    private func z(_ symbol: String, _ cls: ElementClass, ve: Int, charge: Int? = nil,
                   status: ZoneStatus = .neutral, poly: Bool = false) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: cls, isPolyatomic: poly, isTransition: false,
                  valenceElectrons: ve, oxidationStates: charge.map { [$0] } ?? [],
                  derivedCharge: charge, status: status)
    }

    func test_ionicExplanation_containsCrossoverFormula() {
        let na = z("Na", .metal, ve: 1, charge: 1, status: .ionized)
        let cl = z("Cl", .nonMetal, ve: 7, charge: -1, status: .ionized)
        let text = bondingExplanation(.ionic, na, cl)
        XCTAssertTrue(text.contains("NaCl"), text)
    }

    func test_metallicExplanation_mentionsElectronSea() {
        let na = z("Na", .metal, ve: 1)
        let text = bondingExplanation(.metallic, na, na)
        XCTAssertTrue(text.lowercased().contains("electron sea") || text.lowercased().contains("delocalised"), text)
    }

    func test_covalentPairSummary_matchesLayout() {
        let c = z("C", .nonMetal, ve: 4)
        let o = z("O", .nonMetal, ve: 6)
        let layout = covalentLayout(slotA: c, slotB: o)
        let summary = covalentPairSummary(c, o)
        XCTAssertTrue(summary.contains("\(layout.bondOrder) pair"), summary)
        XCTAssertTrue(summary.contains("\(layout.nPeripheral) bond"), summary)
    }

    func test_covalentExplanation_includesPairSummary() {
        let c = z("C", .nonMetal, ve: 4)
        let o = z("O", .nonMetal, ve: 6)
        let text = bondingExplanation(.covalent, c, o)
        XCTAssertTrue(text.contains("share"), text)
        XCTAssertTrue(text.contains("bond"), text)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/BondingExplanationTests`
Expected: FAIL — `cannot find 'bondingExplanation' in scope`.

- [ ] **Step 3: Write the provider**

Create `ChemInteractive/Views/Bridge/BondingExplanation.swift`:

```swift
import ChemCore

/// Display title for a bond type.
func bondingTitle(_ b: BondingType) -> String {
    switch b {
    case .ionic: return "Ionic Bonding"
    case .covalent: return "Covalent Bonding"
    case .metallic: return "Metallic Bonding"
    }
}

/// Plain-text explanation of a bond between two zones. Shared by the
/// at-`.explaining` modal and the tappable bond-type info card.
func bondingExplanation(_ bonding: BondingType, _ a: ZoneState, _ b: ZoneState) -> String {
    switch bonding {
    case .ionic:
        let pair = ionicPair(a, b)
        if pair.cation.status == .ionized, pair.anion.status == .ionized,
           let cc = pair.cation.derivedCharge, let ac = pair.anion.derivedCharge {
            let f = ionicFormula(cationSymbol: pair.cation.symbol, cationCharge: cc,
                                 anionSymbol: pair.anion.symbol, anionCharge: ac,
                                 anionIsPolyatomic: pair.anion.isPolyatomic)
            return "Crossover method: each charge becomes the other ion's subscript → \(f)"
        }
        return "The metal transfers its electron(s) to the non-metal; the opposite charges attract to form an ionic bond."
    case .covalent:
        let aN = electronsNeeded(a.valenceElectrons), bN = electronsNeeded(b.valenceElectrons)
        let share = "\(a.symbol) needs \(aN) more electron\(aN != 1 ? "s" : "") and \(b.symbol) needs \(bN) electron\(bN != 1 ? "s" : "") — they share electrons to complete their octets."
        return share + " " + covalentPairSummary(a, b)
    case .metallic:
        if a.symbol == b.symbol {
            return "Each \(a.symbol) atom contributes \(a.valenceElectrons) valence electron\(a.valenceElectrons != 1 ? "s" : "") to a delocalised electron sea. The positive metal ions are held in a lattice by electrostatic attraction to the sea of electrons."
        } else {
            return "Each \(a.symbol) atom contributes \(a.valenceElectrons) electron\(a.valenceElectrons != 1 ? "s" : "") and each \(b.symbol) atom contributes \(b.valenceElectrons) electron\(b.valenceElectrons != 1 ? "s" : ""). The positive metal ions are held in a lattice by electrostatic attraction to the sea of electrons."
        }
    }
}

/// Bonding/lone-pair counts for a covalent pair, derived from `covalentLayout`.
func covalentPairSummary(_ a: ZoneState, _ b: ZoneState) -> String {
    let l = covalentLayout(slotA: a, slotB: b)
    let central = l.centralIsA ? a : b
    let peripheral = l.centralIsA ? b : a
    let kind = l.bondOrder == 1 ? "single" : l.bondOrder == 2 ? "double" : "triple"
    return "Each bond shares \(l.bondOrder) pair\(l.bondOrder > 1 ? "s" : "") (\(kind)); "
        + "\(l.nPeripheral) bond\(l.nPeripheral > 1 ? "s" : "") total; "
        + "\(central.symbol) has \(l.centralLone) lone pair\(l.centralLone != 1 ? "s" : ""), "
        + "each \(peripheral.symbol) has \(l.peripheralLone)."
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/BondingExplanationTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Refactor ExplanationModalView to use the provider**

In `ChemInteractive/Views/Bridge/ExplanationModalView.swift`, replace the `label(_:)` function and the `summary(_:_:_:)` function so both delegate to the shared provider. Replace:

```swift
    private func label(_ b: BondingType) -> String {
        switch b { case .ionic: "Ionic Bonding"; case .covalent: "Covalent Bonding"; case .metallic: "Metallic Bonding" }
    }
```

with:

```swift
    private func label(_ b: BondingType) -> String { bondingTitle(b) }
```

And replace the entire `@ViewBuilder private func summary(_ bonding: BondingType, _ a: ZoneState, _ b: ZoneState) -> some View { ... }` block with:

```swift
    private func summary(_ bonding: BondingType, _ a: ZoneState, _ b: ZoneState) -> some View {
        Text(bondingExplanation(bonding, a, b))
    }
```

(The call site `summary(bonding, a, b).font(...).foregroundStyle(...)` is unchanged.)

- [ ] **Step 6: Run full suite to verify the refactor**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED; all tests pass.

- [ ] **Step 7: Commit**

```bash
git add ChemInteractive/Views/Bridge/BondingExplanation.swift ChemInteractiveTests/BondingExplanationTests.swift ChemInteractive/Views/Bridge/ExplanationModalView.swift
git commit -m "feat: add shared bondingExplanation provider; reuse in modal"
```

---

## Task 3: BondingInfoCard + BondTypeLabel

**Files:**
- Create: `ChemInteractive/Views/Bridge/BondingInfoCard.swift`
- Create: `ChemInteractive/Views/Bridge/BondTypeLabel.swift`

**Interfaces:**
- Consumes: `CardChrome` (Task 1), `bondingTitle`/`bondingExplanation` (Task 2), `BondingType`, `ZoneState`, `Theme`.
- Produces:
  - `struct BondingInfoCard: View` — init `(bonding: BondingType, a: ZoneState, b: ZoneState, onClose: @escaping () -> Void)`.
  - `struct BondTypeLabel: View` — init `(bonding: BondingType, a: ZoneState, b: ZoneState)`.

These are self-contained views; the deliverable is a successful build. No call sites yet (added in Task 4), so they compile but are unused — that is expected this task.

- [ ] **Step 1: Create BondingInfoCard**

Create `ChemInteractive/Views/Bridge/BondingInfoCard.swift`:

```swift
import SwiftUI
import ChemCore

/// Compact explanation card for a bond type, shown when the bond-type label
/// is tapped. Reuses CardChrome and the shared explanation provider.
struct BondingInfoCard: View {
    let bonding: BondingType
    let a: ZoneState
    let b: ZoneState
    let onClose: () -> Void

    var body: some View {
        CardChrome(onClose: onClose) {
            Text(bondingTitle(bonding))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.text)
                .padding(.bottom, 8)
            Text(bondingExplanation(bonding, a, b))
                .font(.system(size: 13))
                .foregroundStyle(Theme.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 2: Create BondTypeLabel**

Create `ChemInteractive/Views/Bridge/BondTypeLabel.swift`:

```swift
import SwiftUI
import ChemCore

/// High-contrast, tappable bond-type label with an info affordance. Tapping
/// opens a BondingInfoCard explaining the bond.
struct BondTypeLabel: View {
    let bonding: BondingType
    let a: ZoneState
    let b: ZoneState
    @State private var showInfo = false

    private var labelText: String {
        switch bonding {
        case .ionic: return "IONIC BOND"
        case .covalent: return "COVALENT BOND"
        case .metallic: return "METALLIC BOND"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(labelText).font(.system(size: 10, weight: .semibold)).tracking(2)
            Image(systemName: "info.circle").font(.system(size: 10))
        }
        .foregroundStyle(Theme.text.opacity(0.85))
        .contentShape(Rectangle())
        .onTapGesture { showInfo = true }
        .overlay {
            if showInfo {
                BondingInfoCard(bonding: bonding, a: a, b: b) { showInfo = false }
            }
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED (new views compile; not yet referenced).

- [ ] **Step 4: Commit**

```bash
git add ChemInteractive/Views/Bridge/BondingInfoCard.swift ChemInteractive/Views/Bridge/BondTypeLabel.swift
git commit -m "feat: add BondingInfoCard and tappable BondTypeLabel"
```

---

## Task 4: Wire labels into diagrams + contrast bumps

**Files:**
- Modify: `ChemInteractive/Views/Bridge/BondingDiagramView.swift`
- Modify: `ChemInteractive/Views/Bridge/CovalentLewisView.swift`
- Modify: `ChemInteractive/Views/Bridge/MetallicSeaView.swift`

**Interfaces:**
- Consumes: `BondTypeLabel` (Task 3).
- Produces: finished feature — end of chain.

- [ ] **Step 1: BondingDiagramView — label + contrast**

In `ChemInteractive/Views/Bridge/BondingDiagramView.swift`:

Replace the IONIC BOND label in `lewisTransferView` —
`Text("IONIC BOND").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(.white.opacity(0.45))`
with:
`BondTypeLabel(bonding: .ionic, a: cat, b: an)`

Replace the IONIC BOND label in `simpleIonView` —
`Text("IONIC BOND").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(.white.opacity(0.45))`
with:
`BondTypeLabel(bonding: .ionic, a: cat, b: an)`

Bump contrast (in `lewisTransferView`):
- `Text("BEFORE")...foregroundStyle(.white.opacity(0.35))` → `.white.opacity(0.6)`
- `Text("AFTER")...foregroundStyle(.white.opacity(0.35))` → `.white.opacity(0.6)`
- both `Text("+")...foregroundStyle(.white.opacity(0.7))` → `.white.opacity(0.85)`
- `Text("→")...foregroundStyle(.white.opacity(0.75))` → `.white.opacity(0.85)`

In `simpleIonView`:
- `Text("↔")...foregroundStyle(.white.opacity(0.75))` → `.white.opacity(0.85)`

- [ ] **Step 2: CovalentLewisView — label + contrast**

In `ChemInteractive/Views/Bridge/CovalentLewisView.swift`:

Replace `Text("COVALENT BOND").font(.system(size: 9)).tracking(2).foregroundStyle(.white.opacity(0.35))`
with `BondTypeLabel(bonding: .covalent, a: slotA, b: slotB)`.

Bump contrast:
- in `bond(from:to:)`: `.stroke(.white.opacity(0.25), lineWidth: 1)` → `.white.opacity(0.4)`
- in `formula(_:)`: the subline `Text("\(label) covalent bond · ...").font(.system(size: 9)).tracking(1).foregroundStyle(.white.opacity(0.4))` → `.white.opacity(0.7)`
- the `×\(layout.nPeripheral)` overlay `Text(...).foregroundStyle(.white.opacity(0.4))` → `.white.opacity(0.7)`

- [ ] **Step 3: MetallicSeaView — label + contrast**

In `ChemInteractive/Views/Bridge/MetallicSeaView.swift`:

Replace `Text("METALLIC BOND").font(.system(size: 9)).tracking(2).foregroundStyle(.white.opacity(0.35))`
with `BondTypeLabel(bonding: .metallic, a: slotA, b: slotB)`.

Bump contrast:
- the legend `HStack { ... }.font(.system(size: 8)).foregroundStyle(.white.opacity(0.5))` → `.white.opacity(0.7)`
- the subline `Text(homo ? "Pure metal · metallic bond" : "Alloy · metallic bond").font(.system(size: 9)).tracking(1).foregroundStyle(.white.opacity(0.4))` → `.white.opacity(0.7)`

(Leave the small `+` charge marker on the ion at `clr.opacity(0.7)` — it is colored, not white, and reads fine.)

- [ ] **Step 4: Build + run full suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED; all tests pass.

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Views/Bridge/BondingDiagramView.swift ChemInteractive/Views/Bridge/CovalentLewisView.swift ChemInteractive/Views/Bridge/MetallicSeaView.swift
git commit -m "feat: tappable bond-type labels + higher contrast in bridge diagrams"
```

---

## Task 5: Manual verification

**Files:** none (verification only).

- [ ] **Step 1: Launch the app.**

- [ ] **Step 2: Ionic** (e.g. Na + Cl) — reach `.complete`; "IONIC BOND" label is readable with an ⓘ; BEFORE/AFTER/connectors clearly legible; tap the label → info card shows the crossover explanation with the formula; backdrop tap + X dismiss.

- [ ] **Step 3: Covalent** (e.g. two non-metals) — "COVALENT BOND" readable; bond lines + subline clearer; tap → card shows the octet sentence AND the pair summary (bonding pairs, bond count, lone pairs) matching the drawn diagram.

- [ ] **Step 4: Metallic** (e.g. Na + Mg) — "METALLIC BOND" readable; legend + subline clearer; tap → card explains the electron sea.

- [ ] **Step 5: Modal parity** — trigger the `.explaining` modal (before applying) and confirm its wording matches the info-card wording (shared provider).

- [ ] **Step 6: Card coverage check** — confirm the info card's dim backdrop covers the screen and centers the card (BondTypeLabel presents it via `.overlay` + CardChrome). If the backdrop only covers the diagram area, note it and lift the presentation to `BridgeView` level (pass an `onExplain` closure from each diagram and present the card from `BridgeView`).

- [ ] **Step 7: Commit any tweaks** (skip if none).

```bash
git add -A
git commit -m "fix: bridge explanation verification tweaks"
```
