# ChemInteractive (iOS)

A native SwiftUI iPhone app that teaches chemical bonding interactively. Drag two
elements (or a polyatomic ion) together and the app classifies the bond — **ionic**,
**covalent**, or **metallic** — explains the charge derivation, and renders an animated
result diagram: an ionic crossover + Lewis electron‑transfer, a covalent Lewis structure,
or a metallic electron‑sea.

It is a pure‑Swift port of an existing React + Rust/WASM app. **No WebAssembly, FFI, or JS
bridge ships in the binary** — the chemistry domain logic was ported from the Rust
`pt-domain` crate to native Swift and is verified against the original (see
[Testing](#testing)).

- **Platform:** iOS 17.0+, portrait iPhone.
- **Language:** Swift 5 language mode, SwiftUI.
- **Tests:** 96 (61 in `ChemCore`, 35 in the app), all command‑line runnable.

---

## Architecture

The system is three layers, smallest dependency first:

```
┌─────────────────────────────────────────────────────────────┐
│  ChemInteractive  (SwiftUI app target — presentation only)   │
│    State/   Theme/   Diagrams/   Views/                      │
│                          │ reads state, dispatches actions   │
│                          ▼                                    │
├─────────────────────────────────────────────────────────────┤
│  ChemCore  (Swift package — pure, UI-free, fully tested)     │
│    PTDomain → Data → Engine → State (reducer)                │
│                          │ derives every chemistry value     │
│                          ▼                                    │
├─────────────────────────────────────────────────────────────┤
│  elements.raw.json  (118 elements, stored fields only)       │
└─────────────────────────────────────────────────────────────┘
```

**Why this split.** The chemistry is small, deterministic, and worth testing exhaustively,
so it lives in a standalone Swift Package (`ChemCore`) that builds and tests on macOS with
plain `swift test` — no simulator needed. The app target is a thin, declarative SwiftUI
shell: it never computes chemistry, it only reads `ChemCore`'s state and dispatches actions
into `ChemCore`'s reducer.

The app references `ChemCore` as a **local Swift package** (relative path `ChemCore`) via a
hand‑authored `ChemInteractive.xcodeproj` (Xcode 16 `objectVersion = 70`, file‑system‑
synchronized groups — new source files are auto‑discovered, no `pbxproj` editing).

### Module dependencies

Arrows mean "depends on / imports". `ChemCore`'s internal layers are strictly one‑directional;
the app never reaches past `ChemCore`'s public API.

```
            ChemInteractive (app target)
        ┌── State ── Theme ── Diagrams ── Views ──┐
        │          all import ChemCore            │
        └────────────────┬────────────────────────┘
                         │  import ChemCore
                         ▼
   ChemCore  ┌─────────────────────────────────────┐
             │  State ──► Engine ──► Data ──► PTDomain│   (left depends on right)
             └─────────────────────────────────────┘
                         ▲
                         │ loads at runtime
               Resources/elements.raw.json
```

### Unidirectional data flow (Model–View–Update)

The whole app is one loop. A view dispatches an **action**; the model runs it through the
**pure reducer**; the new **state** re‑renders the views. State only ever changes in one
place (`canvasReducer`), so behavior is fully reproducible and testable.

```
        ┌──────────────────────────────────────────────────────────┐
        │                                                          │
        ▼                                                          │
   ┌─────────┐   gesture    ┌──────────────┐   CanvasAction   ┌──────────────┐
   │  Views  │ ───────────► │  CanvasModel │ ───────────────► │ canvasReducer│
   │ (SwiftUI)│             │ (@Observable)│   .send(action)  │  (pure func) │
   └─────────┘              └──────────────┘                  └──────┬───────┘
        ▲                          ▲                                 │
        │   @Environment reads     │      state = reducer(state, …)  │ new CanvasState
        │   model.state            └─────────────────────────────────┘
        └────────────────────────────────────────────────────────────
                        SwiftUI re-renders on @Observable change
```

### Repository layout

```
ios-chem-interactive/
├── ChemCore/                       # the domain package (Plan 1)
│   ├── Package.swift
│   ├── Sources/ChemCore/
│   │   ├── PTDomain/               # periodic-table domain (ported from Rust pt-domain)
│   │   ├── Data/                   # raw element model + loader + derived Element
│   │   ├── Engine/                 # bonding pedagogy (valence, stoich, metallic, gcd)
│   │   ├── State/                  # the canvas state machine (pure reducer)
│   │   └── Resources/elements.raw.json
│   └── Tests/ChemCoreTests/        # 61 XCTests incl. golden WASM-fidelity check
├── ChemInteractive/                # the SwiftUI app (Plans 2 & 3)
│   ├── ChemInteractiveApp.swift    # @main, injects the model
│   ├── State/CanvasModel.swift     # @Observable wrapper over the reducer
│   ├── Theme/                      # Theme.swift, IonFormat.swift
│   ├── Diagrams/LewisLayout.swift  # pure diagram geometry (tested)
│   └── Views/                      # Tray/, Zones/, Bridge/, ChemCanvasView
├── ChemInteractiveTests/           # 35 XCTests for the app's pure helpers
├── ChemInteractive.xcodeproj/      # hand-authored
├── tools/                          # dev-only Node scripts (data generation)
└── docs/superpowers/{specs,plans}/ # design specs + implementation plans
```

---

## Build & run

```bash
# Domain package alone (fast, no simulator):
cd ChemCore && swift test

# Whole app (build + boot + tests in a simulator):
xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17'

# Launch straight into a diagram (DEBUG builds only — see "Debug preview"):
xcrun simctl launch booted com.cheminteractive.app --args -diagramPreview metallic
```

---

## Layer 1 — `ChemCore` (the domain package)

Pure value types and free functions. Everything is derived from an element's atomic number
plus its stored raw data; nothing about bonding is hard‑coded per element.

### `PTDomain/` — periodic‑table domain

A faithful Swift port of the Rust `pt-domain` crate. Its test vectors are translated 1:1
into XCTest.

| Feature | Implementation | File |
| --- | --- | --- |
| Subshells & orbitals | `enum Subshell { s, p, d, f }` with `azimuthal`/`capacity`/`orbitalCount`/`label`; `struct Orbital { n, subshell, electrons }` | `PTDomain/Subshell.swift` |
| Aufbau fill | `aufbauFill(_ z:) -> [Orbital]` walks a hard‑coded **Madelung (n+l) order** table, filling each subshell to capacity | `PTDomain/Aufbau.swift` |
| Validation | `validate(_ z:)` throws `DomainError.invalidAtomicNumber` outside `1...118` | `PTDomain/DomainError.swift` |
| Electron configuration | `electronConfiguration(_ z:) throws -> ElectronConfiguration` = naive Aufbau **+ a ground‑state anomaly table** (Cr, Cu, Nb, Mo, Ru, Rh, Pd, Ag, La, Ce, Gd, Pt, Au, Ac, Th, Pa, U, Np, Cm). Provides `description` (e.g. `"1s2 2s2 2p6 3s2 3p6 3d6 4s2"`), `unpairedElectrons` (Hund's rule), `electrons(in:_:)` | `PTDomain/ElectronConfiguration.swift` |
| Placement | `block`, `period`, `group` (1–18; f‑block → 3 by convention) derived from the configuration | `PTDomain/Classification.swift` |
| Chemistry classification | `category` (10 categories), `elementClass` (`Metal`/`NonMetal`/`Metalloid`), `oxidationStates(_ z:)` — all heuristics over group/block/atomic number | `PTDomain/Classification.swift` |
| Physical calc | `atomicMassFromIsotopes` (abundance‑weighted mean), `isotopeMassMatches`, `stateAt(meltingPoint:boilingPoint:temperatureK:)` | `PTDomain/Calc.swift` |

**Intentional bug fix vs. the React source:** React's `makeZoneState` set
`isTransition = el.block === 'd'`, but the data emits block `"D"` (uppercase), so it was
always `false`. The Swift port uses a `Block` enum and `isTransition = (block == .d)`, so
d‑block elements correctly trigger the transition‑metal charge picker.

### `Data/` — element data

| Feature | Implementation | File |
| --- | --- | --- |
| Raw record | `struct RawElement: Decodable` mirrors the stored fields (atomic number, symbol, masses, melting/boiling points, electronegativity, isotopes…). `decodeAll(from:)` uses `.convertFromSnakeCase` | `Data/RawElement.swift` |
| Derived element | `struct Element` wraps a `RawElement` and computes `block`, `period`, `group`, `category`, `elementClass`, `oxidationStates`, `electronConfiguration`, `computedAtomicMass` at init via `PTDomain` | `Data/Element.swift` |
| Loader | `PeriodicTable.load()` reads the bundled `elements.raw.json` (118 elements) and builds all `Element`s, sorted by atomic number; `bySymbol(_:)`, `byAtomicNumber(_:)` | `Data/PeriodicTable.swift` |
| Data file | `elements.raw.json` — stored fields only, generated from 118 canonical YAML files by `tools/yaml-to-raw-json.mjs` (dev‑time) | `Resources/elements.raw.json` |

### `Engine/` — bonding pedagogy

The teaching logic that lives in the React app (not in Rust). All pure functions.

| Feature | Implementation | File |
| --- | --- | --- |
| Valence electrons | `parseValenceElectrons(config:group:)` strips a noble‑gas prefix, sums the electrons in the highest principal shell (with a group‑based fallback) | `Engine/Valence.swift` |
| Bond classification | `determineBonding(_:_:)` + `bondingType(…)` (see decision tree below) | `Engine/Bonding.swift` |
| Covalent stoichiometry | `calcStoich(veA:veB:) -> (nA, nB, bondOrder)` from octet/duet bonds‑needed and their gcd; `iupacFirst(_:_:)` orders binary formulas by electronegativity | `Engine/CovalentStoich.swift` |
| Metallic count | `metallicElectronCount(veA:veB:poolSize:)` = `min(3·veA + 3·veB, 12)` delocalised electrons | `Engine/Metallic.swift` |
| Math | `gcd(_:_:)` (Euclidean) | `Engine/MathUtil.swift` |

**Bond classification decision tree** (`bondingType`, evaluated on the second drop):

```
                    either side a polyatomic ion?
                       │yes                │no
                       ▼                   ▼
                    IONIC          both sides metal?
                                    │yes          │no
                                    ▼             ▼
                                 METALLIC   both (metalloid│nonmetal)?
                                              │yes            │no
                                              ▼               ▼
                                           COVALENT         IONIC      (e.g. metal + nonmetal)
```

### `State/` — the canvas state machine

A pure value‑type reducer mirroring the React `reducer.ts`. **No reference types, no side
effects** — the same input always yields the same output, which is what makes it
exhaustively testable.

| Type / function | Role | File |
| --- | --- | --- |
| `CanvasPhase` | `selecting → slotAFilled → explaining → animatingCrossover / showingCovalent / showingMetallic → complete` | `State/Phase.swift` |
| `Slot` | `.a` / `.b`, with `.other` | `State/Phase.swift` |
| `ZoneStatus` | `.neutral` / `.deducing` / `.ionized` | `State/Phase.swift` |
| `ZoneState` | a filled slot: symbol, `elementClass`, `isPolyatomic`, `isTransition`, `valenceElectrons`, `oxidationStates`, `derivedCharge`, `status`. Built from an `Element` or a `PolyatomicIon` | `State/ZoneState.swift` |
| `PolyatomicIon` | the 6 hard‑coded ions (OH⁻, NO₃⁻, SO₄²⁻, CO₃²⁻, PO₄³⁻, NH₄⁺) | `State/PolyatomicIon.swift` |
| `CanvasState` | `{ canvasPhase, bondingType?, slotA?, slotB? }`, plus `.initial` | `State/CanvasState.swift` |
| `CanvasAction` | `dropElement(slot:zone:)`, `pickTMCharge(slot:charge:)`, `dismissExplanation`, `replaceElement(slot:)`, `crossoverComplete`, `reset` | `State/CanvasState.swift` |
| `canvasReducer(_:_:)` | the pure transition function. Auto‑ionises ionic pairs on drop, routes transition metals to a `.deducing` charge picker, blocks `dismissExplanation` while a slot is still deducing, restarts when a third token is dropped on two filled slots | `State/CanvasReducer.swift` |

---

## Layer 2 — `ChemInteractive` (the SwiftUI app)

The app adds **zero** chemistry. It wraps `ChemCore`'s reducer in an observable model,
maps state to SwiftUI views, and maps gestures to actions.

### State & data flow

`State/CanvasModel.swift` — `@Observable final class CanvasModel`:

```swift
@Observable final class CanvasModel {
    private(set) var state: CanvasState = .initial
    let elements: [Element]                 // 118, from PeriodicTable.load()
    let polyatomicIons = PolyatomicIon.polyatomicIons
    private(set) var selectedToken: TokenTransfer?

    func send(_ action: CanvasAction) { state = canvasReducer(state, action) }
    func place(_ token: TokenTransfer, in slot: Slot) { … }   // resolve → drop → clear selection
    func zoneState(for token: TokenTransfer) -> ZoneState?    // rebuild a ZoneState via ChemCore
    func select(_:) / clearSelection()
}
```

- The model owns element loading and is injected once at the app root
  (`ChemInteractiveApp.swift`: `@State private var model = CanvasModel()` →
  `.environment(model)`); every view reads it with `@Environment(CanvasModel.self)`.
- **`TokenTransfer { symbol, isPolyatomic }`** is the drag/tap payload — `Codable` +
  `Transferable` (JSON representation). It carries only what's needed to *rebuild* a
  `ChemCore.ZoneState` via the model, so `ZoneState` construction stays in `ChemCore` and is
  never duplicated in the app.

**Dropping a token — the round trip** (drag *and* tap‑to‑place share the same path):

```
ElementTokenView                DropZoneView              CanvasModel                 ChemCore
──────────────────────────────────────────────────────────────────────────────────────────────
.draggable(TokenTransfer) ─────► .dropDestination ──────► place(token, in: slot)
   (symbol, isPolyatomic)          (for: TokenTransfer)        │
                                                               ├─ zoneState(for:) ──► ZoneState(element:)
                                                               │                       or (polyatomic:)
                                                               ├─ send(.dropElement) ► canvasReducer(…)
                                                               │                          │ classify + autoIonize
                                                               └─ clearSelection()     ◄──┘ new CanvasState
                                                                          │
                                                          @Observable change → DropZoneView + tray re-render
```

### Theme & formatting

| Feature | Implementation | File |
| --- | --- | --- |
| Palette | `enum Theme` (`bg #1a0a2e`, `cation #00ff88`, `anion #ff4080`, `accent #7040ff`, `surface`, `muted`, `text`), `Color(hex:)`, category/class/orbital color maps — exact values ported from `index.css` / `elementColor.ts` | `Theme/Theme.swift` |
| Bond hints | `bondHint(firstClass:firstIsPolyatomic:tokenClass:tokenCategory:) -> BondHintKind` (`.ionic`/`.covalent`/`.metallic`/`.none`) drives the tray tint shown after the first drop; noble gases → `.none` (disabled) | `Theme/Theme.swift` |
| Ion text | `superscript(_:)`, `subscriptGlyphs(_:)`, `formatIon(symbol:charge:)` (e.g. `"Mg²⁺"`), `ionicFormula(…)` (gcd‑reduced, parenthesises polyatomic anions: `Ca(OH)₂`), `chargeExplanation(_:)`, `electronsNeeded(_:)` | `Theme/IonFormat.swift` |

> Note: `Category` is qualified as `ChemCore.Category` where it appears, because the iOS 17
> SDK also defines several `Category` types — a bare reference is ambiguous.

### Views

**Root — `Views/ChemCanvasView.swift`.** A `GeometryReader` lays out the tray on top
(~45% height) and the workspace below (`Slot A | Bridge | Slot B` in an `HStack`), with the
explanation modal as a full‑screen `.overlay`.

```
   ┌───────────────────────────────────────────────┐
   │ [ Elements ] [ Polyatomic Ions ]   ● ● ● legend│   ElementTrayView
   │ ┌──┬──┬──┬─────────────────────┬──┬──┬──┐      │     18-col × 7-row Grid
   │ │H │  │  │   …bond-hint tints…  │  │  │He│      │     + f-block rows
   │ ├──┼──┼──┤                     ├──┼──┼──┤      │     (~45% height)
   │ │Li│Be│  │                     │ …│  │Ne│      │
   │ └──┴──┴──┴─────────────────────┴──┴──┴──┘      │
   ├───────────────────────────────────────────────┤
   │   Slot A    │      Bridge       │    Slot B    │   workspace (HStack)
   │  ┌───────┐  │        ⇌          │  ┌───────┐   │     DropZoneView | BridgeView | DropZoneView
   │  │  Na⁺  │  │  [result diagram] │  │  Cl⁻  │   │
   │  └───────┘  │   [ Reset ]       │  └───────┘   │
   └───────────────────────────────────────────────┘
        └─ full-screen ExplanationModalView overlays during .explaining ─┘
```

**Tray — `Views/Tray/`:**

- `ElementTokenView` / `PolyatomicTokenView` — a draggable token. Both use SwiftUI
  `.draggable(TokenTransfer)` for drag and `.onTapGesture` for tap‑to‑select. **`.draggable`
  is attached only in the active branch** of the body, because on iOS 17 `.disabled()` /
  `.allowsHitTesting(false)` do *not* reliably suppress a drag interaction — a disabled
  (noble‑gas, or mid‑animation) token must be neither tappable nor draggable.
- `ElementTrayView` — an 18‑column × 7‑period `Grid` (empty cells where no element sits),
  with f‑block rows below, "Elements" / "Polyatomic Ions" tabs, the bonding legend, and
  per‑token hint tints computed against the single filled slot.

**Zones — `Views/Zones/`:**

- `DropZoneView` — a slot. Accepts a drop via `.dropDestination(for: TokenTransfer.self)` →
  `model.place(token, in: slot)`; a pending tap‑selection can also be placed by tapping the
  zone. Shows the symbol (neutral) or the ion label (ionized), a drop‑over highlight, and a
  `×` clear button that dispatches `.replaceElement`. Slot A is cation‑green, Slot B is
  anion‑pink.
- `TransitionMetalPickerView` — a button per positive oxidation state; tapping dispatches
  `.pickTMCharge`. Rendered inline in the explanation modal when a slot is `.deducing`.

**Bridge (the result column) — `Views/Bridge/`:**

- `ExplanationModalView` — the per‑bond charge‑derivation modal. For ionic it shows a
  per‑slot panel (TM picker when deducing, else the charge explanation) plus the crossover
  summary; "Apply →" dispatches `.dismissExplanation` (disabled while any slot is deducing).
- `BridgeView` — the **phase router**. Shows the `⇌` glyph always and switches on
  `state.canvasPhase` to render the right result view (see [the diagrams](#layer-3--the-result-diagrams)).
  Reset buttons (`ResetButton.swift`) dispatch `.reset`.

### Cation/anion ordering

A single shared `ionicPair(_:_:)` (in `Diagrams/LewisLayout.swift`) decides which slot is
the cation: by `derivedCharge` sign when known, else the Metal/Metalloid is the cation. It
is used by `ExplanationModalView`, `BridgeView`, `CrossoverAnimatorView`, and
`BondingDiagramView` so the polarity is consistent everywhere.

---

## Layer 3 — the result diagrams

When a bond completes, `BridgeView` routes to one of three animated diagrams. All diagram
*geometry that has a correct answer* (counts, central‑atom choice, subscripts, lone‑pair
counts) lives in a pure, **unit‑tested** helper file; the views are thin renderers over it.
Pixel positions and animation timing are deliberately approximate.

```
   ChemCore values            LewisLayout.swift (pure, tested)        SwiftUI view (renderer)
   ───────────────            ───────────────────────────────        ───────────────────────
   ZoneState ───────┐        ┌─ crossoverModel ─► steps, subs ─────► CrossoverAnimatorView
   gcd / calcStoich ├──────► ├─ lewisTransfer  ─► counts, eMoved ──► BondingDiagramView
   metallicCount    │        ├─ covalentLayout ─► central, lone ───► CovalentLewisView
   iupacFirst       ┘        └─ metallic*      ─► count, pattern ──► MetallicSeaView
                              (CORRECTNESS: unit-tested)             (PIXELS: approximate)
```

### `Diagrams/LewisLayout.swift` — the tested geometry spine

| Helper | Returns | Used by |
| --- | --- | --- |
| `ionicPair(_:_:)` | which slot is cation/anion | all ionic views |
| `crossoverModel(cation:anion:)` | reduced subscripts, `showBrackets`/`showGcd`, and the **ordered animation steps** (`isolate → crisscross → [brackets] → [÷gcd] → done`) | `CrossoverAnimatorView` |
| `lewisTransfer(cation:anion:)` | `cCount`, `aCount`, `eMoved`, `anionAfterDots` (capped at 8) | `BondingDiagramView` |
| `dotPositions(_ n:)` | the 8‑slot Lewis dot ring (first `min(n,8)`) | atom rendering |
| `covalentLayout(slotA:slotB:)` | `centralIsA`, `nPeripheral`, `bondOrder`, `centralLone`, `peripheralLone` (central = smaller count; lone pairs from `(ve − bondOrder·n)/2`) | `CovalentLewisView` |
| `peripheralPositions(_:center:distance:)` | atom centres for 1–4 peripherals (5+ collapses to one + an `×N` badge) | `CovalentLewisView` |
| `lonePairAngles(bondAngles:count:)` | `count` of the 8 cardinal/diagonal directions farthest from the bonds | `CovalentLewisView` |
| `metallicIonIndexPattern` / `metallicElectronsShown(_:_:)` | the `[0,1,0,1,0,1]` A/B lattice pattern and the delocalised‑electron count | `MetallicSeaView` |

Each of these is exercised by `ChemInteractiveTests/LewisLayoutTests.swift` with named
vectors (NaCl, MgCl₂, Al₂O₃, CaCO₃, Mg(OH)₂, CO₂, H₂O, N₂, Na/Mg/Al metallic).

**Crossover animation steps** (`crossoverModel.steps`; bracket/÷gcd frames appear only when
relevant — e.g. Mg(OH)₂ gets brackets, CaCO₃ gets ÷gcd, NaCl gets neither):

```
   step:   isolate ──► crisscross ──► [brackets] ──► [÷gcd] ──► done
           ~200ms       ~600ms         ~300ms        ~400ms      │
   shows:  Na  Cl     Mg  Cl₂        Mg (OH)₂      Ca CO₃ ÷2   onComplete()
                      (subs slide in) (anion paren) (reduce)    └─► .crossoverComplete
```

### The four views (`Views/Bridge/`)

| Phase | View | How it's drawn |
| --- | --- | --- |
| `.animatingCrossover` | `CrossoverAnimatorView` | Renders the two symbols with subscripts that animate in. A `.task` steps an index through `crossoverModel.steps` with `withAnimation` and `Task.sleep`; brackets fade in, a `÷g` badge flashes. **Calls `onComplete()` (→ `.crossoverComplete`) unconditionally at the end** so the machine can never softlock. A defensive `else` in `BridgeView` advances the phase even in the impossible nil‑slot case. |
| `.complete` (ionic) | formula text + `BondingDiagramView` | Lewis electron‑transfer for two regular elements (Before: atoms with valence dots; an `Ne⁻ →` arrow; After: charged ions with coefficients and the anion's filled, bracketed octet). Falls back to a simpler charged‑ion view if either is polyatomic. Composed `Circle`/`Text`/`offset` — `AtomCircleView`. |
| `.showingCovalent` | `CovalentLewisView` | All atoms, bonds (`Path`), shared‑pair dots, and lone‑pair dots are positioned with `.position(…)` inside **one** 280×220 `ZStack` (helpers return bare `Group`s so every position resolves in the same coordinate space). Formula ordered by `iupacFirst`. |
| `.showingMetallic` | `MetallicSeaView` | A 3×2 orange cation lattice; the delocalised electrons drift continuously via **`TimelineView(.animation)` + `Canvas`**, each electron on a smooth periodic path with a per‑electron phase offset. |

### Debug preview

`DEBUG` builds accept a launch argument that seeds any diagram state by **replaying real
reducer actions** (so it can't drift from production behavior):

```bash
xcrun simctl launch booted com.cheminteractive.app --args -diagramPreview ionic|covalent|metallic|crossover
```

Implemented as a `#if DEBUG` extension on `CanvasModel` (`debugSeed(_:)`,
`debugPreviewArgument(_:)`) invoked from a `.task` in `ChemInteractiveApp`. Compiled out of
Release.

---

## The phase flow, end to end

```
SELECTING
  │ drop first token
  ▼
SLOT_A_FILLED
  │ drop second token  ── reducer classifies the bond ──┐
  ▼                                                      │
EXPLAINING  (modal: charge derivation; TM picker if deducing)
  │ Apply →                                              │
  ├── ionic ───────► ANIMATING_CROSSOVER ──► COMPLETE (formula + Lewis transfer)
  ├── covalent ────► SHOWING_COVALENT     (Lewis structure)
  └── metallic ────► SHOWING_METALLIC     (electron sea)
                          │ Reset
                          ▼
                       SELECTING
```

Every transition is a pure `canvasReducer` call; the views only *render* the current
`CanvasPhase` and *dispatch* actions.

---

## Testing

| Suite | Count | What it proves |
| --- | --- | --- |
| `ChemCore` PTDomain/Engine/State | 61 | electron configuration (incl. anomalies), block/period/group/category/class/oxidation states, atomic mass, every reducer transition, valence/bonding/stoich/metallic math |
| **Golden fidelity** (`GoldenFidelityTests`) | — | for **all 118 elements**, every Swift‑computed derived field matches the original WASM's output (`elements.golden.json`, generated once by `tools/dump-elements.mjs`) |
| App `LewisLayoutTests` | 13 | the diagram geometry counts (crossover subscripts/steps, Lewis transfer counts, covalent central/lone‑pair counts, metallic count/pattern) |
| App `CanvasModelTests`, `ThemeTests`, `IonFormatTests`, `SmokeTests` | 22 | the model round‑trips actions through the reducer; exact theme hex values + bond‑hint logic; ion formatting strings; ChemCore links and bundled data loads |

**What is *not* unit‑tested:** the SwiftUI views' pixels and animation. Those are verified by
`xcodebuild` compilation, a simulator boot/render gate, and screenshots (the `-diagramPreview`
argument makes each diagram screenshottable). Final confirmation of the live drag‑and‑drop +
animation flows is a manual pass in the simulator.

---

## Notable Swift / SwiftUI design choices

- **Pure value‑type state machine.** `CanvasState` + `canvasReducer` are structs and free
  functions — no `ObservableObject`, no shared mutable state in `ChemCore`. The app's
  `@Observable` `CanvasModel` is the *only* place state is held, and it just forwards to the
  reducer.
- **`Transferable` payload, not the model object.** Drag carries a tiny `Codable`
  `TokenTransfer`; the receiving side rebuilds a `ZoneState` through `ChemCore`. This keeps
  domain construction out of the UI and makes the payload trivially serialisable.
- **Conditional `.draggable`.** Disabled tokens omit the drag modifier entirely, working
  around iOS 17's drag interaction not honoring `.disabled()`.
- **One coordinate space for the covalent diagram.** Every dot/atom/bond is positioned in a
  single fixed‑size `ZStack`; helpers return un‑framed `Group`s so nested `.position(…)`
  calls don't get their own coordinate space.
- **`TimelineView` + `Canvas` for continuous motion.** The electron sea computes positions
  from `timeline.date` each frame — no accumulating animation state, cheap and smooth.
- **Guaranteed phase progress.** The crossover animator always fires its completion callback
  at the end of its step sequence, and the router has a defensive fallback, so the phase
  machine has no softlock path.
- **Hand‑authored Xcode project.** A single app target + a unit‑test target reference
  `ChemCore` as a local package; file‑system‑synchronized groups mean new `.swift` files need
  no project edits.

---

## Provenance

Ported from the React/Rust app at `~/Developer/codews/chem-interactive` (UI/behavior source)
and the Rust workspace `~/Developer/codews/periodic-table` crate `pt-domain` (domain logic
source). Design specs and task‑by‑task implementation plans live in
`docs/superpowers/specs/` and `docs/superpowers/plans/`.
</content>
