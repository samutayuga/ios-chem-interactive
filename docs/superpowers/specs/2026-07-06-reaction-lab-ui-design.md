# Reaction Lab — App UI (ChemInteractive)

**Date:** 2026-07-06
**Status:** Approved design, ready for implementation planning
**Scope:** iOS SwiftUI app UI only. Consumes the ChemCore compound-reactant engine. No redox calculator.

## Summary

The ChemCore compound-reactant engine ([2026-07-06-compound-reactant-engine-design.md](2026-07-06-compound-reactant-engine-design.md), branch `feat/compound-reactant-engine`) can classify a reaction between two compound reactants, predict products, balance the equation, and compute limiting reactant + per-product yields. This spec adds the iOS UI that drives it: **Reaction Lab**, a new third mode alongside the existing Bonding and (synthesis) Stoichiometry flows.

In Reaction Lab the student assembles **two reactant compounds**, each from **1–2 species** (element or polyatomic ion) dropped from the shared periodic tray, and sees the classified, balanced reaction with yields render live. Non-reacting inputs surface as a friendly "no reaction" (infeasible single displacement) or "not classified" state rather than an error.

**Dependency:** this work builds on `feat/compound-reactant-engine` being merged (or based on it). It calls the engine's `solveReaction`, `makeReactant`, `Species`, `Reactant`, `ReactionResult`, `ReactionError`.

**Out of scope (future spec):** the redox calculator (oxidation-state analysis, redox vs non-redox, oxidizing/reducing agent, template text) that will consume `ReactionResult`.

### Decisions locked during brainstorming

- **Mode integration:** Reaction Lab is a **new third mode** reached via a **segmented mode switcher** (Bonding | Reaction Lab). Existing Bonding + Stoichiometry and `CanvasModel` are untouched.
- **Screen layout:** **vertical equation ledger** — reactants stacked (R1 + R2), reaction arrow, then products listed with coefficients + yields, reading like a worked solution. Chosen so up to three products render without horizontal crowding on a portrait iPhone.
- **Zone construction:** each reactant zone accepts **up to 2 dropped tokens**; 1 token = bare element, 2 = compound via `makeReactant`. Tap-× to remove a token, live formula + molar mass under the zone, diatomic auto-note (O → O₂), and a mole/mass quantity control **inside** each zone.
- **Compute timing:** **live** — `solveReaction` runs as reactants form and on every token/quantity change. Reuse the existing reaction **sound + burst** when both quantities are set (or a unit switches).
- **Result states:** reaction-type badge, balanced coefficients in the equation, per-product yields, limiting + excess. A valid **no-reaction** state (`feasible == false`) shows the activity-series message with reactants still visible. A **not-classified** pair (`.unknownReactionClass`) nudges toward supported reaction types.
- **Charge resolution:** main-group elements auto-resolve their common oxidation state; **transition metals reuse the existing `TransitionMetalPickerView`**; polyatomic ions carry their known charge; covalent-forming elements need no charge.
- **Polyatomic composition:** the element-count `composition` map is added to `PolyatomicIon` in ChemCore (intrinsic ion data, also useful to the future redox calc).

## Architecture

Fully additive. Bonding mode, `CanvasModel`, and the existing Stoichiometry flow are unchanged.

```
ChemInteractive/
  State/
    ReactionLabModel.swift      // @Observable: two reactant zones, quantities, derived ReactionResult
    SpeciesMapping.swift        // ZoneState / Element / PolyatomicIon → ChemCore.Species
  Views/
    RootModeView.swift          // segmented switcher: Bonding | Reaction Lab; hosts shared tray
    ReactionLab/
      ReactionLabView.swift     // vertical ledger layout: two zones → result
      ReactantZoneView.swift    // build zone: 1–2 tokens, live formula, in-zone quantity
      ReactionLedgerView.swift  // result: type badge, balanced equation, per-product yields, limiting/excess
      ReactionTypeBadge.swift   // double displacement / single / combustion / synthesis
      NoReactionView.swift      // feasible=false and not-classified states
```

ChemCore (additive):
- `PolyatomicIon` gains a `composition: [String: Int]` field, populated for the 6 existing ions.

### Root wiring

- `ChemInteractiveApp` hosts `RootModeView` instead of `ChemCanvasView`.
- `RootModeView` owns `@State private var mode: AppMode` (`enum AppMode { case bonding, reactionLab }`) and both models as `@State` (`CanvasModel`, `ReactionLabModel`). It renders `ElementTrayView` once at the top (unchanged, 45% height) and swaps the canvas below by `mode`: the existing bonding `ChemCanvasView` body vs. `ReactionLabView`.
- The tray's drag payload `TokenTransfer` is mode-agnostic and unchanged; only the drop targets differ per mode.

### ReactionLabModel

`@Observable final class ReactionLabModel`:

- `elements: [Element]` (loaded from `PeriodicTable`, as `CanvasModel` does) + `polyatomicIons`.
- `zone1: [ZoneState]`, `zone2: [ZoneState]` — 0–2 entries each.
- `quantity1: ReactantEntry?`, `quantity2: ReactantEntry?`.
- `pendingCharge: (zone: Int, index: Int)?` — a placed transition metal awaiting a charge pick; blocks compute.
- Intent methods: `place(_ token:in zone:)`, `removeToken(zone:index:)`, `pickCharge(_:)`, `setQuantity(_:zone:)`, `reset()`.
- Derived (computed): `reactant(_ zone:) -> Reactant?` (nil while empty or pending), and `result: Result<ReactionResult, ReactionError>?` — nil unless both reactants resolve; otherwise `solveReaction(r1, r2, entry1: quantity1, entry2: quantity2, atomicMass:)` where `atomicMass` is a closure over `elements`.

## Species mapping (integration seam)

`SpeciesMapping.swift` — pure, testable, converts a placed `ZoneState` → engine `Species`:

- **atomicMass:** looked up from `elements` (element symbol → `atomicMass`). Not needed on `Species` for polyatomics beyond mass; `Species.atomicMass` for a polyatomic ion = sum of its constituent atomic masses (via its `composition` × element masses).
- **charge:**
  - Main-group element → its common oxidation state (`ZoneState.oxidationStates` first/`derivedCharge` when present). Deterministic.
  - Transition metal → `nil` until resolved through `TransitionMetalPickerView`; the zone is "pending" (`pendingCharge`) and no `Reactant` forms.
  - Polyatomic ion → `PolyatomicIon.charge`.
  - Covalent-forming element (no ionic intent) → `nil`; `makeReactant` uses the covalent path via `valenceElectrons`.
- **isPolyatomic:** from `ZoneState.isPolyatomic`.
- **composition:** element → `[symbol: 1]`; polyatomic ion → `PolyatomicIon.composition` (new field).
- **valenceElectrons / group / period:** straight from `ZoneState`.

Build path: a **pair-aware** `buildReactant(_ zoneStates: [ZoneState], atomicMass:) -> Reactant?` maps the zone's 1–2 `ZoneState`s to `Species` (assigning charges per the rule below), calls `makeReactant`, and returns the `Reactant` (nil while empty or a transition-metal charge is pending). Then `solveReaction(...)`.

**Charge assignment must be pair-aware** — the engine's `makeReactant` treats two species with explicit opposite charges as ionic (to model acids like HCl), so blindly charging every element would misclassify covalent fuels. Rule for a 2-species zone:

- Either species polyatomic → ionic: metal/H → positive, its main-group nonmetal partner → negative, polyatomic → its own charge.
- Metal + nonmetal → ionic: metal → positive oxidation state, nonmetal → negative oxidation state.
- Nonmetal + nonmetal: **acid case** (one is H, the other a group-17 halogen) → ionic, H = +1, halogen = −1. **Otherwise covalent** — both charges `nil`, so `makeReactant` uses the covalent path via `valenceElectrons` (e.g. CH₄, CO₂).
- A single species → bare element; charge `nil` (unused).

This keeps NaCl / NaOH / Na₂SO₄ / HCl ionic and CH₄ / CO₂ covalent, matching the reaction-class test cases below.

### PolyatomicIon.composition (ChemCore)

Add `composition: [String: Int]` to `PolyatomicIon`, populated:
`OH → [O:1, H:1]`, `NO₃ → [N:1, O:3]`, `SO₄ → [S:1, O:4]`, `CO₃ → [C:1, O:3]`, `PO₄ → [P:1, O:4]`, `NH₄ → [N:1, H:4]`. Additive field with the memberwise init updated; existing `ZoneState(polyatomic:)` usage unaffected.

## Interaction flow

**Live pipeline:**
1. User switches to Reaction Lab → two empty zones + placeholder ledger.
2. Drag/tap tokens from the shared tray into a zone (max 2). A transition metal triggers `TransitionMetalPickerView` to resolve charge before the token settles.
3. Each zone with ≥1 resolved species builds a `Reactant`; live formula + molar mass render under the zone.
4. Both zones non-empty and no pending charge → `solveReaction` runs on every change; the ledger renders the classified balanced equation + products (or the no-reaction / not-classified state).
5. Per-zone quantity (mol/mass). When **both** quantities are set (or a unit switches), fire `SoundFX.reaction()` + `ReactionBurst` (reuse `BridgeView`'s `reactionKey`/`fireReaction` pattern); yields, limiting, and excess populate. Blank quantities → stoichiometric basis (ξ = 1); yields shown without a limiting reactant.

**Zone states** (per the approved mockup): empty (drop invite), one token = bare element (with diatomic auto-note for H/N/O/F/Cl/Br/I), two tokens = compound with live formula + molar mass, tap-× per token, in-zone quantity field.

**Result ledger states:**
- **Feasible:** reaction-type badge (double displacement / single displacement / combustion / synthesis), balanced equation with dimmed coefficients, per-product `coeff · formula — moles · mass`, and `limiting: X · Y excess N`.
- **No reaction** (`feasible == false`): "No reaction" badge + the engine's activity-series message; reactants stay visible.
- **Not classified** (`.unknownReactionClass`): neutral badge + a nudge listing supported reaction types.

**Edge behaviors:**
- Pending transition-metal charge → zone shows "choose charge"; ledger stays placeholder; no compute.
- One zone empty → ledger placeholder ("add a second reactant").
- `.unbalanceable` / `.missingAtomicMass` (not expected for supported inputs) → a quiet "can't balance this" fallback, never a crash or raw error.
- Reset clears both zones + quantities.
- Mode switch preserves each model's in-progress state.

## Testing

App target: XCTest (68 existing). Test the pure seams — model + mapping — not SwiftUI rendering.

- **SpeciesMappingTests:** main-group charge auto (Na→+1, O→−2, Al→+3); transition metal → nil until picked; polyatomic → charge + composition from `PolyatomicIon`; molar-mass lookup. Pair-aware `buildReactant`: Na+Cl → ionic NaCl (cation/anion set); H+Cl → ionic HCl (acid); C+H → covalent CH₄ (cation nil); Na+SO₄ → ionic Na₂SO₄.
- **PolyatomicIonCompositionTests (ChemCore):** the 6 ions carry correct `composition`; existing `ZoneState(polyatomic:)` still builds.
- **ReactionLabModelTests:** drive the model like a reducer and assert `result`:
  - NaOH + HCl → NaCl + H₂O (double displacement, feasible)
  - 2HCl + Na₂CO₃ → 2NaCl + CO₂ + H₂O (carbonate, three products)
  - Zn + CuSO₄ → ZnSO₄ + Cu (feasible); Cu + ZnSO₄ → `feasible == false` + activity-series message
  - CH₄ + O₂ → combustion
  - CO₂ + CH₄ → `.unknownReactionClass`
  - pending-transition-metal-charge → no result until picked; both quantities set → limiting/excess + per-product yield numeric checks
- **No regressions:** bonding-mode tests and `CanvasModel` untouched; all 140 ChemCore engine tests stay green after the additive `PolyatomicIon.composition` change.

## Out of scope (future specs)

- Redox calculator: oxidation-state analysis, redox vs non-redox, oxidizing/reducing agent, template text — consumes `ReactionResult`. Note (carried from the engine spec): `Product` currently drops per-ion provenance, so the redox calc will need formula re-parsing or an enriched product term to recover polyatomic oxidation grouping.
- Reaction classes beyond the four supported by the engine.
- Persisting or sharing reactions.
