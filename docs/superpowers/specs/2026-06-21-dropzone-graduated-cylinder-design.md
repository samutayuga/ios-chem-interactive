# Drop Zone: Graduated Measuring Cylinder

Date: 2026-06-21
Branch: feat/domain-logic-core

## Problem

The drop zones were redesigned as lab beakers (see
`2026-06-21-dropzone-beaker-design.md`), but the beaker silhouette still does
not read clearly as a vessel that *holds a measured substance*. We want a
graduated measuring cylinder — an instrument with a visible scale — so the
zone communicates "a container with a measurable quantity". The actual
quantity value is a future feature; this spec covers only the vessel + static
scale.

## Goals

1. Each drop zone renders as a graduated measuring cylinder (not a beaker, not
   a plain box).
2. The cylinder shows graduation tick marks up one side and a static "mL" unit
   label, so it reads as a measuring instrument.
3. When a slot holds an element, tinted liquid fills the cylinder to a fixed
   level (substance color = element class), exactly as the beaker did.
4. All existing drop-zone behavior is preserved.
5. Fix the latent hit-testing coupling noted in the beaker review: the
   `contentShape` and the visible vessel must share one aspect-constrained
   container so the tap region always tracks the drawn outline.

## Non-Goals

- No live quantity: the liquid level is fixed (~0.6) and the "mL" label shows
  no number. Binding level/number to a real substance quantity (mL or grams)
  is a separate future spec.
- No animation.
- No changes to `CanvasModel`, the reducer, or bridge/crossover views.
- Slot semantics unchanged: slot A = cation accent, slot B = anion accent.
- Liquid tint stays element-class color; it does NOT change on ionization.

## Current State (reference)

`ChemInteractive/Views/Zones/BeakerShape.swift` defines:
- `BeakerShape: Shape` — beaker silhouette (to be removed).
- `WaveTop: Shape` — liquid region with `fill: CGFloat` (0…1) and a static
  sine-wave top edge (to be KEPT and reused).

`ChemInteractive/Views/Zones/DropZoneView.swift` (current beaker version):
- `accent = slot == .a ? Theme.cation : Theme.anion`.
- `dropDisabled = phase == .animatingCrossover || phase == .explaining`.
- `showReplace = zone != nil && phase != .animatingCrossover`.
- `hasPendingSelection`, `isTargeted`, `highlighted = isTargeted || hasPendingSelection`.
- `liquidFill: CGFloat = 0.6`.
- `beaker` view: `ZStack { WaveTop(fill:).fill(class color.opacity(0.55)).clipShape(BeakerShape()); BeakerShape().stroke(accent...); VStack { content; Spacer() }.padding(8) }.aspectRatio(0.8, .fit).frame(maxWidth: .infinity)`.
- Outer `ZStack(alignment: .topTrailing)`: `beaker.frame(maxWidth:.infinity, minHeight:96)`, replace-X button, then `.contentShape(BeakerShape())`, `.onTapGesture`, `.dropDestination(for: TokenTransfer.self)`.
- `content`: ionized → `formatIon(symbol:charge:)` size 30; neutral → `zone.symbol` size 24; empty → hint size 13 (`accent.opacity(0.8)`), all `foregroundStyle(accent)`.

Test file `ChemInteractiveTests/BeakerShapeTests.swift` asserts `BeakerShape`/
`WaveTop` paths stay within bounds and that higher fill is taller.

`ZoneState` exposes `symbol`, `status` (`.ionized`/`.neutral`/`.deducing`),
`derivedCharge: Int?`, `elementClass`. Helper `elementClassColor(_:) -> Color`.

## Design

### Component 1 — `MeasuringCylinderShape`

Rename `BeakerShape.swift` to `ChemInteractive/Views/Zones/MeasuringCylinder.swift`.
Replace `BeakerShape` with `MeasuringCylinderShape: Shape`:
- A tall narrow body (near-vertical walls, only a hair of taper or none).
- A small pour-spout notch at the top-right rim.
- A wider, rounded base foot at the bottom (a short flared/rounded base so it
  reads as a standing cylinder).
- All geometry derived from `rect` proportions; no absolute sizes. Path is
  closed.

`WaveTop` is kept unchanged in the same file.

### Component 2 — `GraduationTicks`

In the same file, `struct GraduationTicks: Shape`:
- Draws horizontal tick lines up the **left** inner wall of its `rect`.
- Minor ticks every 1/8 of the height (short, ~18% of width); major ticks
  every 1/4 of the height (longer, ~32% of width).
- Pure geometry derived from `rect`; returns a `Path` of line segments (an
  open, strokable path — it is stroked, not filled).

### Component 3 — `DropZoneView` recomposition

The vessel sub-view (rename `beaker` → `cylinder`) layers, inside one
aspect-constrained container:

1. **Liquid** (occupied only): `WaveTop(fill: liquidFill).fill(elementClassColor(zone.elementClass).opacity(0.55)).clipShape(MeasuringCylinderShape())`.
2. **Graduations**: `GraduationTicks().stroke(accent.opacity(0.35), lineWidth: 1).clipShape(MeasuringCylinderShape())`.
3. **Outline**: `MeasuringCylinderShape().stroke(accent.opacity(highlighted ? 1 : 0.4), lineWidth: highlighted ? 3 : 2)`.
4. **Unit label**: a small `Text("mL")` (size ~9, `accent.opacity(0.7)`)
   positioned near the top rim (e.g. top-leading inside the glass via an
   overlay alignment).
5. **Content**: `content` center-aligned horizontally, floated in the upper
   glass (`VStack { content; Spacer() }`), padding to clear the spout/label.

The container uses `.aspectRatio(0.5, contentMode: .fit)` (taller-than-wide
cylinder) and `.frame(maxWidth: .infinity)`.

**Hit-testing fix:** apply `.contentShape(MeasuringCylinderShape())` to the
SAME aspect-constrained container that draws the cylinder (not the outer
`ZStack`), so the tap/drop region always matches the rendered outline
regardless of host frame. The gesture modifiers (`.onTapGesture`,
`.dropDestination`) attach to that container as well. The replace-X button
remains in an outer `ZStack(alignment: .topTrailing)` overlaying the vessel.

Carried over verbatim: `accent`, `dropDisabled`, `showReplace`,
`hasPendingSelection`, `isTargeted`, `liquidFill`, the `.dropDestination(for:
TokenTransfer.self)` → `model.place`, `.onTapGesture` place-on-`selectedToken`,
replace-X → `model.send(.replaceElement(slot: slot))`, and the `content`
font sizes/colors. Frame keeps `minHeight: 96` on the outer container.

### Content alignment

Because the cylinder is narrow, `content` is centered horizontally
(`.frame(maxWidth: .infinity)` on the content or `HStack { Spacer(); …;
Spacer() }`) and top-floated so the symbol sits above the liquid surface and
below the spout/label.

## Data Flow

Unchanged. View derives everything from `model.state`; drops/taps call
`model.place(_:in:)`; replace-X calls `model.send(.replaceElement(slot:))`.
Only rendering changes.

## Error / Edge Handling

- Empty slot: no liquid; cylinder outline + graduations + "mL" + hint only.
- Ionized: liquid color stays class color; `content` shows charge text.
- `dropDisabled`: drop/tap inert as today; replace-X hidden during
  `.animatingCrossover` via `showReplace`.
- Degenerate frames: shapes derive from `rect`; small frame → small cylinder.
- Graduations + liquid + label all clip to / fit within the cylinder, so none
  overflow the vessel.

## Testing

Rename `BeakerShapeTests.swift` → `MeasuringCylinderTests.swift`:
- `MeasuringCylinderShape().path(in:)` is non-empty and stays within the rect
  bounds (small inset tolerance for the spout, like the beaker test).
- `WaveTop` tests retained (within-bounds; higher fill ⇒ taller) — `WaveTop`
  is unchanged.
- `GraduationTicks().path(in:)` is non-empty and stays within rect bounds.

Visual behavior verified by running the app:
- Empty zones render as graduated cylinders with ticks + "mL" in the correct
  slot accent.
- Placing an element fills to the fixed level with class-colored liquid;
  symbol floats above the surface, centered.
- Ionized charge text shows; liquid color unchanged.
- Highlight thickens/brightens the outline on drag-over / pending selection.
- Replace-X clears; drop + tap-to-place both work; taps land only on the
  cylinder outline (hit region matches the drawn shape).

## Files

- Rename + rewrite: `ChemInteractive/Views/Zones/BeakerShape.swift` →
  `ChemInteractive/Views/Zones/MeasuringCylinder.swift`
  (`MeasuringCylinderShape`, `GraduationTicks`, `WaveTop`; `BeakerShape` removed).
- Modify: `ChemInteractive/Views/Zones/DropZoneView.swift`.
- Rename + rewrite test: `ChemInteractiveTests/BeakerShapeTests.swift` →
  `ChemInteractiveTests/MeasuringCylinderTests.swift`.
- Unchanged: `CanvasModel.swift`, reducer, bridge/crossover views.
