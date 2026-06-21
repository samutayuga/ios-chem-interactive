# State-of-Matter Fill Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the cylinder drop-zone fill represent the dropped substance's state (solid / liquid / gas / aqueous) with a brief entrance animation on drop.

**Architecture:** A pure `resolveSubstanceState(for:elements:)` maps a filled zone to a `SubstanceState`; a new `SubstanceFill` view renders the state-appropriate animated layer (clipped to the cylinder); `DropZoneView` swaps its static liquid layer for `SubstanceFill`. No model/reducer changes.

**Tech Stack:** Swift, SwiftUI, XCTest. App target `ChemInteractive`, tests `ChemInteractiveTests`, scheme `ChemInteractive`. `PBXFileSystemSynchronizedRootGroup` auto-includes new files. Test simulator: `iPhone 17 Pro`.

## Global Constraints

- No changes to `CanvasModel`, the reducer, or the bonding flow.
- State resolution: `zone.isPolyatomic` → `.aqueous`; else look up `model.elements.first { $0.symbol == zone.symbol }` and map `raw.state` (`.solid`/`.liquid`/`.gas`); not found → `.liquid`.
- `StateOfMatter` cases (verbatim): `.solid`, `.liquid`, `.gas`. `Element` exposes `symbol` and `raw: RawElement` with `raw.state: StateOfMatter`.
- Fill fraction stays `0.6` (passed in as `fill`); this feature is state representation, not quantity.
- Tints from `elementClassColor(zone.elementClass)`: liquid/aqueous fill `opacity(0.55)`, solid chunk `opacity(0.7)`, gas tint `opacity(0.12)` + bubbles `opacity(0.5)`, aqueous dots `opacity(0.6)`.
- Entrance animations one-shot (~0.5–0.6s) EXCEPT gas bubbles which loop continuously (mirror `MetallicSeaView`'s `TimelineView(.animation)` + `Canvas`).
- Only `SubstanceFill.swift` (new), its test, `DropZoneView.swift`, and `MeasuringCylinder.swift` (add `animatableData` to `WaveTop`) change.

---

## File Structure

- New `ChemInteractive/Views/Zones/SubstanceFill.swift` — `SubstanceState` enum, `resolveSubstanceState(for:elements:)`, `SubstanceFill` view.
- New test `ChemInteractiveTests/SubstanceStateTests.swift`.
- Modify `ChemInteractive/Views/Zones/MeasuringCylinder.swift` — add `animatableData` to `WaveTop` (enables the smooth liquid rise; static rendering unchanged).
- Modify `ChemInteractive/Views/Zones/DropZoneView.swift` — swap the liquid layer for `SubstanceFill`.

---

## Task 1: `SubstanceState` + pure resolver

**Files:**
- Create: `ChemInteractive/Views/Zones/SubstanceFill.swift`
- Test: `ChemInteractiveTests/SubstanceStateTests.swift`

**Interfaces:**
- Consumes: `ZoneState`, `Element`, `StateOfMatter`.
- Produces:
  - `enum SubstanceState { case solid, liquid, gas, aqueous }`
  - `func resolveSubstanceState(for zone: ZoneState, elements: [Element]) -> SubstanceState`

- [ ] **Step 1: Write the failing test**

Create `ChemInteractiveTests/SubstanceStateTests.swift`:

```swift
import XCTest
import ChemCore
@testable import ChemInteractive

final class SubstanceStateTests: XCTestCase {
    private func zone(_ z: Int) throws -> ZoneState {
        let pt = try PeriodicTable.load()
        return ZoneState(element: try XCTUnwrap(pt.elements.first { $0.atomicNumber == z }))
    }
    private var elements: [Element] { (try? PeriodicTable.load().elements) ?? [] }

    func test_solidElement() throws {
        XCTAssertEqual(resolveSubstanceState(for: try zone(26), elements: elements), .solid)   // Fe
    }
    func test_gasElement() throws {
        XCTAssertEqual(resolveSubstanceState(for: try zone(8), elements: elements), .gas)       // O
    }
    func test_liquidElement() throws {
        XCTAssertEqual(resolveSubstanceState(for: try zone(80), elements: elements), .liquid)   // Hg
    }
    func test_polyatomicIsAqueous() {
        let oh = ZoneState(polyatomic: PolyatomicIon(symbol: "OH", name: "Hydroxide", charge: -1, formula: "OH⁻"))
        XCTAssertEqual(resolveSubstanceState(for: oh, elements: elements), .aqueous)
    }
    func test_unknownSymbolFallsBackToLiquid() {
        let xx = ZoneState(symbol: "Xx", elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                           valenceElectrons: 0, oxidationStates: [])
        XCTAssertEqual(resolveSubstanceState(for: xx, elements: elements), .liquid)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/SubstanceStateTests`
Expected: FAIL — `cannot find 'resolveSubstanceState' in scope` (and `SubstanceState`).

- [ ] **Step 3: Write the enum + resolver**

Create `ChemInteractive/Views/Zones/SubstanceFill.swift`:

```swift
import SwiftUI
import ChemCore

/// The physical state a dropped substance is shown in.
enum SubstanceState { case solid, liquid, gas, aqueous }

/// Resolve the state for a filled zone: polyatomic ions are aqueous; elements
/// use their stored standard state; unknown symbols fall back to liquid.
func resolveSubstanceState(for zone: ZoneState, elements: [Element]) -> SubstanceState {
    if zone.isPolyatomic { return .aqueous }
    guard let el = elements.first(where: { $0.symbol == zone.symbol }) else { return .liquid }
    switch el.raw.state {
    case .solid:  return .solid
    case .liquid: return .liquid
    case .gas:    return .gas
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/SubstanceStateTests`
Expected: PASS (5 tests). If Fe/O/Hg disagree with the bundled data's `state`, report it — the data should carry standard states (Fe solid, O gas, Hg liquid).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Views/Zones/SubstanceFill.swift ChemInteractiveTests/SubstanceStateTests.swift
git commit -m "feat: add SubstanceState resolver"
```

---

## Task 2: `SubstanceFill` view (+ WaveTop animatableData)

**Files:**
- Modify: `ChemInteractive/Views/Zones/SubstanceFill.swift`
- Modify: `ChemInteractive/Views/Zones/MeasuringCylinder.swift`

**Interfaces:**
- Consumes: `SubstanceState` (Task 1), `WaveTop`, `MeasuringCylinderShape`.
- Produces: `struct SubstanceFill: View` — init `(state: SubstanceState, color: Color, fill: CGFloat)`.

Self-contained view; deliverable is a successful build (no call site yet — added in Task 3).

- [ ] **Step 1: Add `animatableData` to WaveTop**

In `ChemInteractive/Views/Zones/MeasuringCylinder.swift`, add an `animatableData` property to `WaveTop` so its `fill` interpolates smoothly. Change:

```swift
struct WaveTop: Shape {
    var fill: CGFloat   // 0…1, fraction of height from the bottom

    func path(in rect: CGRect) -> Path {
```

to:

```swift
struct WaveTop: Shape {
    var fill: CGFloat   // 0…1, fraction of height from the bottom

    var animatableData: CGFloat {
        get { fill }
        set { fill = newValue }
    }

    func path(in rect: CGRect) -> Path {
```

(Static rendering is unchanged; this only lets SwiftUI animate `fill`.)

- [ ] **Step 2: Append the `SubstanceFill` view**

Add to the end of `ChemInteractive/Views/Zones/SubstanceFill.swift`:

```swift
/// State-appropriate animated fill for the measuring cylinder, clipped to its
/// shape. Entrance animations are one-shot; gas bubbles loop.
struct SubstanceFill: View {
    let state: SubstanceState
    let color: Color
    let fill: CGFloat

    @State private var appeared = false

    var body: some View {
        layer
            .clipShape(MeasuringCylinderShape())
            .onAppear { withAnimation(.easeOut(duration: 0.5)) { appeared = true } }
    }

    @ViewBuilder private var layer: some View {
        switch state {
        case .liquid:  liquidLayer
        case .aqueous: aqueousLayer
        case .solid:   solidLayer
        case .gas:     gasLayer
        }
    }

    private var liquidLayer: some View {
        WaveTop(fill: appeared ? fill : 0).fill(color.opacity(0.55))
    }

    private var aqueousLayer: some View {
        ZStack {
            WaveTop(fill: appeared ? fill : 0).fill(color.opacity(0.55))
            GeometryReader { geo in
                let xs: [CGFloat] = [0.3, 0.5, 0.7, 0.4, 0.6]
                let ys: [CGFloat] = [0.55, 0.5, 0.6, 0.65, 0.45]
                ForEach(0..<5, id: \.self) { i in
                    Circle().fill(color.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .position(x: geo.size.width * xs[i], y: geo.size.height * ys[i])
                        .scaleEffect(appeared ? 2.2 : 0.4)
                        .opacity(appeared ? 0 : 0.8)
                }
            }
        }
    }

    private var solidLayer: some View {
        GeometryReader { geo in
            let h = geo.size.height
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.7))
                .frame(height: h * fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .offset(y: appeared ? 0 : -h)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)
        }
    }

    private var gasLayer: some View {
        ZStack {
            color.opacity(0.12)
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let n = 10
                    for i in 0..<n {
                        let period = 2.5 + Double(i % 3) * 0.7
                        let phase = (t / period + Double(i) * 0.13).truncatingRemainder(dividingBy: 1)
                        let x = size.width * (0.15 + 0.7 * Double((i * 37) % 100) / 100.0)
                        let y = size.height * (1 - phase)   // rise bottom → top
                        let r = 2.0 + Double(i % 3)
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                 with: .color(color.opacity(0.5)))
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED (view compiles; not yet referenced).

- [ ] **Step 4: Commit**

```bash
git add ChemInteractive/Views/Zones/SubstanceFill.swift ChemInteractive/Views/Zones/MeasuringCylinder.swift
git commit -m "feat: add SubstanceFill animated state layers"
```

---

## Task 3: Wire SubstanceFill into DropZoneView

**Files:**
- Modify: `ChemInteractive/Views/Zones/DropZoneView.swift`

**Interfaces:**
- Consumes: `resolveSubstanceState(for:elements:)`, `SubstanceFill` (Tasks 1–2).
- Produces: finished feature — end of chain.

- [ ] **Step 1: Swap the liquid layer**

In `ChemInteractive/Views/Zones/DropZoneView.swift`, in the `cylinder` view, replace:

```swift
            if let zone {
                WaveTop(fill: liquidFill)
                    .fill(elementClassColor(zone.elementClass).opacity(0.55))
                    .clipShape(MeasuringCylinderShape())
            }
```

with:

```swift
            if let zone {
                SubstanceFill(state: resolveSubstanceState(for: zone, elements: model.elements),
                              color: elementClassColor(zone.elementClass),
                              fill: liquidFill)
                    .id(zone.symbol)   // restart the entrance animation when the element changes
            }
```

(`SubstanceFill` already clips to `MeasuringCylinderShape`, so the explicit `.clipShape` is removed here. Every other layer and all gestures are unchanged.)

- [ ] **Step 2: Build + run full suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED; all tests pass (including `SubstanceStateTests`).

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Zones/DropZoneView.swift
git commit -m "feat: render state-of-matter fill in the drop zone"
```

---

## Task 4: Manual verification

**Files:** none (verification only).

- [ ] **Step 1: Launch the app.**

- [ ] **Step 2: Solid** — drop a metal (e.g. Na, Fe) → a class-colored chunk drops from the rim and settles at the base with a small bounce; no liquid surface.

- [ ] **Step 3: Gas** — drop a gas (e.g. O, He, Ne) → faint tint with small bubbles rising/drifting continuously.

- [ ] **Step 4: Liquid** — drop Hg or Br → class-colored liquid rises to ~60% with the wave surface.

- [ ] **Step 5: Aqueous** — switch to Polyatomic Ions, drop an ion → liquid rises plus a few dots disperse outward and fade.

- [ ] **Step 6: Re-drop / replace** — replacing the element restarts the entrance animation; the symbol/charge stays legible above the fill; outline, ticks, "mL", and replace-X are unchanged; drop/tap/replace still work.

- [ ] **Step 7: Commit any tweaks** (skip if none).

```bash
git add -A
git commit -m "fix: state-of-matter fill verification tweaks"
```
