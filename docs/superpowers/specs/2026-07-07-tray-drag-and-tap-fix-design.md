# Tray Drag + Reaction Lab Tap Fix (ChemInteractive)

**Date:** 2026-07-07
**Status:** Approved design, ready for implementation planning
**Scope:** Small additive UI fix. Makes element placement work by drag AND tap in both modes.

## Problem

The periodic tray grid tiles (`ElementTokenView`, `PolyatomicTokenView`) are **not draggable** — only the element **detail card** exposes a `.draggable` glyph. The tray's primary interaction is tap-to-select then tap-to-place, wired in bonding's `DropZoneView` but **not** in Reaction Lab's `ReactantZoneView` (which only has a `.dropDestination` and ignores `selectedToken`). Result: in Reaction Lab, tapping a zone does nothing and grid tiles can't be dragged, so there is no discoverable way to add a reactant.

## Decisions locked

- **Drag source:** grid tiles become draggable (works in both modes since drop targets already exist). Accepted trade-off: inside the tray's 2-axis `ScrollView`, iOS uses long-press to initiate a drag; a short pan still scrolls.
- **Both interactions:** keep tap-to-select-then-tap-zone AND drag. Wire tap-to-place into Reaction Lab for parity with bonding.
- The in-zone instructional tour/hints remain a **separate follow-on**, not part of this fix.

## Design

Additive; no ChemCore change; bonding behavior unchanged (it gains drag on grid tiles, which simply adds a second way to do what tap already does).

### Part A — Draggable grid tiles

- `ChemInteractive/Views/Tray/ElementTokenView.swift`: on the active (non-inactive) branch, add `.draggable(token) { dragPreview }`. `token` already exists; a `dragPreview` computed view renders the symbol in a small rounded tile (mirrors `ElementDetailCard`'s proven pattern). `.onTapGesture` (select) stays — long-press drag and tap coexist. Inactive tiles (`allowsHitTesting(false)`) remain non-draggable, so the `animatingCrossover` disable still holds.
- `ChemInteractive/Views/Tray/PolyatomicTokenView.swift`: same, using its `token` (`isPolyatomic: true`).

### Part B — Tap-to-place in Reaction Lab

- `ChemInteractive/Views/RootModeView.swift`: also `.environment(bondingModel)` on `ReactionLabView` so the reaction subtree can read the shared tray selection.
- `ChemInteractive/Views/ReactionLab/ReactantZoneView.swift`:
  - Add `@Environment(CanvasModel.self) private var tray`.
  - Add `.onTapGesture` on the zone container: `if let token = tray.selectedToken { model.place(token, inZone: zone); tray.clearSelection() }`. `model.place` already guards zone-full and pending-charge; inner Buttons (×, quantity, TM picker) keep their own taps.
  - Highlight the zone (accent fill) when `tray.selectedToken != nil`, alongside the existing `isTargeted` drop highlight.

## Testing

Both parts are view wiring — build-gated (`xcodebuild build`, then the full app suite for no regressions). Placement correctness rides on the already-tested `ReactionLabModel.place` (`ReactionLabModelTests`). No new pure logic.

## Out of scope

- In-zone instructional hints / onboarding tour.
- Drag from f-block rows or reordering; drag handles.
