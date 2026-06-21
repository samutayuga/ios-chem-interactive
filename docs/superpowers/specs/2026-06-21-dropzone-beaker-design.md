# Drop Zone: Lab-Vessel (Beaker) Redesign

Date: 2026-06-21
Branch: feat/domain-logic-core

## Problem

The drop zones (`ChemInteractive/Views/Zones/DropZoneView.swift`) are plain
rounded-rectangle boxes. A simple box does not communicate that the zone is a
*container* meant to hold an element/substance. We want the drop target to read
as chemistry glassware that contains the placed element.

## Goals

1. Each drop zone renders as a lab vessel (beaker/flask), not a plain box.
2. When a slot holds an element, the vessel shows a tinted liquid fill whose
   color represents the substance (element class), with the symbol floating
   above the liquid surface.
3. Empty vessels show only the glass outline plus the placement hint text.
4. All existing drop-zone behavior is preserved unchanged.

## Non-Goals

- No animation of the liquid (static wave surface only).
- No change to `CanvasModel`, the bridge/crossover logic, or the reducer.
- No change to slot semantics: slot A = cation accent, slot B = anion accent.
- Liquid tint does NOT shift on ionization — it stays the element-class color
  (decided: consistent "what substance" signal).

## Current State (reference)

`DropZoneView`:
- `ZStack(alignment: .topTrailing)` with a `RoundedRectangle(cornerRadius: 12)`
  stroked in `accent` (opacity 1 when `isTargeted || hasPendingSelection`,
  else 0.4), `background(content.padding(8))`, `minHeight: 96`, full width.
- Replace-X `Button` (top-trailing) shown when `showReplace`
  (`zone != nil && phase != .animatingCrossover`) → `model.send(.replaceElement(slot:))`.
- `.contentShape(RoundedRectangle(cornerRadius: 12))`.
- `.onTapGesture` → `model.place(token, in: slot)` when a `selectedToken`
  exists and `!dropDisabled`.
- `.dropDestination(for: TokenTransfer.self)` → `model.place`, tracks
  `isTargeted`.
- `content`: if `zone` set → ionized shows `formatIon(symbol:charge:)` at font
  size 30, else `zone.symbol` at size 24, both in `accent`. If empty → hint text
  ("Tap to place \(symbol)" or "Drop here") at size 13, `accent.opacity(0.8)`.

Key bindings used: `slot: Slot`, `model: CanvasModel`, `zone: ZoneState?`,
`zone.status == .ionized`, `zone.derivedCharge: Int?`, `zone.symbol`,
`zone.elementClass: ElementClass`, `accent` = `slot == .a ? Theme.cation :
Theme.anion`, `dropDisabled`, `hasPendingSelection`, `showReplace`,
`isTargeted`. Helper `elementClassColor(_:) -> Color` exists in `Theme.swift`.

## Design

### Component 1 — `BeakerShape` (vessel silhouette)

New file `ChemInteractive/Views/Zones/BeakerShape.swift`.

`struct BeakerShape: Shape` returning a beaker path inside the given `rect`:
- A narrow flat rim across the top with a small pour-lip notch on one side.
- Body walls dropping from the rim, very slightly tapered inward toward the
  base (a touch wider at the rim than the base) so it reads as a beaker.
- Flat base with small rounded bottom corners.

The path is built from `rect` proportions (no hard-coded absolute sizes) so it
scales to whatever frame it is given. Pure geometry — depends on nothing in the
app.

### Component 2 — `WaveTop` (liquid surface)

In the same file, `struct WaveTop: Shape` returning a closed region that fills
the lower portion of its `rect` with a gentle sine-wave top edge:
- Parameter `fill: CGFloat` (0…1) — fraction of the rect height the liquid
  occupies, measured from the bottom.
- The top edge is a single low-amplitude sine curve (static; amplitude a small
  fraction of height) to read as a liquid surface rather than a flat line.

Used clipped to `BeakerShape` so the liquid takes the vessel's contour.

### Component 3 — `DropZoneView` recomposition

Rebuild the body as a `ZStack(alignment: .topTrailing)`:

1. **Liquid layer** (only when `zone != nil`): `WaveTop(fill: liquidFill)`
   filled with `liquidColor`, `.clipShape(BeakerShape())`. `liquidFill` is a
   constant occupied fill fraction (≈ `0.6`). `liquidColor =
   elementClassColor(zone.elementClass).opacity(≈0.55)`.
2. **Glass outline**: `BeakerShape().stroke(accent.opacity(strokeOpacity),
   lineWidth: strokeWidth)` where, to preserve current highlight semantics:
   - `isTargeted || hasPendingSelection` → `strokeOpacity = 1`, `strokeWidth = 3`
   - otherwise → `strokeOpacity = 0.4`, `strokeWidth = 2`
3. **Contents** (`content`, padded): the existing symbol / ionized-charge /
   hint text, unchanged in font sizes and color (`accent`). Positioned in the
   upper region so it floats above the liquid surface (e.g. the `content` is
   top-aligned within the vessel area rather than centered).
4. **Replace-X button**: unchanged, shown when `showReplace`.

Frame stays `maxWidth: .infinity, minHeight: 96`. The beaker is given a fixed
aspect ratio (taller-than-wide, e.g. width ≈ `0.8 × height` via an
`.aspectRatio` on the shape layers or a fixed vessel width) and centered
horizontally so it reads as glassware rather than stretching to a wide box.

`.contentShape(BeakerShape())` replaces the rounded-rect content shape so
hit-testing and the drop region follow the vessel outline.

`.onTapGesture` and `.dropDestination(for: TokenTransfer.self) { … } isTargeted:`
are carried over verbatim (same `model.place` calls, same `dropDisabled`
guard, same `isTargeted` binding).

## Data Flow

Unchanged from today. The view derives everything from `model.state` (`slotA`/
`slotB` → `zone`, `canvasPhase` → `dropDisabled`/`showReplace`) and renders;
drops/taps call `model.place(_:in:)` and the replace button calls
`model.send(.replaceElement(slot:))`. Only the rendering changes.

## Error / Edge Handling

- Empty slot: no liquid layer drawn; outline + hint only.
- Ionized element: liquid color stays element-class color; the `content` shows
  `formatIon(symbol:charge:)` as today.
- `dropDisabled` (`.animatingCrossover` / `.explaining`): drop/tap inert as
  today; replace-X hidden during `.animatingCrossover` via existing
  `showReplace`.
- Degenerate frames: `BeakerShape` / `WaveTop` derive from `rect`, so a small
  frame just yields a small beaker (no absolute sizes to overflow).

## Testing

View-layer change; verify by running the app:
- Empty zones render as beaker outlines in the correct slot accent (A cation,
  B anion) with the hint text.
- Placing an element fills the beaker with class-colored liquid; symbol floats
  above the surface.
- Ionized state shows charge text; liquid color unchanged.
- Drag-over and pending-selection thicken/brighten the outline.
- Replace-X clears the slot; drop and tap-to-place both still work.
- During crossover/explaining, drops are inert.

`BeakerShape` / `WaveTop` are pure `Shape`s; if a sanity test is wanted, assert
`path(in:)` stays within the input `rect` bounds. Optional — primary
verification is visual.

## Files

- New: `ChemInteractive/Views/Zones/BeakerShape.swift` (`BeakerShape`, `WaveTop`).
- Modify: `ChemInteractive/Views/Zones/DropZoneView.swift`.
- Unchanged: `CanvasModel.swift`, bridge/crossover views, reducer.
