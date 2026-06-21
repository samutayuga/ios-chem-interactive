# Drop Zone Beaker Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render each drop zone as a lab beaker that fills with element-class-colored liquid when occupied, instead of a plain rounded-rectangle box.

**Architecture:** Add a pure `BeakerShape` (vessel silhouette) and `WaveTop` (liquid surface) as SwiftUI `Shape`s in a new file. Recompose `DropZoneView` to layer: liquid (clipped to the beaker) → beaker outline (slot accent) → existing contents → replace-X. All drop/tap/state logic is carried over verbatim; only rendering changes.

**Tech Stack:** Swift, SwiftUI. App target `ChemInteractive`. No `CanvasModel`/reducer changes.

## Global Constraints

- Do NOT modify `CanvasModel`, `CanvasReducer`, bridge/crossover views, or the reducer. Only `DropZoneView` rendering changes plus the new shape file.
- Slot identity unchanged: `accent = slot == .a ? Theme.cation : Theme.anion` (`Theme.cation = 0x00ff88`, `Theme.anion = 0xff4080`).
- Liquid tint = `elementClassColor(zone.elementClass)` and does NOT change on ionization.
- Preserve verbatim: `.dropDestination(for: TokenTransfer.self)` → `model.place(token, in: slot)`; `.onTapGesture` place-on-`selectedToken`; replace-X → `model.send(.replaceElement(slot: slot))`; guards `dropDisabled` (`phase == .animatingCrossover || phase == .explaining`), `showReplace` (`zone != nil && phase != .animatingCrossover`), `hasPendingSelection`, `isTargeted`.
- Existing content fonts unchanged: ionized `formatIon(symbol:charge:)` size 30; neutral `zone.symbol` size 24; empty hint size 13, all `foregroundStyle(accent)` (hint `accent.opacity(0.8)`).
- Frame stays `maxWidth: .infinity, minHeight: 96`.
- Helpers/fields (verbatim): `elementClassColor(_ cls: ElementClass) -> Color` (in `Theme.swift`); `ZoneState` exposes `symbol`, `status` (`.ionized`/`.neutral`/`.deducing`), `derivedCharge: Int?`, `elementClass: ElementClass`; `formatIon(symbol:charge:)`.

---

## File Structure

- Create `ChemInteractive/Views/Zones/BeakerShape.swift` — `struct BeakerShape: Shape` + `struct WaveTop: Shape`. Pure geometry, no app dependencies.
- Modify `ChemInteractive/Views/Zones/DropZoneView.swift` — swap the rounded-rect for the beaker layers; keep all interaction modifiers.

---

## Task 1: BeakerShape + WaveTop shapes

**Files:**
- Create: `ChemInteractive/Views/Zones/BeakerShape.swift`
- Test: `ChemInteractiveTests/BeakerShapeTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct BeakerShape: Shape { func path(in rect: CGRect) -> Path }`
  - `struct WaveTop: Shape { var fill: CGFloat; func path(in rect: CGRect) -> Path }` — `fill` is the liquid height fraction (0…1) measured from the bottom.

- [ ] **Step 1: Write the failing test**

Create `ChemInteractiveTests/BeakerShapeTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import ChemInteractive

final class BeakerShapeTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 100, height: 120)

    func test_beakerPathStaysWithinRect() {
        let path = BeakerShape().path(in: rect)
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(rect.insetBy(dx: -0.5, dy: -0.5).contains(path.boundingRect))
    }

    func test_waveTopFillStaysWithinRect() {
        let path = WaveTop(fill: 0.6).path(in: rect)
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(rect.insetBy(dx: -0.5, dy: -0.5).contains(path.boundingRect))
    }

    func test_waveTopHigherFillIsTaller() {
        let low = WaveTop(fill: 0.3).path(in: rect).boundingRect.height
        let high = WaveTop(fill: 0.8).path(in: rect).boundingRect.height
        XCTAssertGreaterThan(high, low)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ChemInteractiveTests/BeakerShapeTests`
Expected: FAIL — `cannot find 'BeakerShape' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `ChemInteractive/Views/Zones/BeakerShape.swift`:

```swift
import SwiftUI

/// A beaker silhouette: flat rim with a small pour-lip notch, slightly tapered
/// body, flat base with softly rounded bottom corners. Scales to `rect`.
struct BeakerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let minX = rect.minX, minY = rect.minY
        let taper = w * 0.06          // rim is wider than base by 2*taper
        let lip = w * 0.10            // pour-lip notch width
        let rimY = minY + h * 0.06    // rim sits a touch below the top
        let corner = w * 0.10         // bottom corner radius

        let rimLeft = minX
        let rimRight = minX + w
        let baseLeft = minX + taper
        let baseRight = minX + w - taper
        let bottomY = minY + h

        // Top rim with a pour-lip notch on the right.
        p.move(to: CGPoint(x: rimLeft, y: rimY))
        p.addLine(to: CGPoint(x: rimRight - lip, y: rimY))
        p.addLine(to: CGPoint(x: rimRight - lip * 0.5, y: minY))   // lip up
        p.addLine(to: CGPoint(x: rimRight, y: rimY))               // lip down

        // Right wall down to base, rounded bottom-right.
        p.addLine(to: CGPoint(x: baseRight, y: bottomY - corner))
        p.addQuadCurve(to: CGPoint(x: baseRight - corner, y: bottomY),
                       control: CGPoint(x: baseRight, y: bottomY))

        // Base, rounded bottom-left.
        p.addLine(to: CGPoint(x: baseLeft + corner, y: bottomY))
        p.addQuadCurve(to: CGPoint(x: baseLeft, y: bottomY - corner),
                       control: CGPoint(x: baseLeft, y: bottomY))

        // Left wall back up to the rim.
        p.addLine(to: CGPoint(x: rimLeft, y: rimY))
        p.closeSubpath()
        return p
    }
}

/// The liquid region: fills the lower `fill` fraction of `rect` with a gentle
/// static sine-wave top edge. Clip to `BeakerShape` to take the vessel contour.
struct WaveTop: Shape {
    var fill: CGFloat   // 0…1, fraction of height from the bottom

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let clamped = min(max(fill, 0), 1)
        let surfaceY = rect.maxY - rect.height * clamped
        let amp = rect.height * 0.03
        let midY = surfaceY + amp

        p.move(to: CGPoint(x: rect.minX, y: midY))
        // Single sine period across the width.
        let steps = 24
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + rect.width * t
            let y = surfaceY + amp * sin(t * 2 * .pi)
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ChemInteractiveTests/BeakerShapeTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Views/Zones/BeakerShape.swift ChemInteractiveTests/BeakerShapeTests.swift
git commit -m "feat: add BeakerShape and WaveTop vessel shapes"
```

---

## Task 2: Recompose DropZoneView as a beaker

**Files:**
- Modify: `ChemInteractive/Views/Zones/DropZoneView.swift`

**Interfaces:**
- Consumes: `BeakerShape`, `WaveTop` (Task 1); existing `elementClassColor`, `formatIon`, `CanvasModel`, `ZoneState`.
- Produces: end of chain — the finished drop zone view.

This is a view change; the deliverable is a successful app build + existing tests still passing. Verification of appearance is manual (Task 3).

- [ ] **Step 1: Replace the view**

Replace the entire contents of `ChemInteractive/Views/Zones/DropZoneView.swift` with:

```swift
import SwiftUI
import ChemCore

struct DropZoneView: View {
    let slot: Slot
    @Environment(CanvasModel.self) private var model
    @State private var isTargeted = false

    private var zone: ChemCore.ZoneState? { slot == .a ? model.state.slotA : model.state.slotB }
    private var phase: ChemCore.CanvasPhase { model.state.canvasPhase }
    private var dropDisabled: Bool { phase == .animatingCrossover || phase == .explaining }
    private var showReplace: Bool { zone != nil && phase != .animatingCrossover }
    private var accent: Color { slot == .a ? Theme.cation : Theme.anion }
    private var hasPendingSelection: Bool { model.selectedToken != nil && !dropDisabled }

    private var highlighted: Bool { isTargeted || hasPendingSelection }
    private let liquidFill: CGFloat = 0.6

    var body: some View {
        ZStack(alignment: .topTrailing) {
            beaker
                .frame(maxWidth: .infinity, minHeight: 96)

            if showReplace {
                Button {
                    model.send(.replaceElement(slot: slot))
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .background(.white.opacity(0.1), in: Circle())
                }
                .padding(8)
            }
        }
        .contentShape(BeakerShape())
        .onTapGesture {
            if let token = model.selectedToken, !dropDisabled { model.place(token, in: slot) }
        }
        .dropDestination(for: TokenTransfer.self) { items, _ in
            guard !dropDisabled, let token = items.first else { return false }
            model.place(token, in: slot)
            return true
        } isTargeted: { isTargeted = $0 }
    }

    // Beaker centered with a glassware aspect ratio; liquid + outline + contents.
    private var beaker: some View {
        ZStack {
            if let zone {
                WaveTop(fill: liquidFill)
                    .fill(elementClassColor(zone.elementClass).opacity(0.55))
                    .clipShape(BeakerShape())
            }
            BeakerShape()
                .stroke(accent.opacity(highlighted ? 1 : 0.4), lineWidth: highlighted ? 3 : 2)

            // Contents float in the upper region, above the liquid surface.
            VStack {
                content.padding(.top, 12)
                Spacer()
            }
            .padding(8)
        }
        .aspectRatio(0.8, contentMode: .fit)   // taller-than-wide glassware
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var content: some View {
        if let zone {
            if zone.status == .ionized, let charge = zone.derivedCharge {
                Text(formatIon(symbol: zone.symbol, charge: charge))
                    .font(.system(size: 30, weight: .bold)).foregroundStyle(accent)
            } else {
                Text(zone.symbol)
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(accent)
            }
        } else {
            Text(hasPendingSelection ? "Tap to place \(model.selectedToken!.symbol)" : "Drop here")
                .font(.system(size: 13)).foregroundStyle(accent.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
}
```

Notes:
- `beaker` layers liquid (occupied only) → outline → contents. `highlighted` reproduces the old stroke-opacity swap (now also thickening the line).
- `.aspectRatio(0.8, contentMode: .fit)` gives the glassware proportion and centers it within the full-width frame.
- `content` is top-aligned (`VStack { content; Spacer() }`) so the symbol floats above the ~60% liquid surface.
- All gesture/drop/replace modifiers are unchanged from the original.

- [ ] **Step 2: Build the app + run full test suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED; all tests PASS (including `BeakerShapeTests`).

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Zones/DropZoneView.swift
git commit -m "feat: render drop zone as a lab beaker with class-colored liquid"
```

---

## Task 3: Manual verification in the running app

**Files:** none (verification only).

- [ ] **Step 1: Launch the app** (Xcode Run or `xcodebuild` to a simulator).

- [ ] **Step 2: Empty zones** — both zones show beaker outlines; slot A in cation green (`0x00ff88`), slot B in anion pink (`0xff4080`); hint text "Drop here" inside.

- [ ] **Step 3: Place element** — beaker fills ~60% with element-class-colored liquid; symbol floats above the surface.

- [ ] **Step 4: Ionized state** — charge text via `formatIon` shows; liquid color stays the class color (does NOT shift to accent).

- [ ] **Step 5: Highlight** — dragging a token over a zone, or having a pending tap-selection, thickens/brightens the beaker outline.

- [ ] **Step 6: Interactions** — drop places; tap-to-place (with a selected token) places; replace-X clears the slot; during crossover/explaining drops are inert.

- [ ] **Step 7: Commit any tweaks** (skip if none).

```bash
git add -A
git commit -m "fix: drop zone beaker verification tweaks"
```
