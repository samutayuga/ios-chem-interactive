# ChemInteractive — Result Diagrams Design (Plan 3)

**Date:** 2026-06-20
**Status:** Approved (design), pending implementation plan
**Builds on:**
- Master design: `docs/superpowers/specs/2026-06-20-ios-chem-interactive-design.md` (§7 result diagrams)
- UI-layer design: `docs/superpowers/specs/2026-06-20-chem-interactive-app-ui-design.md` (§6 Plan 3, high level)
- Plan 1 (done): `ChemCore` Swift package — domain + bonding engine.
- Plan 2 (done): `ChemInteractive` SwiftUI app — interactive skeleton with the three result
  diagrams **stubbed** as placeholder boxes.

## 1. Goal & context

Plan 2 delivered the full interactive app on top of `ChemCore`, with the three result
diagrams rendered as placeholder boxes (`DiagramPlaceholders.swift`) that surface
`ChemCore`-computed values so the phase machine runs end-to-end. Plan 3 **replaces those
stubs with the real animated SwiftUI diagrams**, completing the app.

The fidelity source is the reference React app at `~/Developer/codews/chem-interactive/src`:
`bridge/CrossoverAnimator.tsx`, `bridge/BondingDiagram.tsx`, `bridge/CovalentView.tsx`,
`bridge/MetallicView.tsx`. Animation fidelity is **behavioral/approximate, not pixel-exact**
(per the Plan-2 spec §6): the diagrams convey the same information and genuinely animate the
two "wow" moments (the ionic crossover and the metallic electron sea); exact timing, easing,
and motion paths are approximations.

The app adds **no** chemistry logic. All bonding math already lives in tested `ChemCore`
(`gcd`, `calcStoich`, `metallicElectronCount`, `iupacFirst`, `ZoneState`). Plan 3 adds only
presentation **geometry** (pure, partially unit-tested) and SwiftUI **rendering**
(visual-gated). `ChemCore` is consumed as-is and is not modified.

## 2. Decision summary (from brainstorming)

- **Animation:** animated, approximate. The ionic 4-step crossover and the continuous
  metallic electron-sea drift are genuinely animated; the Lewis-transfer and covalent
  diagrams are correct static geometry.
- **Rendering (Approach A — hybrid):** composed SwiftUI views (`Circle` + native `Text`
  positioned in a `ZStack`/`.position`, dots as small `Circle`s, bonds as `Path`s) with
  `withAnimation` for the discrete crossover steps; `TimelineView(.animation)` + `Canvas`
  for the continuous metallic electron sea. Native `Text` keeps glyphs crisp; the discrete
  crossover steps animate trivially; the pure geometry is render-independent and testable.
- **Testing:** test the chemistry-meaningful counts and discrete logic (lone-pair counts,
  central/peripheral choice, shared/lone dot counts, crossover step model, electron count,
  lattice index pattern) as pure helpers with XCTest; verify pixel positions, angles, and
  motion by build + boot + screenshot + a human interactive pass.
- **Debug aid:** a `DEBUG`-only launch argument boots the app directly into a chosen diagram
  state so each diagram is CLI-screenshottable.

## 3. Architecture & file changes

New and changed files under the existing `ChemInteractive/` app target (file-system-
synchronized — new files are auto-discovered; no `.xcodeproj` editing):

```
ChemInteractive/
├── Diagrams/
│   └── LewisLayout.swift                 # NEW — pure geometry/count helpers (unit-tested)
├── Views/Bridge/
│   ├── ResetButton.swift                 # NEW — relocated shared Reset button (was in DiagramPlaceholders)
│   ├── CrossoverAnimatorView.swift       # NEW — ionic 4-step crossover (replaces .animatingCrossover spinner)
│   ├── BondingDiagramView.swift          # NEW — ionic Lewis electron-transfer (replaces IonicCompletePlaceholder)
│   ├── CovalentLewisView.swift           # NEW — covalent Lewis structure (replaces CovalentPlaceholder)
│   ├── MetallicSeaView.swift             # NEW — metallic electron sea (replaces MetallicPlaceholder)
│   ├── BridgeView.swift                  # MODIFY — route phases to the real diagrams
│   ├── ExplanationModalView.swift        # MODIFY — use the shared ionicPair from LewisLayout
│   └── DiagramPlaceholders.swift         # DELETE — its three stub views are replaced
├── State/CanvasModel.swift               # MODIFY — add a DEBUG-only seed seam (see §8)
└── ChemInteractiveApp.swift              # MODIFY — read the DEBUG launch argument (see §8)
ChemInteractiveTests/
└── LewisLayoutTests.swift                # NEW — unit tests for the pure helpers
```

**Deployment / language:** unchanged from Plan 2 — iOS 17, Swift 5 language mode, portrait
iPhone. `TimelineView`, `Canvas`, and `withAnimation` are all iOS 17-available.

## 4. The pure geometry layer — `Diagrams/LewisLayout.swift`

All functions are pure (no SwiftUI), consume `ChemCore` values, and are unit-tested. This is
the "test the counts" spine; rendering views read from these.

### 4.1 Shared cation/anion ordering

```
func ionicPair(_ a: ZoneState, _ b: ZoneState) -> (cation: ZoneState, anion: ZoneState)
```
Ported from the existing duplicated helper: prefer `derivedCharge` sign (positive = cation);
when charges are not both known, the Metal/Metalloid is the cation. **This single copy
replaces the duplicates in `DiagramPlaceholders.swift` and `ExplanationModalView.swift`**
(retiring the deferred Plan-2 review item). `ExplanationModalView` is refactored to call it.

### 4.2 Crossover model (ionic animation)

```
enum CrossoverStep { case isolate, crisscross, brackets, gcdReduce, done }
struct CrossoverModel {
    let cationSymbol: String, anionSymbol: String
    let cationSub: Int, anionSub: Int    // gcd-reduced subscripts
    let gcdValue: Int
    let showBrackets: Bool, showGcd: Bool
    let steps: [CrossoverStep]           // the actual ordered sequence to play
}
func crossoverModel(cation: ZoneState, anion: ZoneState) -> CrossoverModel
```
Logic (from `CrossoverAnimator.tsx`): let `cc = |cation.derivedCharge|`, `ac =
|anion.derivedCharge|`, `g = gcd(ac, cc)`; `cationSub = ac / g`, `anionSub = cc / g`;
`showBrackets = anion.isPolyatomic && anionSub > 1`; `showGcd = g > 1`. `steps` always begins
`[.isolate, .crisscross, …]`, inserts `.brackets` only when `showBrackets`, inserts
`.gcdReduce` only when `showGcd`, and ends with `.done`.

### 4.3 Lewis electron-transfer model (ionic, both regular)

```
struct LewisTransfer { let cCount: Int, aCount: Int, eMoved: Int, anionAfterDots: Int }
func lewisTransfer(cation: ZoneState, anion: ZoneState) -> LewisTransfer
```
`g = gcd(|cc|, |ac|)`; `cCount = |ac| / g`; `aCount = |cc| / g`; `eMoved = |cc|`;
`anionAfterDots = min(anion.valenceElectrons + |ac|, 8)`.

### 4.4 Electron dot ring

```
func dotPositions(_ n: Int) -> [(dx: CGFloat, dy: CGFloat)]
```
The 8-slot ring from `BondingDiagram.tsx` (`DOT_OFFSETS`): right, top, left, bottom, then the
four paired offsets. Returns the first `min(n, 8)` offsets.

### 4.5 Covalent layout

```
struct CovalentLayout {
    let centralIsA: Bool
    let nPeripheral: Int
    let bondOrder: Int
    let centralLone: Int, peripheralLone: Int
}
func covalentLayout(slotA: ZoneState, slotB: ZoneState) -> CovalentLayout
func peripheralPositions(_ nPeripheral: Int, center: CGPoint, distance: CGFloat) -> [CGPoint]
func lonePairAngles(bondAngles: [Double], count: Int) -> [Double]
```
- `covalentLayout` uses `ChemCore.calcStoich(veA:veB:) -> (nA, nB, bondOrder)`. `centralIsA =
  nA <= nB` (central = smaller count); `nPeripheral = centralIsA ? nB : nA`. `centralLone =
  max(0, (ve_central − bondOrder·nPeripheral) / 2)`; `peripheralLone = max(0, (ve_peripheral
  − bondOrder) / 2)` (integer division). **These counts are unit-tested.**
- `peripheralPositions` handles `nPeripheral` 1 (linear), 2 (left/right), 3 (one left + two
  at ±60°), 4 (top/right/bottom/left); `>4` returns a single position (the view shows an
  `×N` badge — the reference's simplification). The *count* of returned positions is tested;
  exact pixels are visual.
- `lonePairAngles` chooses `count` directions from the 8 cardinal/diagonal slots farthest
  from all `bondAngles` (ported from `lonePairAngles` in `CovalentView.tsx`). The returned
  count and chosen slots are tested; pixel rendering is visual.

### 4.6 Metallic layout

```
let metallicIonIndexPattern: [Int]              // [0,1,0,1,0,1] — A/B alternation over the 3×2 lattice
func metallicElectronsShown(slotA: ZoneState, slotB: ZoneState) -> Int   // == ChemCore.metallicElectronCount(...)
```
`metallicElectronsShown` wraps `ChemCore.metallicElectronCount(veA:veB:)` (= `min(3·veA +
3·veB, 12)`); the wiring is unit-tested. Lattice and electron-pool pixel coordinates live in
the view (visual-only).

## 5. The four diagram views

### 5.1 `CrossoverAnimatorView` (phase `.animatingCrossover`)

Props: `cation`, `anion`, `onComplete: () -> Void`. Renders `cationSymbol`/`anionSymbol` with
their reduced subscripts and (when `showBrackets`) parentheses around the anion. A `.task`
steps an index through `model.steps` with approximate per-step sleeps (~200 ms isolate,
~600 ms crisscross, ~300 ms brackets, ~400 ms gcdReduce), animating subscript/bracket
appearance with `withAnimation`; a `÷g` badge flashes during `.gcdReduce`. **On reaching
`.done` it calls `onComplete()`** → `model.send(.crossoverComplete)`. `onComplete` is
guaranteed to fire at the end of the sequence so the phase machine cannot softlock. Replaces
the Plan-2 `ProgressView` + `DispatchQueue.main.async` auto-fire.

### 5.2 `BondingDiagramView` (phase `.complete`, ionic)

Props: `cation`, `anion`. Uses `ionicPair`. If **both are regular elements**: a Lewis
electron-transfer — "Before" row (cation with `cation.valenceElectrons` dots `+` anion with
`anion.valenceElectrons` dots), an "`eMoved`e⁻ →" arrow, "After" row (`cCount ×` cation with
0 dots + charge superscript, `aCount ×` anion with `anionAfterDots` dots, bracketed, +
charge). If **either is polyatomic**: the simpler charged-ion view (coefficients + bracketed
ion, no Lewis dots — the reference's `SimpleIonDiagram`). Atom circles use cation/anion
colors; dots placed via `dotPositions`. The final formula above reuses `ionicFormula(...)`
(Plan-2 Task 4). In `BridgeView`, this view is shown with a Reset button.

### 5.3 `CovalentLewisView` (phase `.showingCovalent`)

Props: `slotA`, `slotB`. Reads `covalentLayout(...)`. Draws the central atom (radius 42) and
`nPeripheral` peripheral atoms (radius 38 for n=1 else 30) at `peripheralPositions(...)`,
overlapping so circles touch. Per bond: `bondOrder` shared-pair dots along the bond axis (two
colors). Lone pairs: `centralLone` / `peripheralLone` dot-pairs at `lonePairAngles(...)` in
pale blue-white. For `nPeripheral > 4`: a single peripheral atom + an `×N` badge. Formula
ordered by `ChemCore.iupacFirst`; homonuclear → symbol + `(nA+nB)` subscript. Caption:
"Single/Double/Triple covalent bond · N shared pair(s) per bond." Shown with Reset.

### 5.4 `MetallicSeaView` (phase `.showingMetallic`)

Props: `slotA`, `slotB`. 6 cations in a 3×2 lattice, A/B alternated via
`metallicIonIndexPattern` (homonuclear → all the same symbol), orange family, each with a
small `+`. A 12-slot electron-position pool, first `metallicElectronsShown(...)` taken. A
`TimelineView(.animation)` drives a `Canvas` drawing each electron as a yellow dot moving
along a smooth periodic path (approximating the reference's `x0 → x0+dx → x0+dx·0.4 → x0`
keyframe loop) with a per-electron phase/period offset so they drift continuously and out of
sync. Below: the orange-ion / yellow-e⁻ legend, formula (`A` homonuclear else `A + B`), and
the electrostatic-attraction caption. Shown with Reset.

## 6. Phase-machine wiring (`BridgeView`)

`BridgeView` keeps the `⇌` glyph and switches on `state.canvasPhase`; only the result
branches change from Plan 2:

| Phase | Plan 2 (stub) | Plan 3 |
|---|---|---|
| `.animatingCrossover` | `ProgressView` auto-fires `.crossoverComplete` | `CrossoverAnimatorView(cation:anion:) { model.send(.crossoverComplete) }` |
| `.complete` | `IonicCompletePlaceholder` | formula (`ionicFormula`) + `BondingDiagramView` + Reset |
| `.showingCovalent` | `CovalentPlaceholder` | `CovalentLewisView` + Reset |
| `.showingMetallic` | `MetallicPlaceholder` | `MetallicSeaView` + Reset |

`selecting`, `slotAFilled`, and `.explaining` paths are unchanged. Cation/anion ordering uses
the shared `ionicPair`. `DiagramPlaceholders.swift` is deleted; its `ResetButton` is
relocated to `Views/Bridge/ResetButton.swift` (shared by the three result views) and its
`ionicPair` moves to `LewisLayout.swift`.

## 7. Testing & verification

**Unit (`ChemInteractiveTests/LewisLayoutTests.swift`, TDD):**
- Crossover model: NaCl → subs (1,1), `!showBrackets`, `!showGcd`, steps
  `[.isolate, .crisscross, .done]`; MgCl₂ → (1,2); Al₂O₃ → (2,3); **CaCO₃** → (1,1),
  `showGcd`, steps contain `.gcdReduce`; **Mg(OH)₂** → (1,2), `showBrackets`, steps contain
  `.brackets`.
- Lewis transfer: NaCl → `cCount 1, aCount 1, eMoved 1, anionAfterDots 8`; an Al/O case →
  `cCount 2, aCount 3`.
- `dotPositions`: returns `min(n, 8)` offsets; order matches the ring.
- Covalent layout: **CO₂** → centralIsA (C central), `nPeripheral 2`, `centralLone 0`,
  `peripheralLone 2`, `bondOrder 2`; **H₂O** → O central, `nPeripheral 2`, `centralLone 2`,
  `peripheralLone 0`, `bondOrder 1`; **N₂** → central N, `nPeripheral 1`, `centralLone 1`,
  `bondOrder 3`. `peripheralPositions` returns the right count for n = 1…5.
  `lonePairAngles` returns `count` angles drawn from the 8 slots, none coincident with a
  bond angle.
- Metallic: `metallicElectronsShown` — Na+Na → 6, Mg+Mg → 12 (capped), Al+Al → 12 (capped);
  `metallicIonIndexPattern == [0,1,0,1,0,1]`.

**Visual gate (honest; matches Plan 2's model):** `xcodebuild build` + simulator boot + the
full suite green. Each diagram view ships a `#Preview` with representative `ZoneState` data
so it renders in Xcode. The `DEBUG` launch argument (§8) makes each diagram CLI-
screenshottable. Final pixel/motion confirmation of all four flows is a **human interactive
pass** (drag Na+Cl → crossover → Lewis NaCl; Fe+Cl ionic; O+O / CO₂ covalent; Na+Mg metallic
sea) — the same pending-smoke model Plan 2 used.

## 8. DEBUG direct-to-diagram launch argument

To make each diagram screenshottable from the CLI, a `DEBUG`-only launch argument seeds the
app into a terminal diagram state on launch:

- `ChemInteractiveApp` reads `ProcessInfo.processInfo.arguments` (only under `#if DEBUG`);
  if it contains `-diagramPreview <ionic|covalent|metallic|crossover>`, it tells the model to
  seed that state before first render.
- `CanvasModel` gains a `#if DEBUG func debugSeed(_ which: DiagramPreview)` that **replays
  real reducer actions** (no bespoke state construction), e.g.:
  - `ionic` → place Na, place Cl, `dismissExplanation`, `crossoverComplete` → `.complete`.
  - `crossover` → place Na, place Cl, `dismissExplanation` → `.animatingCrossover`.
  - `covalent` → place O, place O, `dismissExplanation` → `.showingCovalent`.
  - `metallic` → place Na, place Mg, `dismissExplanation` → `.showingMetallic`.
- Usage: `xcrun simctl launch <device> com.cheminteractive.app --args -diagramPreview metallic`.
- The seam is compiled out of Release builds. It reuses the tested reducer, so it cannot
  drift from real behavior.

## 9. Risks

- **Crossover softlock.** If `onComplete` failed to fire, `.animatingCrossover` would never
  advance. Mitigation: `onComplete` is called unconditionally at the end of the `.task`
  sequence; a `#Preview`/DEBUG-seed exercises the path; the human pass confirms it.
- **`TimelineView` + `Canvas` electron motion.** New SwiftUI surface. Mitigation: motion is
  approximate; positions are computed from `timeline.date` so there is no accumulating
  state; the electron count and lattice come from tested helpers.
- **Covalent geometry for unusual stoichiometries.** Mitigation: the count logic is unit-
  tested for CO₂/H₂O/N₂; `>4` peripheral is explicitly simplified; pixel layout is visual.

## 10. Out of scope

Pixel-exact replication; full polyhedral layout for >4 peripheral atoms (simplified to a
single atom + `×N`); iPad/macOS layouts; haptics/sound; reduce-motion beyond an optional
skip-to-final-state; any change to `ChemCore` (consumed as-is); App Store assets.
</content>
