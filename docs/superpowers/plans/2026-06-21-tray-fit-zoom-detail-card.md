# Element Tray Fit/Zoom/Detail Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the element tray show the whole periodic table at once (fit-to-frame), pinch-zoomable, with a tap-to-open enlarged detail card that is the drag source for placing tokens.

**Architecture:** Extract cell-size math into a pure, unit-tested helper (`trayCellMetrics`). `ElementTrayView` wraps its grid in a `GeometryReader` to size cells from the available area, adds a `MagnificationGesture` for zoom, and owns overlay state for a new `ElementDetailCard`. Grid tokens become tap-only (open the card); the card carries the `.draggable` source and a select button. `CanvasModel`, `DropZoneView`, and bond logic are untouched — both existing placement paths (drag→`dropDestination`, select→tap-slot) keep working.

**Tech Stack:** Swift, SwiftUI, XCTest. Package `ChemCore` (domain), app target `ChemInteractive`, test target `ChemInteractiveTests`. Xcode scheme `ChemInteractive`.

## Global Constraints

- Columns = 18, logical rows = 9 (periods 1–7 + lanthanide row + actinide row), inter-cell spacing = 2pt. Values copied from the existing `ElementTrayView` grid.
- Do NOT modify `CanvasModel`, `DropZoneView`, or `ChemCanvasView`. Tray occupies `geo.size.height * 0.45` (set in `ChemCanvasView`, unchanged).
- Preserve both placement paths: drag a `TokenTransfer` onto a `.dropDestination`, and `model.select(token)` then tap-slot.
- Honor `draggingDisabled` (true when `model.state.canvasPhase == .animatingCrossover`): no drag/select while disabled.
- Existing helpers (use verbatim, do not redefine): `elementClassColor(_ cls: ElementClass) -> Color`, `categoryColor(_ category: ChemCore.Category) -> Color`, `bondHint(...) -> BondHintKind`, `BondHintKind` (has `.tint` and `.none`).
- Model field names (verbatim): `TokenTransfer(symbol: String, isPolyatomic: Bool)`; `Element` exposes `symbol`, `name`, `atomicNumber`, `massNumber`, `atomicMass`, `category`, `elementClass`, `oxidationStates`; `PolyatomicIon` exposes `symbol`, `name`, `charge`, `formula`; `ElementClass.rawValue` and `Category.rawValue` are display strings.
- Unit-test run command (adjust simulator name to one installed locally):
  `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ChemInteractiveTests/TrayLayoutTests`

---

## File Structure

- Create `ChemInteractive/Views/Tray/TrayLayout.swift` — pure `TrayCellMetrics` struct + `trayCellMetrics(...)` function. No SwiftUI view code, just `CoreGraphics` math so it is unit-testable.
- Create `ChemInteractiveTests/TrayLayoutTests.swift` — tests for `trayCellMetrics`.
- Create `ChemInteractive/Views/Tray/ElementDetailCard.swift` — the enlarged overlay card for an element and for a polyatomic ion (one file, two small views).
- Modify `ChemInteractive/Views/Tray/ElementTokenView.swift` — accept cell/font sizing params + an `onTap` closure; remove `.draggable` from the tiny token.
- Modify `ChemInteractive/Views/Tray/PolyatomicTokenView.swift` — same: `onTap` closure, remove `.draggable`.
- Modify `ChemInteractive/Views/Tray/ElementTrayView.swift` — `GeometryReader` sizing via `trayCellMetrics`, pinch-zoom state + gesture, detail-card overlay state, pass `onTap`/metrics into tokens.

---

## Task 1: Pure cell-metrics helper

**Files:**
- Create: `ChemInteractive/Views/Tray/TrayLayout.swift`
- Test: `ChemInteractiveTests/TrayLayoutTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct TrayCellMetrics: Equatable { let cell: CGFloat; let symbolFont: CGFloat; let cornerFont: CGFloat; let showCornerNumbers: Bool }`
  - `func trayCellMetrics(width: CGFloat, height: CGFloat, columns: Int = 18, rows: Int = 9, spacing: CGFloat = 2, minCell: CGFloat = 18, cornerThreshold: CGFloat = 28) -> TrayCellMetrics`

- [ ] **Step 1: Write the failing test**

Create `ChemInteractiveTests/TrayLayoutTests.swift`:

```swift
import XCTest
import CoreGraphics
@testable import ChemInteractive

final class TrayLayoutTests: XCTestCase {
    func test_widthBound_choosesWidthFit() {
        // Wide-but-short frame: height limits the cell.
        let m = trayCellMetrics(width: 2000, height: 360)
        // heightFit = (360 - 8*2)/9 = 38.22 -> floor 38; widthFit much larger.
        XCTAssertEqual(m.cell, 38)
    }

    func test_heightBound_choosesWidthFit() {
        // Narrow frame: width limits the cell.
        let m = trayCellMetrics(width: 390, height: 2000)
        // widthFit = (390 - 17*2)/18 = 19.77 -> floor 19.
        XCTAssertEqual(m.cell, 19)
    }

    func test_symbolFontTracksCell() {
        let m = trayCellMetrics(width: 2000, height: 360)
        XCTAssertEqual(m.symbolFont, 38 * 0.37, accuracy: 0.001)
    }

    func test_cornerNumbersHiddenBelowThreshold() {
        let small = trayCellMetrics(width: 390, height: 2000) // cell 19
        XCTAssertFalse(small.showCornerNumbers)
        let big = trayCellMetrics(width: 2000, height: 360)    // cell 38
        XCTAssertTrue(big.showCornerNumbers)
    }

    func test_minCellClamp() {
        let m = trayCellMetrics(width: 10, height: 10)
        XCTAssertEqual(m.cell, 18) // clamped to minCell
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ChemInteractiveTests/TrayLayoutTests`
Expected: FAIL — `cannot find 'trayCellMetrics' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `ChemInteractive/Views/Tray/TrayLayout.swift`:

```swift
import CoreGraphics

/// Sizing derived from the tray's available area. Pure — no SwiftUI.
struct TrayCellMetrics: Equatable {
    let cell: CGFloat
    let symbolFont: CGFloat
    let cornerFont: CGFloat
    let showCornerNumbers: Bool
}

/// Compute the per-cell size that fits `columns` × `rows` into width × height,
/// plus the font sizes derived from it. `cell` is clamped to `minCell`.
/// Corner atomic/mass numbers are hidden when `cell < cornerThreshold`.
func trayCellMetrics(width: CGFloat, height: CGFloat,
                     columns: Int = 18, rows: Int = 9,
                     spacing: CGFloat = 2, minCell: CGFloat = 18,
                     cornerThreshold: CGFloat = 28) -> TrayCellMetrics {
    let widthFit = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
    let heightFit = (height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
    let cell = max(minCell, floor(min(widthFit, heightFit)))
    return TrayCellMetrics(
        cell: cell,
        symbolFont: cell * 0.37,             // preserves today's 14/38 ratio
        cornerFont: max(5, cell * 0.18),
        showCornerNumbers: cell >= cornerThreshold
    )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ChemInteractiveTests/TrayLayoutTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Views/Tray/TrayLayout.swift ChemInteractiveTests/TrayLayoutTests.swift
git commit -m "feat: add pure trayCellMetrics fit-to-frame helper"
```

---

## Task 2: ElementTokenView — sized + tap-only

**Files:**
- Modify: `ChemInteractive/Views/Tray/ElementTokenView.swift`

**Interfaces:**
- Consumes: `TrayCellMetrics` (Task 1) for `cell`, `symbolFont`, `cornerFont`, `showCornerNumbers`.
- Produces: updated initializer surface used by `ElementTrayView` (Task 5):
  `ElementTokenView(element: Element, hint: BondHintKind?, disabled: Bool, metrics: TrayCellMetrics, onTap: @escaping (Element) -> Void)`.

This task changes a view; the "test" is a successful build of the app target plus the existing `ChemInteractiveTests` suite still passing (it does not reference this view directly). There is no unit test for the rendered view.

- [ ] **Step 1: Replace the view body**

Replace the entire contents of `ChemInteractive/Views/Tray/ElementTokenView.swift` with:

```swift
import SwiftUI
import ChemCore

struct ElementTokenView: View {
    let element: Element
    var hint: BondHintKind?
    var disabled: Bool = false
    var metrics: TrayCellMetrics
    var onTap: (Element) -> Void

    @Environment(CanvasModel.self) private var model

    private var token: TokenTransfer { TokenTransfer(symbol: element.symbol, isPolyatomic: false) }
    private var isInactive: Bool { disabled || hint == BondHintKind.none }
    private var isSelected: Bool { model.selectedToken == token }
    private var glyphColor: Color { elementClassColor(element.elementClass) }

    @ViewBuilder
    var body: some View {
        let styled = VStack(spacing: 0) {
            HStack(spacing: 2) {
                if metrics.showCornerNumbers {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(element.massNumber)").font(.system(size: metrics.cornerFont))
                        Text("\(element.atomicNumber)").font(.system(size: metrics.cornerFont))
                    }
                    .foregroundStyle(Theme.text.opacity(0.65))
                }
                Text(element.symbol)
                    .font(.system(size: metrics.symbolFont, weight: .bold))
                    .foregroundStyle(glyphColor)
            }
        }
        .frame(width: metrics.cell, height: metrics.cell)
        .background((hint?.tint) ?? Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(glyphColor.opacity(0.4), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(isSelected ? 0.8 : 0), lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 6))

        if isInactive {
            styled
                .opacity(0.2)
                .allowsHitTesting(false)
        } else {
            styled
                .opacity(model.selectedToken != nil && !isSelected ? 0.5 : 1)
                .onTapGesture { onTap(element) }
        }
    }
}
```

Notes: `.draggable`/`dragPreview` removed — drag now originates from the detail card (Task 4). Tap now calls `onTap(element)` instead of `model.select`.

- [ ] **Step 2: Commit**

(This task does not compile standalone — `ElementTrayView` still calls the old initializer. Defer the build check to Task 5, where the call site is updated. Commit the view change now so history stays granular.)

```bash
git add ChemInteractive/Views/Tray/ElementTokenView.swift
git commit -m "feat: size ElementTokenView from metrics, tap opens card"
```

---

## Task 3: PolyatomicTokenView — tap-only

**Files:**
- Modify: `ChemInteractive/Views/Tray/PolyatomicTokenView.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: updated initializer used by `ElementTrayView` (Task 5):
  `PolyatomicTokenView(ion: PolyatomicIon, disabled: Bool, onTap: @escaping (PolyatomicIon) -> Void)`.

- [ ] **Step 1: Replace the view body**

Replace the entire contents of `ChemInteractive/Views/Tray/PolyatomicTokenView.swift` with:

```swift
import SwiftUI
import ChemCore

struct PolyatomicTokenView: View {
    let ion: PolyatomicIon
    var disabled: Bool = false
    var onTap: (PolyatomicIon) -> Void

    @Environment(CanvasModel.self) private var model

    private var token: TokenTransfer { TokenTransfer(symbol: ion.symbol, isPolyatomic: true) }
    private var isSelected: Bool { model.selectedToken == token }

    @ViewBuilder
    var body: some View {
        let styled = Text(ion.formula)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(height: 64)
            .padding(.horizontal, 12)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.anion.opacity(0.4), lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(isSelected ? 0.8 : 0), lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        if disabled {
            styled
                .opacity(0.2)
                .allowsHitTesting(false)
        } else {
            styled
                .opacity(model.selectedToken != nil && !isSelected ? 0.5 : 1)
                .onTapGesture { onTap(ion) }
        }
    }
}
```

Notes: `.draggable` removed; tap calls `onTap(ion)`.

- [ ] **Step 2: Commit**

```bash
git add ChemInteractive/Views/Tray/PolyatomicTokenView.swift
git commit -m "feat: polyatomic token tap opens card, drag moves to card"
```

---

## Task 4: ElementDetailCard — enlarged overlay + drag source

**Files:**
- Create: `ChemInteractive/Views/Tray/ElementDetailCard.swift`

**Interfaces:**
- Consumes: `Element`, `PolyatomicIon`, `TokenTransfer`, `CanvasModel`, `elementClassColor`, `categoryColor`.
- Produces:
  - `struct ElementDetailCard: View` — init `ElementDetailCard(element: Element, disabled: Bool, onClose: @escaping () -> Void)`.
  - `struct PolyatomicDetailCard: View` — init `PolyatomicDetailCard(ion: PolyatomicIon, disabled: Bool, onClose: @escaping () -> Void)`.

- [ ] **Step 1: Create the file**

Create `ChemInteractive/Views/Tray/ElementDetailCard.swift`:

```swift
import SwiftUI
import ChemCore

/// Shared dimmed backdrop + card chrome. Tapping the backdrop closes.
private struct CardChrome<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
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
}

struct ElementDetailCard: View {
    let element: Element
    var disabled: Bool = false
    let onClose: () -> Void

    @Environment(CanvasModel.self) private var model

    private var token: TokenTransfer { TokenTransfer(symbol: element.symbol, isPolyatomic: false) }
    private var glyphColor: Color { elementClassColor(element.elementClass) }

    var body: some View {
        CardChrome(onClose: onClose) {
            HStack(alignment: .top, spacing: 12) {
                Text(element.symbol)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(glyphColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(element.name).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.text)
                    Text("Z \(element.atomicNumber)  ·  Mass \(element.massNumber)")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    Text(element.elementClass.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(glyphColor)
                    Text(element.category.rawValue)
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.bottom, 10)

            if !element.oxidationStates.isEmpty {
                Text("Oxidation: " + element.oxidationStates.map { $0 > 0 ? "+\($0)" : "\($0)" }.joined(separator: ", "))
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
                    .padding(.bottom, 12)
            }

            if !disabled {
                HStack(spacing: 10) {
                    Text("Drag to a slot, or")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                    Button("Select") { model.select(token); onClose() }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .foregroundStyle(Theme.accent)
                        .overlay(Capsule().stroke(Theme.accent, lineWidth: 1))
                }
                .draggable(token) { dragPreview }
            }
        }
    }

    private var dragPreview: some View {
        Text(element.symbol)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(glyphColor)
            .padding(8)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct PolyatomicDetailCard: View {
    let ion: PolyatomicIon
    var disabled: Bool = false
    let onClose: () -> Void

    @Environment(CanvasModel.self) private var model

    private var token: TokenTransfer { TokenTransfer(symbol: ion.symbol, isPolyatomic: true) }

    var body: some View {
        CardChrome(onClose: onClose) {
            Text(ion.formula)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 6)
            Text(ion.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text)
            Text("Charge \(ion.charge > 0 ? "+\(ion.charge)" : "\(ion.charge)")")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
                .padding(.bottom, 12)

            if !disabled {
                HStack(spacing: 10) {
                    Text("Drag to a slot, or")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                    Button("Select") { model.select(token); onClose() }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .foregroundStyle(Theme.accent)
                        .overlay(Capsule().stroke(Theme.accent, lineWidth: 1))
                }
                .draggable(token) {
                    Text(ion.formula).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .padding(8).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
```

Note: if `Theme.accent` / `Theme.muted` / `Theme.text` / `Theme.surface` names differ, check `ChemInteractive/Theme/Theme.swift` and use the actual names (they are referenced by existing tray views, so they exist).

- [ ] **Step 2: Commit**

```bash
git add ChemInteractive/Views/Tray/ElementDetailCard.swift
git commit -m "feat: add element + polyatomic detail cards as drag source"
```

---

## Task 5: ElementTrayView — fit sizing, zoom, card overlay

**Files:**
- Modify: `ChemInteractive/Views/Tray/ElementTrayView.swift`

**Interfaces:**
- Consumes: `trayCellMetrics` (Task 1), `ElementTokenView(... metrics: onTap:)` (Task 2), `PolyatomicTokenView(... onTap:)` (Task 3), `ElementDetailCard` / `PolyatomicDetailCard` (Task 4).
- Produces: the finished tray. End of chain — nothing downstream consumes new symbols.

- [ ] **Step 1: Replace the view**

Replace the entire contents of `ChemInteractive/Views/Tray/ElementTrayView.swift` with:

```swift
import SwiftUI
import ChemCore

struct ElementTrayView: View {
    @Environment(CanvasModel.self) private var model
    @State private var tab: Tab = .elements
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var detailElement: Element?
    @State private var detailIon: PolyatomicIon?

    private enum Tab { case elements, polyatomic }

    private var draggingDisabled: Bool { model.state.canvasPhase == .animatingCrossover }

    // The single filled slot, when exactly one is filled (drives hint tints + legend).
    private var firstSlot: ChemCore.ZoneState? {
        let a = model.state.slotA, b = model.state.slotB
        if a != nil && b != nil { return nil }
        return a ?? b
    }

    private func isFBlock(_ z: Int) -> Bool { (57...71).contains(z) || (89...103).contains(z) }
    private var mainElements: [Element] { model.elements.filter { !isFBlock($0.atomicNumber) } }
    private var lanthanides: [Element] { model.elements.filter { (57...71).contains($0.atomicNumber) }.sorted { $0.atomicNumber < $1.atomicNumber } }
    private var actinides: [Element] { model.elements.filter { (89...103).contains($0.atomicNumber) }.sorted { $0.atomicNumber < $1.atomicNumber } }

    private func hint(for el: Element) -> BondHintKind? {
        guard let first = firstSlot else { return nil }
        return bondHint(firstClass: first.elementClass, firstIsPolyatomic: first.isPolyatomic,
                        tokenClass: el.elementClass, tokenCategory: el.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            GeometryReader { geo in
                let metrics = trayCellMetrics(width: geo.size.width, height: geo.size.height)
                ScrollView([.horizontal, .vertical]) {
                    Group {
                        if tab == .elements { elementsGrid(metrics) } else { polyatomicGrid }
                    }
                    .scaleEffect(zoom * pinch, anchor: .topLeading)
                }
                .gesture(
                    MagnificationGesture()
                        .updating($pinch) { value, state, _ in state = value }
                        .onEnded { value in
                            zoom = min(4, max(1, zoom * value))
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.2)) { zoom = 1 }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.opacity(0.5))
        .overlay {
            if let el = detailElement {
                ElementDetailCard(element: el, disabled: draggingDisabled) { detailElement = nil }
            } else if let ion = detailIon {
                PolyatomicDetailCard(ion: ion, disabled: draggingDisabled) { detailIon = nil }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            tabButton("Elements", .elements)
            tabButton("Polyatomic Ions", .polyatomic)
            if firstSlot != nil { legend }
            Spacer()
        }
    }

    private func tabButton(_ title: String, _ value: Tab) -> some View {
        Button(title) { tab = value }
            .font(.system(size: 11))
            .padding(.horizontal, 12).padding(.vertical, 4)
            .foregroundStyle(tab == value ? Theme.accent : Theme.muted)
            .overlay(Capsule().stroke(tab == value ? Theme.accent : Theme.muted.opacity(0.4), lineWidth: 1))
            .background(tab == value ? Theme.accent.opacity(0.2) : .clear, in: Capsule())
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendDot(Color(hex: 0x3b82f6), "Ionic")
            legendDot(Color(hex: 0x22c55e), "Covalent")
            legendDot(Color(hex: 0xf97316), "Metallic")
        }
        .font(.system(size: 9))
        .foregroundStyle(.white.opacity(0.5))
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) { Circle().fill(color.opacity(0.8)).frame(width: 8, height: 8); Text(label) }
    }

    private func elementsGrid(_ m: TrayCellMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 18 columns × 7 periods. Empty cells where no element occupies (group, period).
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                ForEach(1...7, id: \.self) { period in
                    GridRow {
                        ForEach(1...18, id: \.self) { group in
                            if let el = mainElements.first(where: { $0.group == group && $0.period == period }) {
                                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled,
                                                 metrics: m, onTap: { detailElement = $0 })
                            } else {
                                Color.clear.frame(width: m.cell, height: m.cell)
                            }
                        }
                    }
                }
            }
            Divider().overlay(.white.opacity(0.1))
            fBlockRow(lanthanides, label: "6f", m)
            fBlockRow(actinides, label: "7f", m)
        }
    }

    private func fBlockRow(_ els: [Element], label: String, _ m: TrayCellMetrics) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 8)).foregroundStyle(.white.opacity(0.3)).frame(width: 16, alignment: .trailing)
            ForEach(els, id: \.atomicNumber) { el in
                ElementTokenView(element: el, hint: hint(for: el), disabled: draggingDisabled,
                                 metrics: m, onTap: { detailElement = $0 })
            }
        }
    }

    private var polyatomicGrid: some View {
        HStack(spacing: 8) {
            ForEach(model.polyatomicIons, id: \.symbol) { ion in
                PolyatomicTokenView(ion: ion, disabled: draggingDisabled, onTap: { detailIon = $0 })
            }
        }
    }
}
```

Notes:
- `.scaleEffect(zoom * pinch, anchor: .topLeading)` gives a live pinch preview (`pinch`) multiplied into the committed `zoom`; `.onEnded` folds the gesture into `zoom`, clamped `1...4`.
- Anchor `.topLeading` keeps content aligned to the scroll origin so panning works naturally when zoomed.
- Double-tap resets `zoom` to 1.
- Opening a card sets `detailElement`/`detailIon`; the overlay shows one at a time, dismissed via the card's `onClose`.

- [ ] **Step 2: Build the app target + run full test suite**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED; all `ChemInteractiveTests` (including `TrayLayoutTests`) PASS. This is the first point where Tasks 2–5 compile together.

- [ ] **Step 3: Commit**

```bash
git add ChemInteractive/Views/Tray/ElementTrayView.swift
git commit -m "feat: fit-to-frame tray with pinch-zoom and detail-card overlay"
```

---

## Task 6: Manual verification in the running app

**Files:** none (verification only).

No automated UI test exists for this view layer; verify behavior by running the app. The `Step` checkboxes below are the acceptance checklist.

- [ ] **Step 1: Launch the app** (Xcode Run, or `xcodebuild` to a simulator). Optionally use the existing DEBUG direct-to-diagram launch argument where helpful.

- [ ] **Step 2: Verify fit** — at default zoom the full periodic table (7 periods + 6f/7f rows) is visible with NO horizontal scroll on the target device size. Symbols readable; corner numbers hidden when cells are small.

- [ ] **Step 3: Verify zoom/pan** — pinch out to zoom in (up to 4×), pan by dragging when zoomed, double-tap to reset to fit.

- [ ] **Step 4: Verify element card** — tap an element → card shows correct symbol/name/Z/mass/class/category/oxidation states. Background tap and X both dismiss.

- [ ] **Step 5: Verify drag from card** — drag from the card onto a drop slot → element lands in the slot. Then test the Select button → tap a slot → element placed (tap-select path).

- [ ] **Step 6: Verify polyatomic tab** — switch to Polyatomic Ions, tap an ion → card with formula/name/charge → drag and Select both place it.

- [ ] **Step 7: Verify disabled phase** — during the crossover animation phase, the card's drag/Select are inactive (no placement).

- [ ] **Step 8: Commit any tweaks** made during verification.

```bash
git add -A
git commit -m "fix: tray verification tweaks"
```

(Skip the commit if no changes were needed.)
