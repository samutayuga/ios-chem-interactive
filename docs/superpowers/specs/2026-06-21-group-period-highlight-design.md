# Tray: Group/Period Highlight on Element Tap

Date: 2026-06-21
Branch: feat/domain-logic-core

## Problem

Tapping a periodic-table element opens the detail card but gives no sense of
*where* the element sits in the table. We want tapping an element to also
highlight its group (column) and period (row) in the grid and show the group
name + period number on the card — reinforcing periodic-table structure.

## Goals

1. Tapping an element highlights every filled cell sharing its group OR its
   period; the tapped cell stays distinctly marked.
2. The highlight is visible *while the detail card is open* (the trigger and
   lifetime are the same single tap that opens the card).
3. The card shows `Group N · <traditional name>` and `Period N`.
4. Works with mouse-click-only (macOS simulator): a single tap/click is the
   only gesture required — no hover, long-press, or multi-touch.

## Non-Goals

- No persistent/independent highlight selection — it lives exactly as long as
  the card is open (dismiss clears it).
- No highlight for polyatomic ions (they have no group/period); the polyatomic
  card is unchanged.
- No change to `CanvasModel`, the reducer, or bonding logic.
- f-block (lanthanide/actinide) tokens highlight by period only (they sit
  outside the 1–18 columns).

## Current State (reference)

- `ElementTrayView` holds `@State detailElement: Element?` / `detailIon:
  PolyatomicIon?`; the grid `ForEach(1...7) period { ForEach(1...18) group { ... } }`
  renders `ElementTokenView(element:hint:disabled:metrics:onTap:)`, empty cells
  are `Color.clear.frame(width: m.cell, height: m.cell)`. Two f-block rows via
  `fBlockRow(_:label:_:)`. The detail card is shown as a tray `.overlay`.
- `ElementTokenView` renders the token with a selected ring
  (`model.selectedToken == token`), a hint tint, and `disabled` dimming.
- `ElementDetailCard` (in `ElementDetailCard.swift`) shows the atom glyph,
  name, `elementClass.rawValue`, `category.rawValue`, electron configuration,
  oxidation states — wrapped in the shared `CardChrome`.
- `CardChrome` (in `Views/Shared/CardChrome.swift`) is shared by
  `ElementDetailCard`, `PolyatomicDetailCard`, and `BondingInfoCard`; its
  backdrop is a hard-coded `Color.black.opacity(0.55)`.
- `Element` exposes `group: Int`, `period: Int`, `atomicNumber`.

## Design

### Component 1 — `PeriodicNaming` helper

New `ChemInteractive/Theme/PeriodicNaming.swift`:

- `func periodicGroupName(for el: Element) -> String` returning the traditional
  group name with the IUPAC number:
  - z in 57…71 → "Lanthanides"; z in 89…103 → "Actinides" (no group number).
  - else by `el.group`: 1 → "Group 1 · Alkali metals" (special-case H, z==1 →
    "Group 1"), 2 → "Group 2 · Alkaline earth metals", 3…12 → "Group N ·
    Transition metals", 13 → "Group 13 · Boron group", 14 → "Group 14 · Carbon
    group", 15 → "Group 15 · Pnictogens", 16 → "Group 16 · Chalcogens", 17 →
    "Group 17 · Halogens", 18 → "Group 18 · Noble gases".
- Pure; unit-tested.

### Component 2 — Grid highlight

- `ElementTrayView` derives the highlight from `detailElement` (no new state):
  - `selGroup = detailElement?.group`, `selPeriod = detailElement?.period`.
  - A token is `axisHighlighted` when `detailElement != nil` and
    (`el.group == selGroup || el.period == selPeriod`).
  - f-block tokens use period match only (their `group` is not a 1–18 column).
- `ElementTokenView` gains `var axisHighlighted: Bool = false`. When true (and
  not the disabled/inactive branch), it draws an accent wash behind the token —
  e.g. an extra `RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.18))`
  layered under the existing background, and/or a stronger border. The exact
  tapped cell (`el.atomicNumber == detailElement?.atomicNumber`) gets a stronger
  ring (`Theme.accent.opacity(0.9)`, lineWidth 2) so it stands out from its row/
  column. Empty grid cells stay `Color.clear` (bands appear only across filled
  cells — acceptable given the table's natural gaps).
- The highlight only renders while `detailElement != nil`; dismissing the card
  (sets `detailElement = nil`) clears it automatically.

### Component 3 — Card backdrop made visible-through

`CardChrome` gains a `dim` parameter (default `0.55`, preserving current
behavior for `PolyatomicDetailCard` and `BondingInfoCard`). `ElementDetailCard`
passes a light dim (`0.15`) so the highlighted grid shows through behind the
card. The card panel itself keeps its solid `Theme.surface` background, so its
own contents stay fully readable over the lighter backdrop.

### Component 4 — Card group/period lines

`ElementDetailCard` adds two lines (near the name/class block):
- `Text(periodicGroupName(for: element))` (size 12, `Theme.text.opacity(0.8)`).
- `Text("Period \(element.period)")` (size 12, `Theme.text.opacity(0.8)`).

## Data Flow

`ElementTrayView` reads `detailElement`, computes per-token `axisHighlighted`,
passes it into `ElementTokenView`. The card reads the same `detailElement` for
its group/period lines. Nothing mutates the model; the reducer is untouched.

## Error / Edge Handling

- No element tapped (`detailElement == nil`): no highlight, normal grid.
- Polyatomic tap (`detailIon`): no group/period highlight; polyatomic card and
  its default `0.55` dim unchanged.
- f-block element: highlight by period; group name shows "Lanthanides"/
  "Actinides" with no group number.
- H (z==1, group 1): group name "Group 1" (no "Alkali metals" label).
- Dismiss always clears the highlight (state back to nil).

## Testing

- Unit-test `PeriodicNaming.swift`:
  - representative groups: Na (1 → "Alkali metals"), Ca (2), Fe (3…12 →
    "Transition metals"), C (14 → "Carbon group"), N (15 → "Pnictogens"),
    O (16 → "Chalcogens"), Cl (17 → "Halogens"), Ne (18 → "Noble gases").
  - H → "Group 1" (no alkali label).
  - La (57) → "Lanthanides"; U (92) → "Actinides".
- View behavior verified by running the app (single click):
  - Tap an element → its column + row of filled cells wash with accent; the
    tapped cell is distinct; the highlight is visible behind the (lightly
    dimmed) card.
  - Card shows correct group name + period.
  - Dismiss clears the highlight.
  - Polyatomic tab: no highlight, card backdrop unchanged.

## Files

- New: `ChemInteractive/Theme/PeriodicNaming.swift` (+ test
  `ChemInteractiveTests/PeriodicNamingTests.swift`).
- Modify: `ChemInteractive/Views/Shared/CardChrome.swift` (add `dim` param).
- Modify: `ChemInteractive/Views/Tray/ElementTokenView.swift` (add
  `axisHighlighted`).
- Modify: `ChemInteractive/Views/Tray/ElementTrayView.swift` (compute + pass
  highlight).
- Modify: `ChemInteractive/Views/Tray/ElementDetailCard.swift` (light dim +
  group/period lines).
- Unchanged: `CanvasModel`, reducer, polyatomic/bonding cards' behavior.
