# Bridge: Contrast Fix + Bond-Type Explanation Popup

Date: 2026-06-21
Branch: feat/domain-logic-core

## Problem

The bonding-result views in `ChemInteractive/Views/Bridge/` render most labels at
`white opacity 0.25–0.5` on the dark background — the bond-type labels, the
BEFORE/AFTER captions, formula sublines, and legends are hard to read. Also,
once the result diagram is shown, the explanation of *what the bonding means*
(available only during the `.explaining` modal) is gone. The user wants the
bond-type label to be readable AND tappable, opening a popup that explains the
bond (for covalent: how many bonding pairs, lone pairs, etc.).

## Goals

1. Raise the contrast of faint text across the three result diagrams.
2. Make the bond-type label a clearly readable, tappable control with an ⓘ
   affordance.
3. Tapping the label opens a compact dismissible info card explaining the bond
   type; covalent shows bonding-pair and lone-pair counts.
4. Share one explanation text source between the existing `.explaining` modal
   and the new info card (no duplicated wording).

## Non-Goals

- No change to the bonding logic, the reducer, or `CanvasModel`.
- No change to the diagrams' geometry/layout (atom circles, dots, animation).
- No new explanation content beyond what the existing modal already conveys,
  plus the covalent pair/lone-pair counts derived from the existing layout.

## Current State (reference)

- `BridgeView` switches on `canvasPhase`: `.complete` → `BondingDiagramView`
  (ionic), `.showingCovalent` → `CovalentLewisView`, `.showingMetallic` →
  `MetallicSeaView`. Each wraps the diagram + `ResetButton`.
- Faint labels:
  - `BondingDiagramView`: "BEFORE"/"AFTER" `white 0.35`, "IONIC BOND"
    `white 0.45`, connectors `white 0.7–0.75`.
  - `CovalentLewisView`: "COVALENT BOND" `white 0.35`, formula subline
    `white 0.4`, bond lines `white 0.25`.
  - `MetallicSeaView`: "METALLIC BOND" `white 0.35`, subline `white 0.4`,
    legend `white 0.5`.
- `ExplanationModalView` (shown at `.explaining`) has `summary(_ bonding:_ a:_ b:)`
  with ionic / covalent / metallic explanation `Text`. `BondingType` cases:
  `.ionic`, `.covalent`, `.metallic`. Helpers: `electronsNeeded(_:)`,
  `chargeExplanation(_:)`, `ionicPair`, `ionicFormula`, `covalentLayout(slotA:slotB:)`
  returning `bondOrder`, `nPeripheral`, `centralIsA`, `centralLone`,
  `peripheralLone`.
- `ElementDetailCard.swift` contains a private `CardChrome<Content>` (dim
  backdrop + panel + X + tap-to-dismiss) used by the element/polyatomic cards.

## Design

### Component 1 — Shared `CardChrome`

Extract the private `CardChrome` from `ElementDetailCard.swift` into a new
`ChemInteractive/Views/Shared/CardChrome.swift`, made internal (no `private`),
unchanged in behavior. `ElementDetailCard`/`PolyatomicDetailCard` keep using it;
the new bonding info card reuses it. Card width stays a parameter or default
(260); the bonding card may pass a slightly wider value if needed.

### Component 2 — `bondingExplanation` provider

New `ChemInteractive/Views/Bridge/BondingExplanation.swift`:

- `func bondingExplanation(_ bonding: BondingType, _ a: ZoneState, _ b: ZoneState) -> String`
  returning the prose used today by `ExplanationModalView.summary` for each
  bond type:
  - ionic: the crossover/charge-transfer sentence (without the SwiftUI
    bold-formula concatenation — return a plain string including the formula).
  - covalent: octet-sharing sentence PLUS pair counts (see below).
  - metallic: the electron-sea sentence (homonuclear vs alloy variants).
- For covalent, also expose the structured counts via a small helper
  `covalentPairSummary(_ a: ZoneState, _ b: ZoneState) -> String` derived from
  `covalentLayout(slotA: a, slotB: b)`:
  - bonding pairs per bond = `bondOrder` (1 single / 2 double / 3 triple),
  - number of bonds = `nPeripheral`,
  - lone pairs on central = `centralLone`, on each peripheral =
    `peripheralLone`.
  - Example string: "Each bond shares 2 pairs (double); 2 bonds total; C has
    0 lone pairs, each O has 2."
- `ExplanationModalView.summary` is refactored to call
  `bondingExplanation(...)` so both surfaces share the wording. (The modal's
  ionic case currently builds a bold-formula `Text`; after refactor it shows
  the same plain string from the provider, or keeps a bold formula by
  composing `Text(provider string)` — acceptable either way as long as the
  wording comes from the provider.)

### Component 3 — `BondingInfoCard`

New `ChemInteractive/Views/Bridge/BondingInfoCard.swift`:

- `struct BondingInfoCard: View` — init `(bonding: BondingType, a: ZoneState,
  b: ZoneState, onClose: () -> Void)`.
- Renders inside `CardChrome`: a title (`Ionic / Covalent / Metallic Bonding`),
  the `bondingExplanation(...)` body text (size ~13, `Theme.text` /
  `Theme.text.opacity(0.85)` for good contrast), and for covalent the
  `covalentPairSummary` line. Dismisses via backdrop tap + X (from CardChrome).

### Component 4 — `BondTypeLabel`

New `ChemInteractive/Views/Bridge/BondTypeLabel.swift`:

- `struct BondTypeLabel: View` — init `(bonding: BondingType, a: ZoneState,
  b: ZoneState)`.
- Renders the bond name (e.g. "Ionic bond" / "Covalent bond" / "Metallic
  bond") at high contrast — `Theme.text.opacity(0.85)`, size 10, tracking 2,
  with a trailing `Image(systemName: "info.circle")` to signal tappable.
- Owns `@State private var showInfo = false`; `.onTapGesture { showInfo = true }`.
- Presents `BondingInfoCard(bonding:a:b:) { showInfo = false }` as an
  `.overlay` (full-screen via CardChrome's backdrop) when `showInfo`.
- Replaces the three inline faint labels:
  - `BondingDiagramView` "IONIC BOND" (both `lewisTransferView` and
    `simpleIonView`) → `BondTypeLabel(bonding: .ionic, a: cat, b: an)`.
  - `CovalentLewisView` "COVALENT BOND" → `BondTypeLabel(bonding: .covalent,
    a: slotA, b: slotB)`.
  - `MetallicSeaView` "METALLIC BOND" → `BondTypeLabel(bonding: .metallic,
    a: slotA, b: slotB)`.

### Component 5 — Contrast bumps

In the three diagram files, raise the remaining faint text (NOT the bond-type
label, now handled by `BondTypeLabel`):
- BEFORE/AFTER: `white 0.35 → 0.6`.
- formula sublines: `white 0.4 → 0.7`.
- legends (`MetallicSeaView`): `white 0.5 → 0.7`.
- connectors (`+`, `→`, `↔`): `white 0.7 → 0.85`.
- bond lines (`CovalentLewisView.bond`): `white 0.25 → 0.4`.
Decorative dots / lone-pair / atom strokes left as-is.

## Data Flow

`BondTypeLabel` reads the two `ZoneState`s passed in and toggles local
`showInfo`. `BondingInfoCard` calls `bondingExplanation(...)` /
`covalentPairSummary(...)` — pure functions of the two zones plus
`covalentLayout`. No model mutation; nothing touches the reducer.

## Error / Edge Handling

- Info card always dismissible (backdrop + X) — no trap.
- Covalent counts come from `covalentLayout`, the same source the diagram
  already renders, so the popup matches the picture.
- Polyatomic ionic pairs: ionic explanation uses the existing `ionicPair` /
  `ionicFormula` path, unchanged.
- One info card at a time per label (local state); switching phases tears down
  the diagram (and its label) entirely.

## Testing

- Unit-test `BondingExplanation.swift` (pure):
  - covalent pair summary for a known pair (e.g. C+O or H+O) asserts the
    bonding-pair count = `bondOrder` and lone-pair counts match `covalentLayout`.
  - `bondingExplanation` returns non-empty, bond-type-appropriate text for
    ionic / covalent / metallic (e.g. ionic string contains the crossover
    formula; metallic mentions the electron sea).
- View/contrast changes verified by running the app:
  - All three diagrams: bond-type label readable with an ⓘ; tapping opens the
    info card with correct explanation; covalent card shows pair/lone counts;
    dismiss works.
  - Faint captions/legends/connectors are visibly more legible.
  - The `.explaining` modal still shows the same wording (shared provider).

## Files

- New: `ChemInteractive/Views/Shared/CardChrome.swift` (extracted, internal).
- New: `ChemInteractive/Views/Bridge/BondingExplanation.swift` (+ test
  `ChemInteractiveTests/BondingExplanationTests.swift`).
- New: `ChemInteractive/Views/Bridge/BondingInfoCard.swift`.
- New: `ChemInteractive/Views/Bridge/BondTypeLabel.swift`.
- Modify: `ChemInteractive/Views/Tray/ElementDetailCard.swift` (drop private
  CardChrome, use shared).
- Modify: `ChemInteractive/Views/Bridge/BondingDiagramView.swift`,
  `CovalentLewisView.swift`, `MetallicSeaView.swift` (labels + contrast).
- Modify: `ChemInteractive/Views/Bridge/ExplanationModalView.swift` (use
  shared provider).
- Unchanged: `CanvasModel`, reducer, `CrossoverAnimatorView`, `ResetButton`.
