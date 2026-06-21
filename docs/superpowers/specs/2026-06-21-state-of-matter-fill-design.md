# Drop Zone: State-of-Matter Fill Animation

Date: 2026-06-21
Branch: feat/domain-logic-core

## Problem

When an element is dropped into the measuring-cylinder drop zone it always
shows the same static liquid fill. We want the fill to *represent the
substance's physical state* — solid, liquid, gas, or aqueous — with a short
entrance animation the moment the element lands, reinforcing what state the
substance is in.

## Goals

1. The cylinder's fill reflects the dropped substance's state: solid, liquid,
   gas, or aqueous.
2. Each state has a distinct, brief entrance animation triggered when the slot
   becomes filled.
3. State is resolved without any model/reducer change.

## Non-Goals

- No change to `CanvasModel`, the reducer, or the bonding flow.
- No change to the cylinder shape, ticks, "mL" label, outline, replace-X, or
  any gesture/drop/placement logic.
- No quantity binding (the fill level is still a fixed fraction; this spec is
  about the *state representation*, not amount).
- No per-temperature state calculation — use each element's stored standard
  state (`raw.state`).

## Current State (reference)

`DropZoneView.cylinder` layers, when `zone != nil`:
`WaveTop(fill: liquidFill).fill(elementClassColor(zone.elementClass).opacity(0.55)).clipShape(MeasuringCylinderShape())`
as the first (liquid) layer, then graduations, outline, "mL", content.
`liquidFill: CGFloat = 0.6`. `zone` is a `ChemCore.ZoneState` (`symbol`,
`elementClass`, `isPolyatomic`, …). `model.elements: [Element]`, each `Element`
has `symbol` and `raw: RawElement` with `raw.state: StateOfMatter`
(`.solid`/`.liquid`/`.gas`). `WaveTop(fill:)` and `MeasuringCylinderShape` live
in `Views/Zones/MeasuringCylinder.swift`. `MetallicSeaView` demonstrates the
`TimelineView(.animation)` + `Canvas` particle pattern used here for gas.

## Design

### Component 1 — `SubstanceState` + resolution

In the new file (Component 2), define:

```
enum SubstanceState { case solid, liquid, gas, aqueous }
```

`DropZoneView` resolves it from the filled `zone` plus the model:
- `zone.isPolyatomic` → `.aqueous`.
- else find `model.elements.first { $0.symbol == zone.symbol }`; map
  `raw.state`: `.solid → .solid`, `.liquid → .liquid`, `.gas → .gas`.
- not found → `.liquid` (safe fallback).

This resolution is a small helper on `DropZoneView` (`substanceState(for:
ZoneState) -> SubstanceState`).

### Component 2 — `SubstanceFill` view

New file `ChemInteractive/Views/Zones/SubstanceFill.swift`.

`struct SubstanceFill: View` — init `(state: SubstanceState, color: Color,
fill: CGFloat)`. Renders the state-appropriate animated layer, already clipped
to `MeasuringCylinderShape()`. It owns the entrance-animation state (a
`@State` progress / appeared flag) and starts the animation on `.onAppear`.
Each state is a small private subview to keep responsibilities isolated:

- **liquid** — a `WaveTop` whose `fill` animates from `0` to `fill` (≈0.6) on
  appear (`withAnimation(.easeOut(duration: 0.5))`), filled `color.opacity(0.55)`.
- **solid** — a rounded-rect "chunk" (`color.opacity(0.7)`) sized to the lower
  portion of the vessel, entering with a vertical `offset` from above the rim
  that settles to rest with a small spring bounce
  (`.animation(.spring(response: 0.5, dampingFraction: 0.6))`). No wave surface.
- **gas** — a faint `color.opacity(0.12)` tint plus rising bubbles drawn with
  `TimelineView(.animation)` + `Canvas`: a fixed set of small circles on smooth
  upward periodic paths with per-bubble phase offsets (continuous ambient
  motion, mirroring `MetallicSeaView`'s electron sea). Bubbles use
  `color.opacity(0.5)`.
- **aqueous** — the liquid layer (animated rise, as in *liquid*) plus a
  one-shot "dissolving" effect: a few dots that expand outward from center and
  fade (`scaleEffect` + `opacity` animating to 0 over ~0.6s on appear). Dots
  use `color.opacity(0.6)`.

Only the entrance animations are one-shot; **gas** bubbles loop continuously.

### Component 3 — `DropZoneView` integration

Replace the current occupied-liquid layer:

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
    SubstanceFill(state: substanceState(for: zone),
                  color: elementClassColor(zone.elementClass),
                  fill: liquidFill)
        .id(zone.symbol)   // restart the entrance animation when the slot's content changes
}
```

`.id(zone.symbol)` makes SwiftUI rebuild `SubstanceFill` (re-running its
entrance animation) whenever a different element is placed. All other layers
(graduations, outline, "mL", content, replace-X) and every gesture/guard are
unchanged.

## Data Flow

`DropZoneView` reads `zone` (from `model.state`) and `model.elements`, resolves
`SubstanceState`, and hands it plus the class color to `SubstanceFill`, which
animates locally. Nothing mutates the model; the reducer is untouched.

## Error / Edge Handling

- Empty slot: no `SubstanceFill` (unchanged — only rendered when `zone != nil`).
- Unknown symbol (shouldn't happen for real elements): fallback `.liquid`.
- Polyatomic ions: always `.aqueous` (no element lookup).
- `dropDisabled`/crossover: `SubstanceFill` is a passive visual layer behind
  the content; it does not affect hit-testing or placement.
- Animations are bounded (entrance ≤ ~0.6s; gas loops but is lightweight,
  same pattern as the existing metallic view).

## Testing

- Unit-test the pure resolution: extract `substanceState(for:elements:)` as a
  free/static function so it can be tested without a view:
  - a solid element (e.g. Fe) → `.solid`; a gas (e.g. O or He) → `.gas`; the
    liquid elements (Hg, Br) → `.liquid`; a polyatomic ion zone → `.aqueous`;
    an unknown symbol → `.liquid`.
- View/animation behavior verified by running the app:
  - drop a metal (solid) → chunk drops + settles; a noble gas → bubbles rise;
    Hg/Br → liquid rises; a polyatomic ion → liquid + dissolving dots.
  - symbol still legible above the fill; replacing the element restarts the
    animation; outline/ticks/mL/replace-X unchanged.

## Files

- New: `ChemInteractive/Views/Zones/SubstanceFill.swift` (`SubstanceState`,
  `SubstanceFill`, and the pure `substanceState(for:elements:)` resolver).
- New test: `ChemInteractiveTests/SubstanceStateTests.swift`.
- Modify: `ChemInteractive/Views/Zones/DropZoneView.swift` (swap the liquid
  layer for `SubstanceFill`, add the `substanceState(for:)` wrapper).
- Unchanged: `MeasuringCylinder.swift`, `CanvasModel`, reducer.
