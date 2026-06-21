# Element Tray: Fit-to-Frame, Pinch-Zoom, and Detail Card

Date: 2026-06-21
Branch: feat/domain-logic-core

## Problem

The element tray (`ChemInteractive/Views/Tray/`) renders the full periodic
table as an 18-column grid of fixed 38×38pt tokens. At that size the grid is
~720pt wide — wider than the tray, which occupies 45% of screen height. The
user must scroll/swipe horizontally to reach an element, and there is no way to
see the whole table at once. Small symbols are also hard to read, and there is
no enlarged view of a tapped element.

## Goals

1. The whole periodic table fits inside the tray with no horizontal scroll at
   the default zoom level.
2. The user can pinch-zoom to read small symbols and pan when zoomed in.
3. Tapping an element (or polyatomic ion) shows an enlarged detail card.
4. Dragging an element into a drop slot happens from the detail card (a large
   target), since tiny grid tokens are too small to drag reliably.

## Non-Goals

- No slider/arrow navigation control (explicitly rejected in favor of
  fit + zoom).
- No carousel/paging interaction.
- No change to the drop-zone / bond-resolution logic in `CanvasModel` or
  `DropZoneView`. Both existing placement paths are preserved:
  - tap-select (`model.select`) then tap-slot-to-place, and
  - drag a `TokenTransfer` onto a `.dropDestination`.

## Current State (reference)

- `ElementTrayView` — header with tab buttons + legend; `ScrollView([.horizontal,
  .vertical])` wrapping `elementsGrid` (a `Grid` of 7 periods × 18 groups plus
  two f-block `HStack` rows) or `polyatomicGrid` (single `HStack`).
- `ElementTokenView` — 38×38 token: corner mass/atomic numbers + symbol
  (size 14). `.draggable(token)` + `.onTapGesture { model.select(token) }`.
- `PolyatomicTokenView` — formula token, height 64. Same drag + tap-select.
- Hosted in `ChemCanvasView` at `height: geo.size.height * 0.45`.
- `Element` model exposes: `symbol`, `name`, `atomicNumber`, `massNumber`,
  `atomicMass`, `category`, `elementClass`, `oxidationStates`,
  `electronConfiguration`.
- `elementClassColor(_:)` / `bondHint(...)` helpers already exist and are used
  by the token views.

## Design

### Component 1 — Fit-to-frame sizing

Wrap the grid content in a `GeometryReader` so the cell size is derived from the
available tray area rather than fixed at 38pt.

- Columns = 18, spacing = 2. Logical rows = 9 (7 periods + 2 f-block rows).
- `widthFit  = (W - 17 * spacing) / 18`
- `heightFit = (H - 8 * spacing - divider/labelAllowance) / 9`
- `cell = floor(min(widthFit, heightFit))`, clamped to a sane minimum (e.g.
  18pt) so the table never collapses to nothing on very small frames.
- Symbol font size scales with the cell: `cell * 0.37` (preserves today's
  14/38 ratio). Corner mass/atomic-number font scales proportionally.
- **Legibility threshold:** when `cell` is below a threshold (e.g. < 28pt),
  hide the corner atomic/mass numbers and render the symbol only, so the symbol
  stays readable. The full numbers remain available in the detail card.

`cell` and the derived font sizes are passed down to `ElementTokenView`
(new parameters with defaults) so the token renders at the computed size. Empty
grid cells use `Color.clear.frame(width: cell, height: cell)`. The f-block rows
and their `6f`/`7f` labels use the same `cell`.

At default zoom the computed `cell` makes the entire table fit the tray with no
scrolling.

### Component 2 — Pinch-zoom and pan

- Add `@State private var zoom: CGFloat = 1` (plus a gesture-tracking
  `@GestureState` for the in-progress magnification) to `ElementTrayView`.
- Apply `.scaleEffect(zoom, anchor: .topLeading)` to the grid content. (Anchor
  is `.topLeading`, not `.center`: it pins content to the scroll origin so
  panning works naturally when zoomed; `.center` fights the ScrollView's
  content-origin panning model.)
- `MagnificationGesture` updates the committed `zoom`, clamped to `1...4`.
- Keep the existing `ScrollView([.horizontal, .vertical])`. At `zoom == 1` the
  content fits, so there is nothing to scroll; at `zoom > 1` the scaled content
  overflows and the user pans by dragging.
- Double-tap on the grid background resets `zoom` to `1` (animated).

### Component 3 — Element detail card

New file `ChemInteractive/Views/Tray/ElementDetailCard.swift`.

- Presentation: `ElementTrayView` holds `@State private var detailElement:
  Element?` (and a parallel `detailIon: PolyatomicIon?`). The card is shown as
  an `.overlay` on the tray (or a `.sheet`/popover — overlay preferred to keep
  it inside the tray bounds) with a dimmed tap-catcher behind it that dismisses
  on tap.
- Card contents (element): large symbol in `elementClassColor`, element name,
  atomic number, mass number, element class label, oxidation states. Layout is
  a compact card (~ 240–280pt wide), centered.
- Card is the **drag source**: `.draggable(TokenTransfer(symbol:
  element.symbol, isPolyatomic: false)) { preview }`.
- Card also has a primary action button ("Use" / "Select") that calls the
  existing select path (`model.select(token)`) and dismisses, so tap-to-place
  still works for users who prefer it.
- An explicit close affordance (X) plus background tap dismiss.
- Respects `draggingDisabled` (canvas phase `.animatingCrossover`): when
  disabled, the drag source and select button are inactive, matching current
  token behavior.

### Component 4 — Token tap wiring + polyatomic parity

- `ElementTokenView`: `.onTapGesture` now requests the detail card
  (via a closure passed from `ElementTrayView`, e.g. `onTap: (Element) ->
  Void`) instead of selecting directly. Remove `.draggable` from the tiny grid
  token (drag now originates from the card). The selected/hint/disabled visual
  states remain.
- `PolyatomicTokenView`: same change — tap opens a detail card variant showing
  the ion formula (large) and name; drag originates from that card. The
  polyatomic grid keeps its single-row layout (no width problem there) but
  gains the unified tap→card interaction.

## Data Flow

1. `ElementTrayView` computes `cell` + font sizes from `GeometryReader`.
2. Tokens render at `cell` size; tapping a token calls back into
   `ElementTrayView`, which sets `detailElement` / `detailIon`.
3. The overlay card renders for that element/ion.
4. User either drags the `TokenTransfer` from the card to a `DropZoneView`
   (`.dropDestination` consumes it → `model.place`), or taps the card's
   select button (`model.select`) then taps a slot.
5. `CanvasModel` placement/bond logic is unchanged.

## Error / Edge Handling

- Minimum cell clamp prevents zero/negative sizes on tiny frames.
- Zoom clamped to `1...4`; double-tap reset guarantees an escape from a
  zoomed-in state.
- Card dismiss always available (background tap + X) so the user is never
  trapped in the overlay.
- `draggingDisabled` honored in the card (no drag/select during crossover
  animation).
- Only one card at a time: opening a new element's card replaces the current
  `detailElement`/`detailIon`.

## Testing

- This is a SwiftUI view layer; logic changes are minimal. Verify manually in
  the running app (and via the DEBUG direct-to-diagram launch argument where
  useful):
  - Full table visible with no horizontal scroll at default zoom on the target
    device size(s).
  - Pinch zoom in/out within bounds; pan when zoomed; double-tap resets.
  - Tap element → card with correct data; corner numbers hidden below the
    threshold but present in the card.
  - Drag from card → element lands in slot; select button + tap-slot path also
    works.
  - Polyatomic tab: tap → card → drag/select works.
  - Crossover-animation phase disables card drag/select.
- Any extractable pure helper (e.g. the cell-size computation) can be factored
  into a small function and unit-tested if desired.

## Files

- New: `ChemInteractive/Views/Tray/ElementDetailCard.swift`
- Modify: `ChemInteractive/Views/Tray/ElementTrayView.swift`
- Modify: `ChemInteractive/Views/Tray/ElementTokenView.swift`
- Modify: `ChemInteractive/Views/Tray/PolyatomicTokenView.swift`
- Unchanged: `CanvasModel.swift`, `DropZoneView.swift`, `ChemCanvasView.swift`
