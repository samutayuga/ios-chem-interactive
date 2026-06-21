# Result Diagrams: Order Consistency + Covalent Atom Count

Date: 2026-06-21
Branch: feat/domain-logic-core

## Problem

1. The formula/compound-name vs Lewis-dot diagram order is inconsistent: ionic
   shows formula + name **above** the diagram, while covalent and metallic show
   the diagram **above** the formula/name.
2. The covalent Lewis diagram does not show an explicit numeric atom-count
   coefficient (only draws N peripheral atoms, with a "×N" badge solely when
   N > 4). Ionic already shows the crossover coefficient ("×N" for counts > 1);
   covalent should be comparably explicit.

## Goals

1. All three result diagrams use the same order: **formula + name on top, then
   the Lewis-dot diagram below.**
2. The covalent diagram shows the peripheral-atom count as a numeric "×N" badge
   whenever N > 1 (matching ionic's coefficient visibility). Shared-pairs-per-
   bond count remains in the subline.

## Non-Goals

- No model/reducer change. No ionic change (already conforms to the order).
- No change to the shared-pair dot rendering or atom geometry.

## Current State (reference)

- `BridgeView` `.complete` (ionic): `VStack { formula Text; name Text;
  BondingDiagramView; ResetButton }` — name above diagram. (No change.)
- `CovalentLewisView.body`: `VStack(spacing: 8) { BondTypeLabel; ZStack{ …diagram…;
  if layout.nPeripheral > 4 { Text("×\(nPeripheral)") at top-trailing } }
  .frame(...); formula(layout.bondOrder) }`. `formula(_:)` returns
  `VStack { formula Text; compound-name Text; "… shared pair(s) per bond"
  subline }`.
- `MetallicSeaView.body`: `VStack(spacing: 8) { BondTypeLabel; ZStack{…diagram…}
  .frame(...); legend HStack; VStack { symbol Text; "Pure metal/Alloy ·
  metallic bond" subline } }`.

## Design

### Component 1 — Covalent order + count (`CovalentLewisView`)

- Reorder `body` to `VStack(spacing: 8) { BondTypeLabel; formula(layout.bondOrder);
  diagramZStack }` — move the `formula(...)` block from after the diagram to
  before it. The diagram `ZStack` (with `.frame(width: canvas.width, height:
  canvas.height)`) becomes the last element.
- Lower the peripheral-count badge threshold: change `if layout.nPeripheral > 4`
  to `if layout.nPeripheral > 1` so the `Text("×\(layout.nPeripheral)")` badge
  shows for every multi-atom case (e.g. CO₂ → "×2"). Keep its top-trailing
  position and styling.

### Component 2 — Metallic order (`MetallicSeaView`)

- Reorder `body` to `VStack(spacing: 8) { BondTypeLabel; <formula block>;
  diagramZStack; legend }` — move the bottom `VStack { symbol; "… metallic bond"
  subline }` to directly after `BondTypeLabel` (above the diagram). The legend
  stays after the diagram.

### Order result (all three)

- Ionic: formula + name → diagram (unchanged).
- Covalent: bond-type label → formula + name + shared-pairs subline → diagram.
- Metallic: bond-type label → symbol + metallic-bond subline → diagram → legend.

So the formula/name sits above the Lewis-dot diagram in every case.

## Data Flow

Pure view reordering + a badge-threshold constant. No model/state involvement.

## Error / Edge Handling

- Homonuclear covalent (e.g. N₂): `nPeripheral` may be 1 → no "×N" badge (single
  peripheral), which is correct.
- `nPeripheral > 4` still collapses to one drawn peripheral + the badge (existing
  behavior); the badge now also appears for 2–4.

## Testing

View-layer reordering; no unit test. Verify by running the app:
- Covalent (e.g. C+O): formula + name appear above the dot diagram; a "×2" badge
  shows on the diagram.
- Metallic (e.g. Na+Mg): symbol + "…metallic bond" above the electron-sea
  diagram; legend below.
- Ionic unchanged: formula + name above the BEFORE/AFTER diagram.

## Files

- Modify: `ChemInteractive/Views/Bridge/CovalentLewisView.swift` (reorder body,
  badge threshold > 1).
- Modify: `ChemInteractive/Views/Bridge/MetallicSeaView.swift` (reorder body).
- Unchanged: `BridgeView.swift` (ionic), `CanvasModel`, reducer.
