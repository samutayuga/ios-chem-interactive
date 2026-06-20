# iOS ChemInteractive — Native Swift Port Design

**Date:** 2026-06-20
**Status:** Approved (design), pending implementation plan
**Source app:** `/Users/samutup/Developer/codews/chem-interactive` (React 19 + TypeScript + Vite + WASM)
**Target:** `/Users/samutup/Developer/codews/ios-chem-interactive` (native SwiftUI iPhone app)

## 1. Goal

Port the React chemistry-bonding education app to a native SwiftUI iPhone app at
**full feature parity**. A student drags two elements (or a polyatomic ion) into two
drop zones; the app detects the bond type (Ionic / Covalent / Metallic), explains the
charge/electron logic, and renders an animated result diagram.

Non-goals: iPad-specific layout, macOS, Android, App Store submission assets, the
periodic-table "extra" data (melting/boiling points, isotopes) beyond what bonding needs
(though the full data is bundled, so it is available for later features).

## 2. Approach (selected: A)

Native SwiftUI app + pure-Swift chemistry engine + element data baked into the bundle as
JSON dumped from the existing WASM. No Rust/FFI (Approach B) and no WebView wrapper
(Approach C). Rationale: only Approach A is a genuine native Swift app without a
disproportionate toolchain; the chemistry logic is small and well-isolated, so porting is
low-risk and unit-testable.

## 3. Data strategy

The React app's 118 elements live in a compiled Rust→WASM binary. Swift cannot read it
directly. A **one-time build-time Node script** (run from the React repo) dumps the exact
objects the React app consumes:

```js
import { PeriodicTable } from './src/wasm/pkg/pt_wasm.js';
const all = PeriodicTable.load().all();   // 118 elements, verified
// write JSON array to ios-chem-interactive/ChemInteractive/Resources/elements.json
```

Verified output includes all derived fields: `group`, `period`, `block` ("S/P/D/F"),
`category` (e.g. `TransitionMetal`), `class` ("Metal"/"NonMetal"/"Metalloid"),
`oxidation_states`, `electron_configuration`, `computed_atomic_mass`, `mass_number`,
`isotopes`. This is byte-for-byte the same data the React UI sees — no reconstruction.

`elements.json` is committed into the iOS repo (not regenerated at app runtime). The dump
script is also committed for reproducibility.

The 6 polyatomic ions are hardcoded constants (matching `src/canvas/constants.ts`):
OH⁻, NO₃⁻, SO₄²⁻, CO₃²⁻, PO₄³⁻, NH₄⁺.

## 4. Project structure

Hand-authored `ChemInteractive.xcodeproj` (single SwiftUI app target, deployment target
**iOS 17.0**, portrait iPhone). No XcodeGen/Tuist dependency. Verified by `xcodebuild`.

```
ios-chem-interactive/
├── ChemInteractive.xcodeproj/
├── ChemInteractive/
│   ├── ChemInteractiveApp.swift          # @main
│   ├── Data/
│   │   ├── Element.swift                  # Codable, mirrors WasmElement
│   │   ├── PolyatomicIon.swift            # 6 constants
│   │   └── PeriodicTable.swift            # loads elements.json (replaces WasmProvider)
│   ├── Engine/                            # pure Swift, no UI — fully unit-tested
│   │   ├── Valence.swift                  # parseValenceElectrons (port valence.ts)
│   │   ├── MathUtil.swift                 # gcd (port gcd.ts)
│   │   ├── Bonding.swift                  # determineBonding + autoIonize (port reducer.ts)
│   │   ├── CovalentStoich.swift           # octet stoich + IUPAC order (port CovalentView.tsx)
│   │   └── Metallic.swift                 # electron count (port MetallicView.tsx)
│   ├── State/
│   │   ├── CanvasModel.swift              # @Observable state machine (port reducer.ts)
│   │   ├── ZoneState.swift
│   │   └── Phase.swift                    # CanvasPhase / BondingType enums
│   ├── Views/
│   │   ├── ChemCanvasView.swift           # root layout
│   │   ├── Tray/ElementTrayView.swift     # 18-col grid + Elements/Polyatomic tabs + hints
│   │   ├── Tray/ElementTokenView.swift    # draggable + tap-select + tooltip
│   │   ├── Tray/PolyatomicTokenView.swift
│   │   ├── Zones/DropZoneView.swift       # slots A/B, drop highlight, × clear
│   │   ├── Zones/TransitionMetalPickerView.swift
│   │   ├── Bridge/BridgeView.swift        # phase router
│   │   ├── Bridge/ExplanationModalView.swift
│   │   ├── Bridge/CrossoverAnimatorView.swift   # ionic result
│   │   ├── Bridge/BondingDiagramView.swift      # Lewis electron-transfer (Canvas)
│   │   ├── Bridge/CovalentLewisView.swift        # Lewis structure (Canvas)
│   │   └── Bridge/MetallicSeaView.swift          # electron sea (Canvas + TimelineView)
│   ├── Theme/Theme.swift                  # exact colors from index.css / elementColor.ts
│   └── Resources/
│       ├── elements.json
│       └── Assets.xcassets
├── ChemInteractiveTests/                  # XCTest: Engine/ + State/
├── tools/dump-elements.mjs                # the data dump script
└── docs/superpowers/specs/…
```

## 5. State machine (port of `reducer.ts`)

`CanvasModel` is an `@Observable` class. Phases:

```
SELECTING → SLOT_A_FILLED → EXPLAINING
  → (Ionic)    ANIMATING_CROSSOVER → COMPLETE
  → (Covalent) SHOWING_COVALENT
  → (Metallic) SHOWING_METALLIC
```

`ZoneState`: `symbol, elementClass, isPolyatomic, isTransition, valenceElectrons,
oxidationStates, derivedCharge?, wrongCount, status (NEUTRAL/DEDUCING/IONIZED)`.

Actions ported exactly: `dropElement(slot,zone)`, `pickTMCharge(slot,charge)`,
`dismissExplanation()`, `replaceElement(slot)`, `crossoverComplete()`, `reset()`.

Key rules carried over verbatim:
- Both slots filled + new drop → clears the *other* slot, restarts at SLOT_A_FILLED.
- Bond type: Metal+Metal → Metallic; (NonMetal/Metalloid)+(NonMetal/Metalloid) → Covalent;
  else Ionic. Any polyatomic ion involved → always Ionic.
- `autoIonize`: transition metal or empty oxidation_states → DEDUCING (needs picker);
  else IONIZED with `oxidation_states[0]`.
- `dismissExplanation` is blocked for Ionic while either slot is still DEDUCING.

## 6. Chemistry engine (pure, unit-tested)

- **Valence** — strip noble-gas prefix, parse subshells, return highest-shell electron
  count; fallback `group<=2 ? group : group>=13 ? group-10 : 0`.
- **gcd** — Euclidean; used to reduce ionic subscripts and covalent stoich.
- **CovalentStoich** — `shellTarget(ve)= ve<=2 ?2:8`; `bondsNeeded = max(0,target-ve)`;
  stoich via gcd of bonds needed → `nA,nB,bondOrder`. IUPAC ordering table (B…F) decides
  which symbol is written first.
- **Metallic** — `electronCount = min(3*veA + 3*veB, 12)`.

These mirror `valence.ts`, `gcd.ts`, `CovalentView.tsx`, `MetallicView.tsx` and are the
deterministic core — built **test-first** with XCTest, using known compounds as fixtures
(NaCl, CaO, MgCl₂, HCl, CO₂, H₂O, N₂, Fe/Cu alloys, etc.).

## 7. UI / interaction

- **Layout:** tray on top (~45% height), workspace below (Slot A | Bridge | Slot B),
  portrait-first, matching the React mobile layout.
- **Tray:** horizontally scrollable 18-column grid so tokens stay legible on iPhone; f-block
  (lanthanides/actinides) rendered below; tabs "Elements" / "Polyatomic Ions"; after the
  first drop, remaining tokens get bond-hint tints (ionic=blue, covalent=green,
  metallic=orange; noble gases faded/disabled).
- **Drag & drop:** SwiftUI `.draggable` / `.dropDestination` carrying a token identifier
  (`Transferable`), with **tap-to-select** parity (tap a token → fills next empty slot),
  matching dnd-kit + tap in React. Drop zones show a highlight on hover/drag-over.
- **Explanation modal:** charge derivation per bond type; inline transition-metal charge
  picker when a slot is DEDUCING; "Apply →" advances the phase.
- **Result diagrams** (SwiftUI `Canvas`):
  - Ionic: animated crossover (charges → subscripts → gcd reduction) via `withAnimation`
    / `matchedGeometryEffect`, plus Lewis electron-transfer before/after.
  - Covalent: Lewis structure — central atom, peripheral atoms (1–4 layout, simplified >4),
    shared-pair dots and lone-pair dots placed geometrically.
  - Metallic: electron-sea model — 3×2 cation lattice (alternating A/B for alloys) with
    animated electrons via `TimelineView` + `Canvas` (sine-wave motion).
- **Reset / replace:** × on each zone clears it (resets the other to NEUTRAL); Reset
  returns to SELECTING.

## 8. Theme

Port exact values into a Swift `Theme`/asset catalog: bg `#1a0a2e`, cation `#00ff88`,
anion `#ff4080`, accent `#7040ff`, surface `#2a1a4e`, muted `#4a3a6e`; the 8 element
category colors from `elementColor.ts`; bond-hint tints; orbital colors (s/p/d/f). System
font.

## 9. Testing & verification

- **Unit (XCTest, TDD):** `Engine/` (valence, gcd, covalent stoich, IUPAC order, metallic
  count) and `State/` (every reducer transition — mirrors the React reducer tests).
- **Data:** a test asserts `elements.json` loads to 118 elements and spot-checks Fe
  (oxidation_states [2,3], TransitionMetal, group 8 period 4).
- **Build/boot:** `xcodebuild -scheme ChemInteractive -destination
  'platform=iOS Simulator,name=iPhone 17'` compiles and launches in the simulator.

## 10. Risks

- **Hand-authored pbxproj** is fiddly. Mitigation: keep one target, verify early and often
  with `xcodebuild`; treat a clean build as the gate before adding views.
- **Diagram animation fidelity** (Framer Motion → SwiftUI) is approximate, not pixel-exact.
  Acceptable: parity is behavioral (correct chemistry + comparable motion), not pixel-perfect.
- **Periodic-table legibility on a narrow screen.** Mitigation: horizontal scroll + tap to
  enlarge/tooltip, as the React app already does on mobile.
