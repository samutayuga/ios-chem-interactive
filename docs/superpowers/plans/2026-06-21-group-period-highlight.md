# Group/Period Highlight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapping a periodic-table element highlights its group column + period row in the grid (visible behind the detail card) and shows the group name + period number on the card.

**Architecture:** Add a pure `periodicGroupName` helper; parameterize the shared `CardChrome` backdrop dim so the element card can be lightly dimmed; derive per-token `axisHighlighted`/`focused` from `detailElement` in `ElementTrayView` and render a wash/ring in `ElementTokenView`. No model/reducer changes.

**Tech Stack:** Swift, SwiftUI, XCTest. App target `ChemInteractive`, tests `ChemInteractiveTests`, scheme `ChemInteractive`. `PBXFileSystemSynchronizedRootGroup` — new files auto-include. Test simulator: `iPhone 17 Pro`.

## Global Constraints

- No changes to `CanvasModel`, the reducer, or bonding logic.
- Highlight derives from `ElementTrayView`'s existing `@State detailElement: Element?` — NO new selection state; it clears when the card dismisses (`detailElement = nil`).
- A token is axis-highlighted when `detailElement != nil` and (`same group` OR `same period`); `same group` excludes f-block on either side (lanthanide z 57–71 / actinide z 89–103 highlight by period only). `ElementTrayView` already has `private func isFBlock(_ z: Int) -> Bool`.
- The focused (tapped) cell is `detailElement?.atomicNumber == el.atomicNumber`.
- Polyatomic ions: no highlight; `PolyatomicDetailCard` and `BondingInfoCard` keep the default `0.55` backdrop. Only `ElementDetailCard` uses a light dim (`0.15`).
- Group names (verbatim): 1 "Group 1 · Alkali metals" (H, z==1 → "Group 1"), 2 "Group 2 · Alkaline earth metals", 3–12 "Group N · Transition metals", 13 "Group 13 · Boron group", 14 "Group 14 · Carbon group", 15 "Group 15 · Pnictogens", 16 "Group 16 · Chalcogens", 17 "Group 17 · Halogens", 18 "Group 18 · Noble gases"; z 57–71 "Lanthanides"; z 89–103 "Actinides".
- Highlight wash `Theme.accent.opacity(0.18)`; focused ring `Theme.accent.opacity(0.9)` lineWidth 2.

---

## File Structure

- New `ChemInteractive/Theme/PeriodicNaming.swift` — `periodicGroupName(for:)` (pure).
- Modify `ChemInteractive/Views/Shared/CardChrome.swift` — add `dim` parameter.
- Modify `ChemInteractive/Views/Tray/ElementTokenView.swift` — add `axisHighlighted`/`focused`.
- Modify `ChemInteractive/Views/Tray/ElementTrayView.swift` — compute + pass highlight.
- Modify `ChemInteractive/Views/Tray/ElementDetailCard.swift` — light dim + group/period lines.

---

## Task 1: `periodicGroupName` helper

**Files:**
- Create: `ChemInteractive/Theme/PeriodicNaming.swift`
- Test: `ChemInteractiveTests/PeriodicNamingTests.swift`

**Interfaces:**
- Consumes: `Element` (`group`, `period`, `atomicNumber`).
- Produces: `func periodicGroupName(for el: Element) -> String`.

- [ ] **Step 1: Write the failing test**

Create `ChemInteractiveTests/PeriodicNamingTests.swift`:

```swift
import XCTest
import ChemCore
@testable import ChemInteractive

final class PeriodicNamingTests: XCTestCase {
    private func el(_ z: Int) throws -> Element {
        let pt = try PeriodicTable.load()
        return try XCTUnwrap(pt.elements.first { $0.atomicNumber == z })
    }

    func test_namedGroups() throws {
        XCTAssertEqual(periodicGroupName(for: try el(11)), "Group 1 · Alkali metals")        // Na
        XCTAssertEqual(periodicGroupName(for: try el(20)), "Group 2 · Alkaline earth metals") // Ca
        XCTAssertEqual(periodicGroupName(for: try el(26)), "Group 8 · Transition metals")     // Fe
        XCTAssertEqual(periodicGroupName(for: try el(6)),  "Group 14 · Carbon group")         // C
        XCTAssertEqual(periodicGroupName(for: try el(7)),  "Group 15 · Pnictogens")           // N
        XCTAssertEqual(periodicGroupName(for: try el(8)),  "Group 16 · Chalcogens")           // O
        XCTAssertEqual(periodicGroupName(for: try el(17)), "Group 17 · Halogens")             // Cl
        XCTAssertEqual(periodicGroupName(for: try el(10)), "Group 18 · Noble gases")          // Ne
    }

    func test_hydrogenHasNoAlkaliLabel() throws {
        XCTAssertEqual(periodicGroupName(for: try el(1)), "Group 1")                          // H
    }

    func test_fBlock() throws {
        XCTAssertEqual(periodicGroupName(for: try el(57)), "Lanthanides")  // La
        XCTAssertEqual(periodicGroupName(for: try el(92)), "Actinides")    // U
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/PeriodicNamingTests`
Expected: FAIL — `cannot find 'periodicGroupName' in scope`.

- [ ] **Step 3: Write the implementation**

Create `ChemInteractive/Theme/PeriodicNaming.swift`:

```swift
import ChemCore

/// Traditional group name (with IUPAC number) for an element, or the f-block
/// series name. Hydrogen is shown as just "Group 1" (it is not an alkali metal).
func periodicGroupName(for el: Element) -> String {
    let z = el.atomicNumber
    if (57...71).contains(z) { return "Lanthanides" }
    if (89...103).contains(z) { return "Actinides" }

    let g = el.group
    let traditional: String?
    switch g {
    case 1:  traditional = z == 1 ? nil : "Alkali metals"
    case 2:  traditional = "Alkaline earth metals"
    case 3...12: traditional = "Transition metals"
    case 13: traditional = "Boron group"
    case 14: traditional = "Carbon group"
    case 15: traditional = "Pnictogens"
    case 16: traditional = "Chalcogens"
    case 17: traditional = "Halogens"
    case 18: traditional = "Noble gases"
    default: traditional = nil
    }
    if let traditional { return "Group \(g) · \(traditional)" }
    return "Group \(g)"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/PeriodicNamingTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Theme/PeriodicNaming.swift ChemInteractiveTests/PeriodicNamingTests.swift
git commit -m "feat: add periodicGroupName helper"
```

---

## Task 2: CardChrome dim param + card group/period lines

**Files:**
- Modify: `ChemInteractive/Views/Shared/CardChrome.swift`
- Modify: `ChemInteractive/Views/Tray/ElementDetailCard.swift`

**Interfaces:**
- Consumes: `periodicGroupName(for:)` (Task 1).
- Produces: `CardChrome(onClose:dim:content:)` with `dim` defaulting to `0.55`.

- [ ] **Step 1: Add the `dim` parameter to CardChrome**

In `ChemInteractive/Views/Shared/CardChrome.swift`, change the stored properties and the backdrop. Replace:

```swift
struct CardChrome<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
```

with:

```swift
struct CardChrome<Content: View>: View {
    let onClose: () -> Void
    var dim: Double = 0.55
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(dim)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
```

(The rest of the file is unchanged. `PolyatomicDetailCard` and `BondingInfoCard` call `CardChrome(onClose:) { ... }` and keep the `0.55` default.)

- [ ] **Step 2: Light dim + group/period lines on the element card**

In `ChemInteractive/Views/Tray/ElementDetailCard.swift`, in `ElementDetailCard.body`, change the opening `CardChrome(onClose: onClose) {` to `CardChrome(onClose: onClose, dim: 0.15) {`.

Then, in the `VStack(alignment: .leading, spacing: 3)` that holds the name/class/category, add the group and period lines after the category line. Replace:

```swift
                VStack(alignment: .leading, spacing: 3) {
                    Text(element.name).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(element.elementClass.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(glyphColor)
                    Text(element.category.rawValue)
                        .font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.7))
                }
```

with:

```swift
                VStack(alignment: .leading, spacing: 3) {
                    Text(element.name).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(element.elementClass.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(glyphColor)
                    Text(element.category.rawValue)
                        .font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.7))
                    Text(periodicGroupName(for: element))
                        .font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.8))
                    Text("Period \(element.period)")
                        .font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.8))
                }
```

- [ ] **Step 3: Build + run full suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED; all tests pass.

- [ ] **Step 4: Commit**

```bash
git add ChemInteractive/Views/Shared/CardChrome.swift ChemInteractive/Views/Tray/ElementDetailCard.swift
git commit -m "feat: light dim + group/period lines on the element detail card"
```

---

## Task 3: Grid highlight (token + tray)

**Files:**
- Modify: `ChemInteractive/Views/Tray/ElementTokenView.swift`
- Modify: `ChemInteractive/Views/Tray/ElementTrayView.swift`

**Interfaces:**
- Consumes: `ElementTokenView` gains `axisHighlighted: Bool = false`, `focused: Bool = false`.
- Produces: finished feature — end of chain.

- [ ] **Step 1: Add highlight props + rendering to ElementTokenView**

In `ChemInteractive/Views/Tray/ElementTokenView.swift`, add the two properties after `var onTap: (Element) -> Void`:

```swift
    var axisHighlighted: Bool = false
    var focused: Bool = false
```

Then change the `styled` view's background + overlays. Replace:

```swift
        .frame(width: metrics.cell, height: metrics.cell)
        .background((hint?.tint) ?? Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(glyphColor.opacity(0.4), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(isSelected ? 0.8 : 0), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 6))
```

with:

```swift
        .frame(width: metrics.cell, height: metrics.cell)
        .background {
            ZStack {
                (hint?.tint) ?? Theme.surface
                if axisHighlighted { Theme.accent.opacity(0.18) }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(glyphColor.opacity(0.4), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(isSelected ? 0.8 : 0), lineWidth: 2))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(focused ? 0.9 : 0), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 6))
```

- [ ] **Step 2: Compute + pass highlight in ElementTrayView**

In `ChemInteractive/Views/Tray/ElementTrayView.swift`, add two helpers (next to the existing `isFBlock`):

```swift
    private func axisHighlighted(_ el: Element) -> Bool {
        guard let sel = detailElement else { return false }
        let sameGroup = !isFBlock(el.atomicNumber) && !isFBlock(sel.atomicNumber) && el.group == sel.group
        return sameGroup || el.period == sel.period
    }
    private func isFocused(_ el: Element) -> Bool { detailElement?.atomicNumber == el.atomicNumber }
```

Then update BOTH `ElementTokenView(...)` call sites to pass the new args.

In `elementsGrid`, replace:

```swift
                                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled,
                                                 metrics: m, onTap: { detailElement = $0 })
```

with:

```swift
                                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled,
                                                 metrics: m, onTap: { detailElement = $0 },
                                                 axisHighlighted: axisHighlighted(el), focused: isFocused(el))
```

In `fBlockRow`, replace:

```swift
                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled,
                                 metrics: m, onTap: { detailElement = $0 })
```

with:

```swift
                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled,
                                 metrics: m, onTap: { detailElement = $0 },
                                 axisHighlighted: axisHighlighted(el), focused: isFocused(el))
```

- [ ] **Step 3: Build + run full suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: BUILD SUCCEEDED; all tests pass.

- [ ] **Step 4: Commit**

```bash
git add ChemInteractive/Views/Tray/ElementTokenView.swift ChemInteractive/Views/Tray/ElementTrayView.swift
git commit -m "feat: highlight group/period on element tap"
```

---

## Task 4: Manual verification

**Files:** none (verification only).

- [ ] **Step 1: Launch the app** (single mouse click is the only gesture needed).

- [ ] **Step 2: Tap a main-group element** (e.g. Cl) — every filled cell in its column (group 17) and its row (period 3) gets an accent wash; the tapped cell shows the accent ring; the highlight is visible behind the lightly-dimmed card.

- [ ] **Step 3: Card lines** — the card shows `Group 17 · Halogens` and `Period 3`.

- [ ] **Step 4: f-block** — tap a lanthanide (e.g. La) — highlight follows the period only; card shows "Lanthanides".

- [ ] **Step 5: Hydrogen** — tap H — card shows "Group 1" (no alkali label).

- [ ] **Step 6: Dismiss** — close the card (click backdrop or ✕) → highlight clears.

- [ ] **Step 7: Polyatomic tab** — tap an ion → no grid highlight; its card backdrop is the normal darker dim.

- [ ] **Step 8: Commit any tweaks** (skip if none).

```bash
git add -A
git commit -m "fix: group/period highlight verification tweaks"
```
