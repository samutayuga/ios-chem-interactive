# ChemInteractive — SwiftUI App (UI Layer) Design

**Date:** 2026-06-20
**Status:** Approved (design), pending implementation plan
**Builds on:**
- Master design: `docs/superpowers/specs/2026-06-20-ios-chem-interactive-design.md`
- Plan 1 (done): `docs/superpowers/plans/2026-06-20-domain-logic-core.md` — the `ChemCore` Swift package.

## 1. Goal & context

The master spec designed the whole app (layout, interactions, theme, result diagrams,
testing). Plan 1 implemented the **domain logic** as a standalone, UI-independent Swift
package `ChemCore` (PTDomain, Data, Engine, State machine), verified by 61 XCTests
including a golden-fidelity check against WASM for all 118 elements.

This document is the **delta** for the remaining work: the native SwiftUI iPhone app built
**on top of** `ChemCore`. It supersedes the master spec's monolithic single-target file
tree (which placed PTDomain/Data/Engine/State inside the app target) — that logic now lives
in the `ChemCore` package and is consumed as a dependency.

The reference React app is available at `~/Developer/codews/chem-interactive/src`
(`tray/`, `bridge/`, `canvas/`, `utils/`, `index.css`) and is the fidelity source for
layout, colors, and behavior.

## 2. Decomposition

The UI is large enough to split into two focused, independently verifiable plans:

- **Plan 2 — Interactive skeleton (this spec's primary scope).** Hand-authored
  `.xcodeproj`, `ChemCore` integration, `@Observable` model, theme, tray, drag/drop +
  tap-select, drop zones, transition-metal picker, and the explanation modal. The three
  result diagrams are **stubbed** with placeholder views so the full phase machine runs
  end-to-end. Gate: a build/boot-verified interactive app.
- **Plan 3 — Result diagrams (follow-on).** Replace the three stubs with the animated
  SwiftUI `Canvas` diagrams: ionic crossover + Lewis electron-transfer, covalent Lewis
  structure, metallic electron-sea (`TimelineView` + `Canvas`).

Each plan gets its own implementation plan and build/boot verification. Plan 3 is scoped
here only at a high level; it will be brainstormed/planned separately when Plan 2 lands.

## 3. Architecture & project layout

```
ios-chem-interactive/
├── ChemCore/                        # existing Swift package (Plan 1) — unchanged
├── ChemInteractive.xcodeproj/       # NEW — hand-authored, single SwiftUI app target
└── ChemInteractive/                 # NEW — app sources
    ├── ChemInteractiveApp.swift     # @main; injects CanvasModel
    ├── State/
    │   └── CanvasModel.swift         # @Observable wrapper over canvasReducer
    ├── Theme/
    │   └── Theme.swift               # exact colors from index.css / elementColor.ts
    ├── Views/
    │   ├── ChemCanvasView.swift      # root layout (tray over workspace)
    │   ├── Tray/ElementTrayView.swift
    │   ├── Tray/ElementTokenView.swift
    │   ├── Tray/PolyatomicTokenView.swift
    │   ├── Zones/DropZoneView.swift
    │   ├── Zones/TransitionMetalPickerView.swift
    │   ├── Bridge/BridgeView.swift            # phase router
    │   ├── Bridge/ExplanationModalView.swift
    │   └── Bridge/DiagramPlaceholders.swift   # Plan 2 stubs; replaced in Plan 3
    └── Assets.xcassets
```

**Project generation:** hand-authored `project.pbxproj` for a single SwiftUI target. No
XcodeGen/Tuist. The project references `ChemCore` as a **local Swift package** (relative
path `ChemCore`) and the app target links the `ChemCore` library product. The hand-authored
pbxproj is the known-fiddly part; mitigation is to verify with `xcodebuild` before adding
any views and treat a clean build + simulator boot as the gate.

**Deployment target:** iOS 17.0, portrait iPhone. (`ChemCore` targets iOS 16; an iOS 17 app
consuming an iOS 16 package is fine.) `@Observable` requires iOS 17, matching the spec.

**Data & domain:** the app adds **no** chemistry logic. `PeriodicTable.load()` reads
`elements.raw.json` from the `ChemCore` package bundle, so the app obtains the 118 elements,
the 6 polyatomic ions, and all derived fields transitively. No data files are added to the
app target.

## 4. The `@Observable` model

`ChemCore` exposes a pure `canvasReducer(_:_:) -> CanvasState`, `CanvasState`, and
`CanvasAction`. The app wraps them in a thin observable class — no logic duplication:

```swift
import ChemCore
import Observation

@Observable
final class CanvasModel {
    private(set) var state: CanvasState = .initial
    let elements: [Element]                       // 118, from PeriodicTable.load()
    let polyatomicIons = PolyatomicIon.polyatomicIons

    init() {
        let pt = try! PeriodicTable.load()        // bundled resource; failure is a dev error
        self.elements = pt.elements
    }

    func send(_ action: CanvasAction) {
        state = canvasReducer(state, action)
    }
}
```

- The model owns element loading at init and exposes elements + polyatomic ions to views.
- Views read `model.state.canvasPhase / slotA / slotB / bondingType` and call
  `model.send(.dropElement(slot:zone:))`, `.pickTMCharge`, `.dismissExplanation`,
  `.replaceElement`, `.crossoverComplete`, `.reset`. All transitions stay in the
  already-tested reducer.
- Dropping a token builds a `ZoneState` via the existing `ZoneState(element:)` /
  `ZoneState(polyatomic:)` initializers from `ChemCore`.

The app layer is a thin, declarative SwiftUI shell over tested logic.

## 5. Plan 2 components (skeleton)

Behavior is ported from the master spec §7 and the React reference; summarized here:

- **Root layout (`ChemCanvasView`):** tray on top (~45% height), workspace below
  (Slot A | Bridge | Slot B), portrait-first.
- **Tray:** horizontally scrollable 18-column grid (f-block below), tabs
  "Elements" / "Polyatomic Ions". After the first drop, remaining tokens get bond-hint
  tints (ionic=blue, covalent=green, metallic=orange; noble gases faded/disabled). Hint
  tints are computed from the prospective `bondingType(...)` against the filled slot.
- **Tokens:** `Transferable` identifier for drag (`.draggable`), plus **tap-to-select**
  parity (tap fills the next empty slot). Element tooltip on long-press/tap.
- **Drop zones (`DropZoneView`):** slots A/B via `.dropDestination`, drop-over highlight,
  `×` to clear (clearing resets the other slot to NEUTRAL via `.replaceElement`).
- **Transition-metal picker:** inline when a slot is DEDUCING; selecting a charge sends
  `.pickTMCharge`.
- **Explanation modal (`ExplanationModalView`):** charge-derivation copy per bond type;
  "Apply →" sends `.dismissExplanation` (blocked for Ionic while a slot is DEDUCING).
- **Bridge router (`BridgeView`):** switches on `state.canvasPhase`. For
  `animatingCrossover` / `showingCovalent` / `showingMetallic` it renders **placeholder**
  views in Plan 2 (e.g., a labeled box naming the bond type and computed stoichiometry /
  electron count from `ChemCore`), so the full phase machine — including
  `.crossoverComplete` → `complete` and `.reset` — is exercisable end-to-end.
- **Theme (`Theme.swift`):** exact values ported from `index.css` / `elementColor.ts`
  (bg `#1a0a2e`, cation `#00ff88`, anion `#ff4080`, accent `#7040ff`, surface `#2a1a4e`,
  muted `#4a3a6e`; 8 category colors; bond-hint tints; orbital colors). System font.

## 6. Plan 3 components (diagrams — follow-on, high level)

Replace the three placeholders with SwiftUI `Canvas` diagrams matching the master spec §7:
ionic animated crossover (charges → subscripts → gcd reduction) + Lewis electron-transfer;
covalent Lewis structure (central/peripheral layout, shared + lone pairs); metallic
electron-sea (3×2 cation lattice, animated electrons via `TimelineView` + `Canvas`).
Animation fidelity is behavioral/approximate, not pixel-exact. Detailed design deferred to
Plan 3's own brainstorm.

## 7. Testing & verification

- **Domain/state logic:** already covered by `ChemCore`'s 61 XCTests (PTDomain, Data,
  golden fidelity, Engine, State machine). No app-target unit tests duplicate this.
- **App build/boot gate (Plan 2):** `xcodebuild -scheme ChemInteractive -destination
  'platform=iOS Simulator,name=iPhone 17'` compiles, and the app launches in the simulator.
  This is run early (empty target) and again after views are added.
- **Manual smoke (Plan 2):** drag Na + Cl → ionic explanation → crossover placeholder →
  complete → reset; drop on both-filled restarts; transition-metal picker path (Fe + Cl).

## 8. Risks

- **Hand-authored pbxproj** is fiddly (the issue that surfaced when the project couldn't be
  opened). Mitigation: one target, local-package reference, verify with `xcodebuild` before
  adding views; clean build is the gate.
- **`@Observable` + drag/drop wiring** is new SwiftUI surface. Mitigation: keep the model a
  thin pass-through to the tested reducer; verify interactions via simulator boot + manual
  smoke before Plan 3.
- **Tray legibility on a narrow screen.** Mitigation: horizontal scroll + tap-to-enlarge /
  tooltip, as the React app does on mobile.

## 9. Out of scope (this spec)

iPad/macOS layouts, App Store assets, the three animated diagrams (Plan 3), and any change
to `ChemCore` (consumed as-is). If a small `ChemCore` addition proves necessary during
Plan 2 (e.g., a convenience accessor), it will be made test-first in the package.
