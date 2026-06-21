# Graduated Measuring Cylinder Drop Zone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the beaker drop-zone vessel with a graduated measuring cylinder (scale ticks + static "mL" label), keeping the class-colored liquid fill and all interaction behavior, and bind the hit-test shape to the visible vessel.

**Architecture:** Rename `BeakerShape.swift` → `MeasuringCylinder.swift`, swapping `BeakerShape` for `MeasuringCylinderShape` and adding a `GraduationTicks` shape; `WaveTop` is kept verbatim. `DropZoneView` recomposes its vessel sub-view to layer liquid → graduations → outline → "mL" label → centered content inside one aspect-constrained container that also carries `.contentShape` and the gestures. No `CanvasModel`/reducer changes.

**Tech Stack:** Swift, SwiftUI, XCTest. App target `ChemInteractive`, tests `ChemInteractiveTests`, scheme `ChemInteractive`. Project uses `PBXFileSystemSynchronizedRootGroup` — files in the target directories are auto-included; renaming = create new file + delete old, no .pbxproj edits.

## Global Constraints

- Only `DropZoneView.swift` + the renamed shape file + the renamed test file change. Do NOT touch `CanvasModel`, the reducer, bridge/crossover views, or `ChemCanvasView`.
- Slot identity: `accent = slot == .a ? Theme.cation : Theme.anion`.
- Liquid tint = `elementClassColor(zone.elementClass).opacity(0.55)`; shown ONLY when `zone != nil`; tint does NOT change on ionization. Fixed `liquidFill: CGFloat = 0.6`. Reuses existing `WaveTop(fill:)` clipped to the cylinder.
- Outline stroke = `accent.opacity(highlighted ? 1 : 0.4)`, lineWidth `highlighted ? 3 : 2`, where `highlighted = isTargeted || hasPendingSelection`.
- Preserve verbatim: `.dropDestination(for: TokenTransfer.self)` → `model.place(token, in: slot)`; `.onTapGesture` place-on-`selectedToken`; replace-X → `model.send(.replaceElement(slot: slot))`; guards `dropDisabled` (`phase == .animatingCrossover || phase == .explaining`), `showReplace` (`zone != nil && phase != .animatingCrossover`), `hasPendingSelection`.
- Content fonts/colors unchanged: ionized `formatIon(symbol:charge:)` 30; neutral `zone.symbol` 24; empty hint 13 (`accent.opacity(0.8)`), all `foregroundStyle(accent)`. Content is center-aligned horizontally and top-floated.
- Static unit label `Text("mL")` (size 9, `accent.opacity(0.7)`) near the top rim. No numeric quantity (deferred).
- `.contentShape(MeasuringCylinderShape())` and the gesture modifiers attach to the SAME aspect-constrained container that draws the cylinder. Outer frame keeps `minHeight: 96`.
- Cylinder container uses `.aspectRatio(0.5, contentMode: .fit)`.
- Test simulator: `iPhone 17 Pro` (iPhone 16 not installed).

---

## File Structure

- Rename `ChemInteractive/Views/Zones/BeakerShape.swift` → `ChemInteractive/Views/Zones/MeasuringCylinder.swift`: contains `MeasuringCylinderShape`, `GraduationTicks`, `WaveTop`. `BeakerShape` removed.
- Modify `ChemInteractive/Views/Zones/DropZoneView.swift`.
- Rename `ChemInteractiveTests/BeakerShapeTests.swift` → `ChemInteractiveTests/MeasuringCylinderTests.swift`.

---

## Task 1: MeasuringCylinderShape + GraduationTicks (keep WaveTop)

**Files:**
- Create: `ChemInteractive/Views/Zones/MeasuringCylinder.swift`
- Delete: `ChemInteractive/Views/Zones/BeakerShape.swift`
- Create: `ChemInteractiveTests/MeasuringCylinderTests.swift`
- Delete: `ChemInteractiveTests/BeakerShapeTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct MeasuringCylinderShape: Shape { func path(in rect: CGRect) -> Path }`
  - `struct GraduationTicks: Shape { func path(in rect: CGRect) -> Path }` (open, strokable path of tick segments)
  - `struct WaveTop: Shape { var fill: CGFloat; func path(in rect: CGRect) -> Path }` (unchanged from the beaker file)

- [ ] **Step 1: Write the failing test**

Create `ChemInteractiveTests/MeasuringCylinderTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import ChemInteractive

final class MeasuringCylinderTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 100, height: 200)

    func test_cylinderPathStaysWithinRect() {
        let path = MeasuringCylinderShape().path(in: rect)
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(rect.insetBy(dx: -0.5, dy: -0.5).contains(path.boundingRect))
    }

    func test_graduationTicksStayWithinRect() {
        let path = GraduationTicks().path(in: rect)
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

First delete the old shape + test files so the symbols don't collide:

```bash
git rm ChemInteractive/Views/Zones/BeakerShape.swift ChemInteractiveTests/BeakerShapeTests.swift
```

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/MeasuringCylinderTests`
Expected: FAIL — `cannot find 'MeasuringCylinderShape' in scope` (and `WaveTop`, since the old file was removed).

- [ ] **Step 3: Write minimal implementation**

Create `ChemInteractive/Views/Zones/MeasuringCylinder.swift`:

```swift
import SwiftUI

/// A graduated measuring cylinder: narrow vertical body, a small pour-spout at
/// the top-right rim, and a wider rounded base foot. Scales to `rect`.
struct MeasuringCylinderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let x = rect.minX, y = rect.minY
        let bodyLeft = x + w * 0.24
        let bodyRight = x + w * 0.76
        let footLeft = x + w * 0.12
        let footRight = x + w * 0.88
        let rimY = y + h * 0.05
        let spout = w * 0.10
        let footTopY = y + h * 0.90
        let bottomY = y + h
        let corner = w * 0.06

        // Rim left→right with a pour-spout on the right.
        p.move(to: CGPoint(x: bodyLeft, y: rimY))
        p.addLine(to: CGPoint(x: bodyRight - spout, y: rimY))
        p.addLine(to: CGPoint(x: bodyRight + spout * 0.4, y: y))   // spout tip up/out
        p.addLine(to: CGPoint(x: bodyRight, y: rimY + h * 0.02))   // back to wall

        // Right wall down, flare out to the foot, rounded bottom-right.
        p.addLine(to: CGPoint(x: bodyRight, y: footTopY))
        p.addLine(to: CGPoint(x: footRight, y: footTopY))
        p.addLine(to: CGPoint(x: footRight, y: bottomY - corner))
        p.addQuadCurve(to: CGPoint(x: footRight - corner, y: bottomY),
                       control: CGPoint(x: footRight, y: bottomY))

        // Base, rounded bottom-left.
        p.addLine(to: CGPoint(x: footLeft + corner, y: bottomY))
        p.addQuadCurve(to: CGPoint(x: footLeft, y: bottomY - corner),
                       control: CGPoint(x: footLeft, y: bottomY))

        // Left foot up, in to the body wall, up to the rim.
        p.addLine(to: CGPoint(x: footLeft, y: footTopY))
        p.addLine(to: CGPoint(x: bodyLeft, y: footTopY))
        p.addLine(to: CGPoint(x: bodyLeft, y: rimY))
        p.closeSubpath()
        return p
    }
}

/// Measuring graduations: horizontal tick lines up the left inner wall.
/// Minor ticks every 1/8 of the scale height, longer major ticks every 1/4.
/// Returns an open (strokable) path of line segments.
struct GraduationTicks: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let x = rect.minX, y = rect.minY
        let tickLeft = x + w * 0.24       // aligns with the body's left wall
        let minorLen = w * 0.18
        let majorLen = w * 0.32
        let topY = y + h * 0.14
        let botY = y + h * 0.86
        let span = botY - topY
        let divisions = 8
        for i in 0...divisions {
            let ty = topY + span * CGFloat(i) / CGFloat(divisions)
            let len = (i % 2 == 0) ? majorLen : minorLen   // majors every 1/4
            p.move(to: CGPoint(x: tickLeft, y: ty))
            p.addLine(to: CGPoint(x: tickLeft + len, y: ty))
        }
        return p
    }
}

/// The liquid region: fills the lower `fill` fraction of `rect` with a gentle
/// static sine-wave top edge. Clip to a vessel shape to take its contour.
struct WaveTop: Shape {
    var fill: CGFloat   // 0…1, fraction of height from the bottom

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let clamped = min(max(fill, 0), 1)
        let surfaceY = rect.maxY - rect.height * clamped
        let amp = rect.height * 0.03
        let midY = surfaceY + amp

        p.move(to: CGPoint(x: rect.minX, y: midY))
        let steps = 24
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let xx = rect.minX + rect.width * t
            let yy = surfaceY + amp * sin(t * 2 * .pi)
            p.addLine(to: CGPoint(x: xx, y: yy))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/MeasuringCylinderTests`
Expected: PASS (4 tests). NOTE: the app target will NOT fully build yet because `DropZoneView` still references `BeakerShape` (removed). Run with `-only-testing` and expect this specific test bundle to compile its own sources; if the whole-target compile blocks the test run, proceed to Task 2 (which fixes the call site) and run the full suite there. If the test command fails ONLY due to `BeakerShape` errors in `DropZoneView.swift`, that is expected at this step.

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Views/Zones/MeasuringCylinder.swift ChemInteractiveTests/MeasuringCylinderTests.swift
git rm --cached --ignore-unmatch ChemInteractive/Views/Zones/BeakerShape.swift ChemInteractiveTests/BeakerShapeTests.swift 2>/dev/null; true
git commit -m "feat: add MeasuringCylinderShape + GraduationTicks, remove BeakerShape"
```

(The `git rm` in Step 2 already staged the deletions; this commit captures both the new files and the removals.)

---

## Task 2: DropZoneView — graduated cylinder vessel

**Files:**
- Modify: `ChemInteractive/Views/Zones/DropZoneView.swift`

**Interfaces:**
- Consumes: `MeasuringCylinderShape`, `GraduationTicks`, `WaveTop` (Task 1); existing `elementClassColor`, `formatIon`, `CanvasModel`, `ZoneState`.
- Produces: finished drop zone — end of chain.

This task makes the whole app compile again. Deliverable = BUILD SUCCEEDED + full suite passes; appearance verified manually in Task 3.

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
            cylinder

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
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    // Graduated measuring cylinder: liquid → graduations → outline → mL label →
    // centered contents, all inside one aspect-constrained container that also
    // owns the hit-test shape and the drop/tap gestures.
    private var cylinder: some View {
        ZStack {
            if let zone {
                WaveTop(fill: liquidFill)
                    .fill(elementClassColor(zone.elementClass).opacity(0.55))
                    .clipShape(MeasuringCylinderShape())
            }
            GraduationTicks()
                .stroke(accent.opacity(0.35), lineWidth: 1)
                .clipShape(MeasuringCylinderShape())
            MeasuringCylinderShape()
                .stroke(accent.opacity(highlighted ? 1 : 0.4), lineWidth: highlighted ? 3 : 2)

            // Static unit label near the top rim.
            VStack {
                HStack {
                    Text("mL").font(.system(size: 9, weight: .medium))
                        .foregroundStyle(accent.opacity(0.7))
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 6).padding(.leading, 10)

            // Contents float in the upper region, centered horizontally.
            VStack {
                content.frame(maxWidth: .infinity).padding(.top, 20)
                Spacer()
            }
            .padding(8)
        }
        .aspectRatio(0.5, contentMode: .fit)   // tall, narrow cylinder
        .frame(maxWidth: .infinity)
        .contentShape(MeasuringCylinderShape())
        .onTapGesture {
            if let token = model.selectedToken, !dropDisabled { model.place(token, in: slot) }
        }
        .dropDestination(for: TokenTransfer.self) { items, _ in
            guard !dropDisabled, let token = items.first else { return false }
            model.place(token, in: slot)
            return true
        } isTargeted: { isTargeted = $0 }
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

- [ ] **Step 2: Build the app + run full test suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED; all tests pass (including `MeasuringCylinderTests`). If the build fails, fix genuine integration mismatches against the Task 1 shape names; if unresolved, report BLOCKED with the exact compiler output.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Zones/DropZoneView.swift
git commit -m "feat: render drop zone as a graduated measuring cylinder"
```

---

## Task 3: Manual verification in the running app

**Files:** none (verification only).

- [ ] **Step 1: Launch the app** (Xcode Run or `xcodebuild` to a simulator).

- [ ] **Step 2: Empty zones** — both zones render as graduated cylinders with tick marks up the left wall and an "mL" label near the rim; slot A in cation green (`0x00ff88`), slot B in anion pink (`0xff4080`); "Drop here" hint centered.

- [ ] **Step 3: Place element** — cylinder fills to ~60% with element-class-colored liquid; symbol floats above the surface, centered.

- [ ] **Step 4: Ionized state** — charge text via `formatIon` shows; liquid color stays the class color.

- [ ] **Step 5: Highlight** — dragging a token over a zone, or a pending tap-selection, thickens/brightens the cylinder outline.

- [ ] **Step 6: Interactions + hit region** — drop places; tap-to-place (with a selected token) places; replace-X clears the slot; taps register on the cylinder outline (not the empty corners of the frame); during crossover/explaining drops are inert.

- [ ] **Step 7: Commit any tweaks** (skip if none).

```bash
git add -A
git commit -m "fix: graduated cylinder verification tweaks"
```
