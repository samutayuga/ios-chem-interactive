# Tray Interaction Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two-tap placement (tap element selects + shows a non-modal card → tap zone places), hover tooltip/highlight for group+period, a symbol cue on the empty drop zone, and a decluttered detail card.

**Architecture:** Add a `blocking` flag to the shared `CardChrome` so the element/polyatomic cards become non-modal (taps pass through to the zones). Tapping an element both selects it and shows the card; placing clears the selection, which auto-dismisses the card. Hover drives a header tooltip + group/period highlight. All view-layer; no model/reducer change.

**Tech Stack:** Swift, SwiftUI, XCTest. App target `ChemInteractive`, scheme `ChemInteractive`. These are view changes — no new pure functions, so each task's gate is BUILD SUCCEEDED + the existing full suite still passing, plus manual verification at the end. Test simulator: `iPhone 17 Pro`.

## Global Constraints

- No changes to `CanvasModel`, the reducer, or bonding logic. Uses existing `model.select(_:)`, `model.place(_:in:)`, `model.clearSelection()`, `model.selectedToken`, `periodicGroupName(for:)`.
- `CardChrome` default stays `blocking: true` (`PolyatomicDetailCard`'s and `BondingInfoCard`'s current modal behavior must be preserved unless explicitly changed); the element + polyatomic detail cards pass `blocking: false`, `dim: 0.15`.
- Tap an element ⇒ `detailElement = el` AND `model.select(TokenTransfer(symbol: el.symbol, isPolyatomic: false))`; polyatomic ⇒ `detailIon = ion` AND `model.select(TokenTransfer(symbol: ion.symbol, isPolyatomic: true))`.
- Card auto-dismiss: when `model.selectedToken` becomes `nil`, set `detailElement = nil; detailIon = nil`. The card's close (X / backdrop is non-interactive) clears the selection.
- Detail cards: NO group/period lines, NO "Select" button, NO "Drag the symbol/formula to a slot" hint. Keep the draggable glyph, name/class/category, e-config + oxidation (element), charge (ion), and the X.
- Empty drop zone, pending-selection branch: pending symbol (accent, size 20, bold) + `Image(systemName: "hand.tap")` (size 16, `accent.opacity(0.8)`) in a `VStack(spacing: 4)`. Idle droplet unchanged.
- Hover: `ElementTokenView` exposes `onHover: (Bool) -> Void`; highlight source = `hoveredElement ?? detailElement`; header strip shows `"<symbol> · <periodicGroupName> · Period <n>"` while hovering. `.onHover` requires a pointer (may not fire in the Simulator) — tap path must stay fully functional.

---

## File Structure

- `ChemInteractive/Views/Shared/CardChrome.swift` — add `blocking`.
- `ChemInteractive/Views/Tray/ElementDetailCard.swift` — declutter both cards + non-modal + drop unused `model`.
- `ChemInteractive/Views/Tray/ElementTokenView.swift` — add `onHover`.
- `ChemInteractive/Views/Tray/ElementTrayView.swift` — select-on-tap, auto-dismiss, onClose clears selection, hover state + tooltip, coalesced highlight.
- `ChemInteractive/Views/Zones/DropZoneView.swift` — pending cue.

---

## Task 1: CardChrome `blocking` flag

**Files:**
- Modify: `ChemInteractive/Views/Shared/CardChrome.swift`

**Interfaces:**
- Produces: `CardChrome(onClose:dim:blocking:content:)` — `blocking` defaults to `true`.

- [ ] **Step 1: Add the flag + conditional backdrop**

Replace the whole struct body in `ChemInteractive/Views/Shared/CardChrome.swift` with:

```swift
import SwiftUI

/// Shared dimmed backdrop + card chrome. When `blocking` is true the backdrop
/// intercepts taps and dismisses on tap; when false it lets taps pass through
/// to the views beneath (non-modal) and is dismissed via the X button.
struct CardChrome<Content: View>: View {
    let onClose: () -> Void
    var dim: Double = 0.55
    var blocking: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            backdrop
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(16)
            .frame(width: 260)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(8)
            }
            .shadow(radius: 20)
        }
    }

    @ViewBuilder private var backdrop: some View {
        if blocking {
            Color.black.opacity(dim).ignoresSafeArea().onTapGesture { onClose() }
        } else {
            Color.black.opacity(dim).ignoresSafeArea().allowsHitTesting(false)
        }
    }
}
```

- [ ] **Step 2: Build + run full suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED; all tests pass (default `blocking: true` keeps every existing call site unchanged).

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Shared/CardChrome.swift
git commit -m "feat: add non-blocking option to CardChrome"
```

---

## Task 2: Declutter + non-modal detail cards

**Files:**
- Modify: `ChemInteractive/Views/Tray/ElementDetailCard.swift`

**Interfaces:**
- Consumes: `CardChrome(... blocking:)` (Task 1).
- Produces: `ElementDetailCard` / `PolyatomicDetailCard` are non-modal, decluttered. Note: after this task the cards no longer reference `model` or `token` for selection, but the glyph still uses `token` for `.draggable`; `model` is removed.

- [ ] **Step 1: ElementDetailCard — non-modal, drop group/period + Select/hint**

In `ChemInteractive/Views/Tray/ElementDetailCard.swift`:

Change the CardChrome call (line ~15) from `CardChrome(onClose: onClose, dim: 0.15) {` to `CardChrome(onClose: onClose, dim: 0.15, blocking: false) {`.

Remove the two lines in the name VStack:
```swift
                    Text(periodicGroupName(for: element))
                        .font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.8))
                    Text("Period \(element.period)")
                        .font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.8))
```
(so the VStack ends after the `category` line).

Remove the entire bottom block:
```swift
            if !disabled {
                HStack(spacing: 10) {
                    Text("Drag the symbol to a slot, or")
                        .font(.system(size: 11)).foregroundStyle(Theme.text.opacity(0.7))
                    Button("Select") { model.select(token); onClose() }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .foregroundStyle(Theme.accent)
                        .overlay(Capsule().stroke(Theme.accent, lineWidth: 1))
                }
            }
```

Remove the now-unused environment property `@Environment(CanvasModel.self) private var model` from `ElementDetailCard` (the struct no longer calls `model`). Keep `private var token` (used by `.draggable`) and `glyphColor`.

- [ ] **Step 2: PolyatomicDetailCard — non-modal, drop Select/hint**

In the same file, change `PolyatomicDetailCard`'s `CardChrome(onClose: onClose) {` to `CardChrome(onClose: onClose, dim: 0.15, blocking: false) {`.

Remove its bottom block:
```swift
            if !disabled {
                HStack(spacing: 10) {
                    Text("Drag the formula to a slot, or")
                        .font(.system(size: 11)).foregroundStyle(Theme.text.opacity(0.7))
                    Button("Select") { model.select(token); onClose() }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .foregroundStyle(Theme.accent)
                        .overlay(Capsule().stroke(Theme.accent, lineWidth: 1))
                }
            }
```

Remove the now-unused `@Environment(CanvasModel.self) private var model` from `PolyatomicDetailCard`. Keep `private var token` (used by `.draggable`).

- [ ] **Step 3: Build + run full suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED; all tests pass. (If the `#Preview` for these cards referenced the model only for selection, it still builds; leave any `.environment(CanvasModel())` already present.)

- [ ] **Step 4: Commit**

```bash
git add ChemInteractive/Views/Tray/ElementDetailCard.swift
git commit -m "feat: non-modal, decluttered detail cards (no Select/hint/group-period)"
```

---

## Task 3: Select-on-tap, auto-dismiss, hover tooltip + highlight

**Files:**
- Modify: `ChemInteractive/Views/Tray/ElementTokenView.swift`
- Modify: `ChemInteractive/Views/Tray/ElementTrayView.swift`

**Interfaces:**
- Consumes: non-modal cards (Task 2), `periodicGroupName(for:)`.
- Produces: `ElementTokenView` gains `var onHover: (Bool) -> Void = { _ in }`. End of chain otherwise.

- [ ] **Step 1: Add `onHover` to ElementTokenView**

In `ChemInteractive/Views/Tray/ElementTokenView.swift`, add after `var focused: Bool = false`:

```swift
    var onHover: (Bool) -> Void = { _ in }
```

In the active (`else`) branch, add `.onHover` after `.onTapGesture`:

```swift
        } else {
            styled
                .opacity(model.selectedToken != nil && !isSelected ? 0.5 : 1)
                .onTapGesture { onTap(element) }
                .onHover { onHover($0) }
        }
```

- [ ] **Step 2: ElementTrayView — hover state + coalesced highlight**

In `ChemInteractive/Views/Tray/ElementTrayView.swift`, add the hover state after `@State private var detailIon`:

```swift
    @State private var hoveredElement: Element?
```

Replace the highlight helpers (the `axisHighlighted`/`isFocused` funcs) with versions keyed off a coalesced source:

```swift
    private var highlightSource: Element? { hoveredElement ?? detailElement }
    private func axisHighlighted(_ el: Element) -> Bool {
        guard let sel = highlightSource else { return false }
        let sameGroup = !isFBlock(el.atomicNumber) && !isFBlock(sel.atomicNumber) && el.group == sel.group
        return sameGroup || el.period == sel.period
    }
    private func isFocused(_ el: Element) -> Bool { highlightSource?.atomicNumber == el.atomicNumber }
```

- [ ] **Step 3: ElementTrayView — select-on-tap, auto-dismiss, onClose clears selection**

Replace the `.overlay { … }` block on the body with one whose closes also clear the selection:

```swift
        .overlay {
            if let el = detailElement {
                ElementDetailCard(element: el, disabled: draggingDisabled) {
                    detailElement = nil; model.clearSelection()
                }
            } else if let ion = detailIon {
                PolyatomicDetailCard(ion: ion, disabled: draggingDisabled) {
                    detailIon = nil; model.clearSelection()
                }
            }
        }
        .onChange(of: model.selectedToken) { _, newValue in
            if newValue == nil { detailElement = nil; detailIon = nil }
        }
```

Update the three token call sites to select on tap and report hover.

In `elementsGrid`, replace the `ElementTokenView(...)` call with:

```swift
                                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled,
                                                 metrics: m,
                                                 onTap: { detailElement = $0; model.select(TokenTransfer(symbol: $0.symbol, isPolyatomic: false)) },
                                                 axisHighlighted: axisHighlighted(el), focused: isFocused(el),
                                                 onHover: { hovering in
                                                     if hovering { hoveredElement = el }
                                                     else if hoveredElement?.atomicNumber == el.atomicNumber { hoveredElement = nil }
                                                 })
```

In `fBlockRow`, replace the `ElementTokenView(...)` call with:

```swift
                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled,
                                 metrics: m,
                                 onTap: { detailElement = $0; model.select(TokenTransfer(symbol: $0.symbol, isPolyatomic: false)) },
                                 axisHighlighted: axisHighlighted(el), focused: isFocused(el),
                                 onHover: { hovering in
                                     if hovering { hoveredElement = el }
                                     else if hoveredElement?.atomicNumber == el.atomicNumber { hoveredElement = nil }
                                 })
```

In `polyatomicGrid`, replace the `PolyatomicTokenView(...)` call with:

```swift
                PolyatomicTokenView(ion: ion, disabled: draggingDisabled,
                                    onTap: { detailIon = $0; model.select(TokenTransfer(symbol: $0.symbol, isPolyatomic: true)) })
```

- [ ] **Step 4: ElementTrayView — header tooltip**

Replace the `header` computed property with one that appends the hover tooltip:

```swift
    private var header: some View {
        HStack(spacing: 8) {
            tabButton("Elements", .elements)
            tabButton("Polyatomic Ions", .polyatomic)
            if firstSlot != nil { legend }
            if let h = hoveredElement {
                Text("\(h.symbol) · \(periodicGroupName(for: h)) · Period \(h.period)")
                    .font(.system(size: 10)).foregroundStyle(Theme.text.opacity(0.8)).lineLimit(1)
            }
            Spacer()
        }
    }
```

- [ ] **Step 5: Build + run full suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED; all tests pass.

- [ ] **Step 6: Commit**

```bash
git add ChemInteractive/Views/Tray/ElementTokenView.swift ChemInteractive/Views/Tray/ElementTrayView.swift
git commit -m "feat: select-on-tap, hover tooltip + highlight, card auto-dismiss"
```

---

## Task 4: Empty drop-zone tap cue

**Files:**
- Modify: `ChemInteractive/Views/Zones/DropZoneView.swift`

**Interfaces:**
- Consumes: nothing new. End of chain.

- [ ] **Step 1: Replace the pending-selection cue**

In `ChemInteractive/Views/Zones/DropZoneView.swift`, in the `content` view, replace the pending-selection branch:

```swift
        } else if hasPendingSelection {
            Text("Tap to place \(model.selectedToken!.symbol)")
                .font(.system(size: 13)).foregroundStyle(accent.opacity(0.8))
                .multilineTextAlignment(.center)
        } else {
```

with:

```swift
        } else if hasPendingSelection {
            VStack(spacing: 4) {
                Text(model.selectedToken!.symbol)
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(accent)
                Image(systemName: "hand.tap")
                    .font(.system(size: 16)).foregroundStyle(accent.opacity(0.8))
            }
        } else {
```

(The idle `else` branch — the droplet icon — is unchanged.)

- [ ] **Step 2: Build + run full suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED; all tests pass.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Zones/DropZoneView.swift
git commit -m "feat: symbol + tap icon cue on empty drop zone"
```

---

## Task 5: Manual verification

**Files:** none (verification only).

- [ ] **Step 1: Launch the app.**

- [ ] **Step 2: Two-tap placement** — tap an element: it shows the selected ring + the detail card appears + other tokens dim. Tap a drop zone: the element is placed AND the card disappears. **Two taps total.**

- [ ] **Step 3: Card declutter** — the card shows no group/period lines, no "Select" button, no "Drag the symbol…" text. Dragging the big symbol from the card into a zone still places it.

- [ ] **Step 4: Card dismiss** — tapping the card's X clears the selection (other tokens un-dim) and closes the card with nothing placed.

- [ ] **Step 5: Empty zone cue** — with a selection pending, an empty zone shows the pending symbol + a tap-hand icon (no sentence). With no selection, the droplet icon shows.

- [ ] **Step 6: Hover (if the Simulator forwards pointer hover)** — point at an element without clicking: the header shows "<symbol> · Group … · Period n" and its group column + period row highlight; moving away clears them. If hover doesn't fire in your Simulator, confirm tapping still highlights and opens the card.

- [ ] **Step 7: Polyatomic + bonding** — polyatomic card is also non-modal/decluttered and tap-selects; the bonding info card (from the bond-type label) is still modal as before.

- [ ] **Step 8: Commit any tweaks** (skip if none).

```bash
git add -A
git commit -m "fix: tray interaction verification tweaks"
```
