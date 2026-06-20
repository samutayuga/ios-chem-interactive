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

## 3. Data & domain strategy

**Authoritative source of chemistry domain logic:** the Rust workspace at
`~/Developer/codews/periodic-table`, crate **`pt-domain`** (the logic that compiles to the
`pt-wasm` the React app uses). It is pure and stateless, and computes every derived field
from atomic number + raw stored data:

- `config.rs` — `electron_configuration(z)` via Madelung (n+l) fill order + a ground-state
  **anomaly table** (Cr, Cu, Nb, Mo, Ru, Rh, Pd, Ag, La, Ce, Gd, Pt, Au, Ac, Th, Pa, U, Np,
  Cm); subshell capacities; `unpaired_electrons` (Hund), `electrons_in(n, subshell)`.
- `classification.rs` — `block`, `period`, `group` (1–18; f-block→3 by convention),
  `category`, `element_class` (Metal/NonMetal/Metalloid), `oxidation_states` — all derived
  from the electron configuration / atomic number, with documented heuristics.
- `calc.rs` — `atomic_mass_from_isotopes` (abundance-weighted), `isotope_mass_matches`,
  `state_at(temperature_k)`.

**Decision (per user direction): port `pt-domain` to Swift** rather than snapshotting the
WASM's computed output. The iOS app carries the real domain model and computes derived
fields from raw data, exactly as Rust does. This is more faithful and more robust than a
frozen JSON snapshot, and the Rust crate's extensive `#[cfg(test)]` vectors translate 1:1
into XCTest fixtures — guaranteeing the port matches the source.

**Raw data**: bundle `elements.raw.json` — only the *stored* fields (atomic_number, name,
symbol, atomic_mass, mass_number, melting_point?, boiling_point?, density?,
electronegativity?, state, discovery_year?, discoverer?, isotopes), the same fields
`pt-domain::Element` holds, sourced from the 118 canonical YAML files in
`periodic-table/data/elements/`. Swift's `PTDomain` computes block/period/group/category/
class/oxidation_states/electron_configuration/computed_atomic_mass at load time.

**Fidelity guarantee**: a committed script also dumps `elements.golden.json` (the full
*computed* output from the existing WASM, already verified to produce 118 elements with
correct fields, e.g. Fe → group 8, period 4, block D, TransitionMetal, oxidation_states
[2,3], computed_atomic_mass ≈ 55.845). An XCTest loads this golden file and asserts every
Swift-computed derived field matches the WASM for all 118 elements. The app ships only
`elements.raw.json` + `PTDomain`; the golden file is a test fixture.

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
│   ├── PTDomain/                          # faithful Swift port of Rust crate pt-domain
│   │   ├── ElectronConfiguration.swift    # port config.rs (Madelung + anomalies, Hund)
│   │   ├── Classification.swift           # port classification.rs (block/period/group/
│   │   │                                  #   category/element_class/oxidation_states)
│   │   └── Calc.swift                     # port calc.rs (atomic mass, state_at)
│   ├── Data/
│   │   ├── RawElement.swift               # Codable, mirrors pt-domain::Element (stored)
│   │   ├── Element.swift                  # RawElement + PTDomain-computed derived fields
│   │   ├── PolyatomicIon.swift            # 6 constants
│   │   └── PeriodicTable.swift            # loads elements.raw.json (replaces WasmProvider)
│   ├── Engine/                            # bonding pedagogy logic (lives in React/TS, not Rust)
│   │   ├── Valence.swift                  # valence electrons for bonding (port valence.ts,
│   │   │                                  #   driven by PTDomain electron configuration)
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
│       ├── elements.raw.json              # shipped: raw stored fields only
│       └── Assets.xcassets
├── ChemInteractiveTests/                  # XCTest: PTDomain/ + Engine/ + State/ + golden
│   └── Fixtures/elements.golden.json      # test-only: full computed dump from WASM
├── tools/dump-elements.mjs                # WASM → elements.golden.json (full computed)
├── tools/yaml-to-raw-json.mjs             # 118 YAML → elements.raw.json (stored fields)
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

## 6. Chemistry logic (two layers, both pure & unit-tested)

**Layer 1 — `PTDomain` (port of Rust `pt-domain`):** the authoritative element model.
Reproduces `config.rs`, `classification.rs`, `calc.rs` in Swift, computing from atomic
number + raw data: electron configuration (Madelung order + anomaly table + Hund),
block/period/group/category/element_class/oxidation_states, atomic-mass-from-isotopes,
state_at. Built **test-first**, translating the Rust crate's own `#[cfg(test)]` vectors
into XCTest (e.g. Cr/Cu/Pd anomalies, Fe config, group/category/oxidation_states tables,
La/Lr boundary, chlorine weighted mass).

**Layer 2 — `Engine` (port of React/TS bonding pedagogy):** logic that lives in the React
app, not in Rust.
- **Valence** — valence electrons for bonding, matching `valence.ts` semantics but driven
  by the authoritative `PTDomain` electron configuration; group-based fallback
  `group<=2 ? group : group>=13 ? group-10 : 0`.
- **gcd** — Euclidean; reduces ionic subscripts and covalent stoich.
- **Bonding** — `determineBonding` (Metal+Metal→Metallic; NonMetal/Metalloid pair→Covalent;
  else Ionic) + `autoIonize` (transition/empty oxidation_states→DEDUCING else IONIZED with
  first oxidation state). Polyatomic involved → always Ionic.
- **CovalentStoich** — `shellTarget(ve)= ve<=2 ?2:8`; `bondsNeeded = max(0,target-ve)`;
  stoich via gcd → `nA,nB,bondOrder`. IUPAC ordering table (B…F) decides leading symbol.
- **Metallic** — `electronCount = min(3*veA + 3*veB, 12)`.

Layer 2 is built **test-first** with known compounds as fixtures (NaCl, CaO, MgCl₂, HCl,
CO₂, H₂O, N₂, Fe/Cu alloys, etc.).

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

- **Unit (XCTest, TDD):** `PTDomain/` (electron configuration incl. anomalies, block/period/
  group/category/element_class/oxidation_states, atomic mass, state_at — translated from the
  Rust crate's test vectors); `Engine/` (valence, gcd, covalent stoich, IUPAC order, metallic
  count); `State/` (every reducer transition — mirrors the React reducer tests).
- **Golden fidelity:** a test loads `Fixtures/elements.golden.json` (full computed WASM dump)
  and asserts that, for all 118 elements, `PTDomain`-computed block/period/group/category/
  class/oxidation_states/electron_configuration/computed_atomic_mass match the WASM exactly.
- **Data:** a test asserts `elements.raw.json` loads to 118 elements and spot-checks Fe
  (oxidation_states [2,3], TransitionMetal, group 8 period 4).
- **Build/boot:** `xcodebuild -scheme ChemInteractive -destination
  'platform=iOS Simulator,name=iPhone 17'` compiles and launches in the simulator.

## 10. Risks

- **`PTDomain` port fidelity** (Rust → Swift). Mitigation: translate the Rust crate's own
  test vectors into XCTest, and run the golden-file assertion against the WASM's computed
  output for all 118 elements — a regression there fails the build.
- **Hand-authored pbxproj** is fiddly. Mitigation: keep one target, verify early and often
  with `xcodebuild`; treat a clean build as the gate before adding views.
- **Diagram animation fidelity** (Framer Motion → SwiftUI) is approximate, not pixel-exact.
  Acceptable: parity is behavioral (correct chemistry + comparable motion), not pixel-perfect.
- **Periodic-table legibility on a narrow screen.** Mitigation: horizontal scroll + tap to
  enlarge/tooltip, as the React app already does on mobile.
