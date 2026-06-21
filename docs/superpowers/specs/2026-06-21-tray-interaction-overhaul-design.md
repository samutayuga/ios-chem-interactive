# Tray Interaction Overhaul

Date: 2026-06-21
Branch: feat/domain-logic-core

## Problem

Several tray/placement usability issues:
1. **Three taps to place via tap-flow**: tap element (opens card) → tap "Select"
   in the card → tap the zone. Should be two: tap element (selects) → tap zone.
2. The empty drop zone's pending cue is the sentence "Tap to place Na"; a symbol
   would be more intuitive.
3. No way to inspect an element's group/period without committing a tap; pointing
   (hover) should preview group + period and highlight them.
4. The detail card carries text that's now redundant — group/period lines, the
   "Select" button, and the "Drag the symbol to a slot" hint.

## Goals

1. Tap element → it is selected AND the detail card shows; tap a drop zone →
   places. Two steps. Drag-from-card remains as an alternative.
2. The detail card is non-modal so the zone tap lands while it's shown.
3. Empty drop zone pending cue = pending symbol + a tap icon (no sentence).
4. Hovering an element shows a header tooltip (group/period) and highlights its
   group column + period row, without tapping.
5. Card decluttered: no group/period lines, no Select button, no drag hint.

## Non-Goals

- No `CanvasModel`/reducer/bonding changes (uses existing `select`, `place`,
  `clearSelection`, `selectedToken`).
- No change to the polyatomic/bonding cards' modality (they stay blocking).
- Hover is best-effort: `.onHover` requires a pointer and may not fire in the
  iOS Simulator; the tap path must remain fully functional without it.

## Current State (reference)

- `ElementTokenView.onTapGesture { onTap(element) }` → `ElementTrayView` sets
  `detailElement = element` (card only; selection happens via the card's
  "Select" button). Token dims to 0.5 when `model.selectedToken != nil &&
  !isSelected`.
- `ElementDetailCard` / `PolyatomicDetailCard` wrap content in `CardChrome`
  (shared, `Views/Shared/CardChrome.swift`) with a `dim` param; element card
  uses `dim: 0.15`. Each card has: atom/formula glyph (`.draggable` when
  `!disabled`), name/class/category, electron config + oxidation (element),
  `Group N · …`/`Period N` lines (element), and a bottom `if !disabled { HStack
  { Text("Drag the symbol/formula to a slot, or"); Button("Select"){ model.select;
  onClose } } }`.
- `CardChrome` backdrop: `Color.black.opacity(dim).ignoresSafeArea().onTapGesture
  { onClose() }` (intercepts taps → modal).
- `ElementTrayView`: `@State detailElement: Element?` / `detailIon:
  PolyatomicIon?`; `.overlay` shows the card; grid passes `axisHighlighted`/
  `focused` derived from `detailElement`; header has tabs + legend + Spacer.
- `DropZoneView` pending branch: `Text("Tap to place \(symbol)")`; idle branch:
  `Image(systemName: "drop")`. Tap-to-place: `if let token = model.selectedToken,
  !dropDisabled { model.place(token, in: slot) }`.
- `model.place(_:in:)` clears the selection; `model.select(_:)` toggles
  (same token → deselect); `periodicGroupName(for:)` + `element.period` exist.

## Design

### Component 1 — `CardChrome` blocking flag

Add `var blocking: Bool = true` to `CardChrome`. When `false`:
- the dim layer gets `.allowsHitTesting(false)` (taps pass through to the views
  beneath, e.g. drop zones), and
- the backdrop's `.onTapGesture { onClose() }` is omitted (a pass-through
  backdrop can't receive it anyway).
The card panel (drag handle, X button) is always interactive. `blocking: true`
preserves today's modal behavior for `PolyatomicDetailCard` and
`BondingInfoCard`.

### Component 2 — Select-on-tap + non-modal element card + auto-dismiss

- `ElementTrayView` element-token `onTap` closure becomes: `detailElement = el;
  model.select(TokenTransfer(symbol: el.symbol, isPolyatomic: false))`.
  Polyatomic `onTap`: `detailIon = ion; model.select(TokenTransfer(symbol:
  ion.symbol, isPolyatomic: true))`.
- `ElementDetailCard` / `PolyatomicDetailCard` pass `blocking: false` to
  `CardChrome` (element card keeps `dim: 0.15`; the polyatomic card uses a light
  dim too for consistency, `dim: 0.15`).
- Auto-dismiss: `ElementTrayView` adds `.onChange(of: model.selectedToken) { _,
  new in if new == nil { detailElement = nil; detailIon = nil } }`. So placing
  (which clears the selection) or deselecting hides the card.
- The card's X button now clears selection too: `onClose` for these cards sets
  the state nil AND calls `model.clearSelection()`. (Implement by having the
  tray pass an `onClose` that does both, or call `clearSelection` in the button;
  simplest: the tray's overlay closure does `detailElement = nil;
  model.clearSelection()`.)
- Net flow: tap element → selected + card; tap zone → `model.place` →
  selection clears → card auto-dismisses, element placed. Two taps.

### Component 3 — Card declutter

In `ElementDetailCard`: remove the `Group N · …` and `Period N` lines, and
remove the entire bottom `if !disabled { HStack { … "Drag the symbol…" …
Button("Select") … } }` block. Keep the draggable atom glyph, name, class,
category, electron config, oxidation states, and the X (via CardChrome).
In `PolyatomicDetailCard`: remove the bottom `if !disabled { HStack { … "Drag
the formula…" … Button("Select") … } }` block. Keep the draggable formula
glyph, name, charge, X.
(The glyph remains `.draggable` when `!disabled`, so drag-to-slot still works.)

### Component 4 — Empty drop-zone pending cue

In `DropZoneView.content`, the pending-selection branch (`hasPendingSelection`)
renders, instead of the sentence:

```swift
VStack(spacing: 4) {
    Text(model.selectedToken!.symbol)
        .font(.system(size: 20, weight: .bold)).foregroundStyle(accent)
    Image(systemName: "hand.tap").font(.system(size: 16)).foregroundStyle(accent.opacity(0.8))
}
```

Idle branch (droplet icon) unchanged.

### Component 5 — Hover tooltip + highlight

- `ElementTokenView` gains `var onHover: (Bool) -> Void = { _ in }` and applies
  `.onHover { onHover($0) }` to the interactive token.
- `ElementTrayView` adds `@State private var hoveredElement: Element?`. Element
  tokens pass `onHover: { hoveredElement = $0 ? el : (hoveredElement?.atomicNumber
  == el.atomicNumber ? nil : hoveredElement) }`.
- The highlight source becomes `hoveredElement ?? detailElement`: the
  `axisHighlighted(_:)`/`isFocused(_:)` helpers use this coalesced element so
  pointing highlights immediately and tapping still highlights.
- Header tooltip: when `hoveredElement != nil`, the header strip shows
  `Text("\(el.symbol) · \(periodicGroupName(for: el)) · Period \(el.period)")`
  (small, `Theme.text.opacity(0.8)`), placed after the legend / before the
  Spacer; hidden otherwise.

## Data Flow

Tap → `detailElement`/`detailIon` + `model.select`. The non-modal card lets a
subsequent zone tap reach `DropZoneView` → `model.place` → selection cleared →
`onChange` nils the card state. Hover sets `hoveredElement` (view-local) driving
highlight + header tooltip. No model mutation beyond the existing `select`/
`place`/`clearSelection`.

## Error / Edge Handling

- Tap same element again → `model.select` toggles to nil → card auto-dismisses
  (deselect). Tap a different element → selection swaps, card swaps.
- Drag-from-card still works (glyph draggable). Dragging also goes through
  `model.place` via `dropDestination`, clearing selection → card dismisses.
- `dropDisabled` (crossover/explaining): zone taps inert (existing guard); the
  card glyph is non-draggable when `disabled`.
- Hover unsupported (no pointer): `hoveredElement` stays nil; everything else
  works via tap.
- Non-modal card with no backdrop tap-to-dismiss: X button (clears selection)
  and placing both dismiss; the card never traps because selection-clear nils it.

## Testing

- `CardChrome` `blocking` flag: pure-ish; verify via build + the existing app
  behavior (modal cards still dim/block, element card passes touches). No unit
  test feasible for hit-testing; covered in manual verification.
- Manual (running app):
  1. Tap element → it highlights as selected, card appears, other tokens dim.
  2. Tap a drop zone → element placed, card disappears — **two taps total**.
  3. Card X → selection cleared, card gone, no placement.
  4. Empty zone with a pending selection shows the symbol + tap icon.
  5. Pointing (if hover fires) → header shows group/period, group+period
     highlight; moving away clears it; no tap needed.
  6. Card no longer shows group/period, Select, or the drag-hint text; drag from
     the glyph still places.
  7. Polyatomic + bonding cards still behave as before (modal), minus the
     removed Select/hint.

## Files

- Modify: `ChemInteractive/Views/Shared/CardChrome.swift` (add `blocking`).
- Modify: `ChemInteractive/Views/Tray/ElementDetailCard.swift` (non-modal, drop
  group/period + Select + drag-hint).
- Modify: `ChemInteractive/Views/Tray/ElementTokenView.swift` (add `onHover`).
- Modify: `ChemInteractive/Views/Tray/ElementTrayView.swift` (select-on-tap,
  hover state + header tooltip, coalesced highlight, auto-dismiss, onClose
  clears selection).
- Modify: `ChemInteractive/Views/Zones/DropZoneView.swift` (pending cue).
- Unchanged: `CanvasModel`, reducer, `BondingInfoCard` (stays blocking).
