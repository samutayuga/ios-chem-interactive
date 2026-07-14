# Compound-Reactant Reaction Engine (ChemCore)

**Date:** 2026-07-06
**Status:** Approved design, ready for implementation planning
**Scope:** ChemCore pure-logic engine only. No app UI. No redox calculator.

## Summary

Today the stoichiometry engine assumes each reactant is a single element and the
reaction is a binary synthesis `A + B → AₓBᵧ`. This sub-project generalizes the
engine so each reactant can be a **compound** built from 1–2 species (element or
polyatomic ion), and the reaction is classified, its products predicted, and the
equation balanced for the general (multi-product) case.

This is the first of a decomposed effort. It delivers a fully unit-tested pure
engine in ChemCore. Two follow-on specs are out of scope here:

1. **App UI** — dropzones that build 1–2 species reactants and render up to three
   product chips.
2. **Redox calculator** — oxidation-state analysis (redox vs non-redox, oxidizing
   / reducing agent, template text) that consumes this engine's output.

The engine is designed so the redox calculator plugs in with no rework: every
balanced term carries a `formula` and an element→count `composition` map, which is
all the redox calculator needs to derive per-element oxidation states.

### Scope decisions (locked during brainstorming)

- **Compound construction:** each of two dropzones builds ONE reactant from **1–2
  species** (element or polyatomic ion), reusing the existing binary bonding rules.
  3+-raw-element formula inference is explicitly out of scope.
- **Product prediction:** atoms rearrange into new products (not mere combination).
- **Reaction classes in scope:** synthesis, double displacement / neutralization
  (incl. acid + carbonate → salt + CO₂ + H₂O), single displacement, combustion.
- **Feasibility:** single displacement uses an activity series; when the free
  element is below the ion in reactivity, the result is a valid "no reaction"
  outcome (not an error).
- **Delivery split:** engine first (this spec), app UI next spec.

## Architecture

New folder, pure logic, no UI or app dependencies:

```
ChemCore/Sources/ChemCore/Reaction/
  Reactant.swift          // a reactant compound built from 1–2 species
  ReactionClass.swift     // enum + classifier
  ProductPrediction.swift // per-class product formulas + compositions (no coeffs)
  Balancer.swift          // general integer balancer (linear-algebra null space)
  Fraction.swift          // exact rational helper for the balancer
  ActivitySeries.swift    // metal + halogen reactivity data + feasibility check
  ReactionSolver.swift    // top-level solveReaction → ReactionResult
```

`Fraction.swift` may live under `Engine/` instead if that reads better with the
existing layout; it is a small pure helper either way.

The existing binary path (`balanceEquation`, `solveStoichiometry`,
`covalentStoich`, `ionicFormula`, crossover model) is **untouched**. The new engine
is additive and reuses those helpers to derive each reactant compound's formula and
atom counts. Synthesis routes through the new classifier but may delegate to the
existing binary logic.

### Core types

```swift
// One placed species: element or polyatomic ion.
struct Species {
  let symbol: String
  let atomicMass: Double
  let charge: Int?              // ionic charge if known
  let elementClass: ElementClass
  let isPolyatomic: Bool
  let composition: [String: Int] // element → atom count (OH → [O:1, H:1])
}

// A reactant = 1 or 2 species combined by existing bonding rules.
struct Reactant {
  let species: [Species]          // count 1 or 2
  let formula: String             // "NaCl", "H₂SO₄", "O₂"
  let composition: [String: Int]  // total atoms per element
  let molarMass: Double
  let cation: Species?            // set when ionic (drives swap)
  let anion: Species?             // nil for bare element / covalent
  let isBareElement: Bool
}

struct Product {
  let formula: String
  let composition: [String: Int]
  let molarMass: Double
}

enum ReactionClass {
  case synthesis, doubleDisplacement, singleDisplacement, combustion, none
}
```

`composition` (element→count map) is the universal currency read by the classifier,
the balancer, and the future redox calculator. That map is the redox seam.

## Components and data flow

`solveReaction(r1, r2, entry1, entry2)` pipeline:

```
classify → predict products → balance → identify limiting → yields / excess
```

### 1. Classification

`classifyReaction(_ r1: Reactant, _ r2: Reactant) -> ReactionClass`, priority order:

1. **Combustion** — one reactant is O₂ (bare O, diatomic) AND the other contains C
   or H (a fuel); an element + O₂ pairing (metal/nonmetal → oxide) also routes here.
2. **Single displacement** — exactly one reactant `isBareElement` (metal or
   halogen), the other is an ionic compound.
3. **Double displacement** — both reactants ionic (both have cation + anion).
4. **Synthesis** — both bare elements.
5. Otherwise **none**.

### 2. Product prediction

`predictProducts(_ cls: ReactionClass, _ r1: Reactant, _ r2: Reactant) -> [Product]`
(or an empty/`.none` outcome with a reason). Products carry **formulas + composition
maps only — no coefficients**. The balancer assigns coefficients. This keeps
prediction and balancing separable and independently testable.

- **Double displacement:** swap anions → `cation₁·anion₂` + `cation₂·anion₁`, each
  neutralized by charge crossover (reuse `ionicFormula` / crossover). Special cases:
  - H⁺ + OH⁻ → H₂O (neutralization).
  - Acid + carbonate → salt + **CO₂ + H₂O** (three products; also covers unstable
    H₂CO₃ → H₂O + CO₂).
- **Single displacement:** free element X vs salt `M·A`. If X outranks M in the
  activity series → products `X·A` + free `M`. Else a "no reaction" outcome with
  reason "X is below M in the activity series".
- **Combustion:** fuel CₐHᵦ(Oᵧ) + O₂ → `a·CO₂ + (b/2)·H₂O`; element + O₂ → its oxide
  (via the element's oxidation state). Product identities fixed; balancer sets
  coefficients.
- **Synthesis:** single product = the existing binary formula / subscripts.

### 3. General balancer

`balance(reactants: [[String: Int]], products: [[String: Int]]) -> [Int]?`

- Build composition matrix **M** (rows = distinct elements, cols = species;
  reactants positive, products negative).
- Solve **M·x = 0** for the smallest positive integer vector: rational null space via
  Gaussian elimination over `Fraction`, then scale by the LCM of denominators and
  divide by the GCD.
- Returns `nil` when unbalanceable (no positive solution / rank defect).
- Guard: reject non-positive or all-zero solutions.

`Fraction` — exact rational (Int numerator/denominator, always reduced) with add,
multiply, and reduce; small, pure, unit-tested.

The existing binary `balanceEquation` stays for the synthesis path (keeps current
tests green); the general balancer is additive.

Worked checks:
- `H₂ + O₂ → H₂O`: H[2,0,−2] O[0,2,−1] → null → [2,1,2]. ✓
- `NaOH + HCl → NaCl + H₂O` → [1,1,1,1]. ✓

### 4. Solver, results, yields

```swift
struct BalancedTerm {
  let coeff: Int
  let formula: String
  let molarMass: Double
  let composition: [String: Int]
}

struct ReactionResult {
  let reactionClass: ReactionClass
  let reactants: [BalancedTerm]   // 2
  let products:  [BalancedTerm]   // 1–3
  let limiting:  LimitingSide     // reuse existing enum
  let yields:    [AmountResult]   // per product (moles + mass)
  let excess:    AmountResult
  let messages:  [String]         // diatomic notes, feasibility, etc.
  let feasible:  Bool             // false → "no reaction"
}
```

Yields generalize the current logic: reaction extent ξ derived from the limiting
reactant, `yield_i = coeff_i · ξ`, excess = leftover of the non-limiting reactant.
Blank quantities → stoichiometric basis (ξ = 1), same rule as today. Per-term molar
mass computed from `composition` × atomic masses.

### Error handling

Typed enum, no crashes. `solveReaction` returns `Result<ReactionResult, ReactionError>`:

- `.unbalanceable` — balancer returned nil.
- `.noProducts` / `.unknownReactionClass`.
- `.missingAtomicMass(symbol)`.

Infeasible single displacement is **not** an error — it is a valid `ReactionResult`
with `feasible = false` and an explanatory message.

### Redox seam (later spec, not built now)

Every `BalancedTerm` carries `formula` + `composition`. The future redox calculator
derives per-element oxidation states from these. No hook is stubbed now; the result
shape simply accommodates it.

Note: the current `Product` type stores only `formula` plus a flat element-count
`composition`, and drops the source `Species` provenance (per-ion charge,
`isPolyatomic`). A future redox/oxidation-state calculator that needs polyatomic
grouping (e.g. S is +6 within SO₄²⁻, not derivable from a merged `{S:1,O:4}`) will
therefore need either formula re-parsing or an enriched product term that retains
constituent ion identity.

## Testing

XCTest, pure, command-line runnable, mirroring the existing ChemCore test style.
New files under `ChemCore/Tests/ChemCoreTests/`:

- **FractionTests** — reduce, add / multiply, LCM/GCD scaling.
- **BalancerTests** — synthesis, neutralization, combustion, carbonate 3-product,
  unbalanceable → nil, degenerate/all-zero guard.
- **ReactionClassTests** — each reactant pair classifies correctly; ambiguous /
  none cases.
- **ProductPredictionTests** — anion swap correctness, neutralization → H₂O,
  carbonate → CO₂ + H₂O, single displacement feasible + infeasible, combustion
  CₐHᵦ fuel.
- **ActivitySeriesTests** — ordering; Zn > Cu proceeds, Cu < Zn infeasible; halogen
  F > Cl > Br > I.
- **ReactionSolverTests** — end-to-end golden cases:
  - `2Na + Cl₂ → 2NaCl` (synthesis)
  - `NaOH + HCl → NaCl + H₂O` (neutralization, non-redox)
  - `Zn + CuSO₄ → ZnSO₄ + Cu` (single displacement, feasible)
  - `Cu + ZnSO₄ → no reaction` (infeasible)
  - `CH₄ + 2O₂ → CO₂ + 2H₂O` (combustion)
  - `2HCl + Na₂CO₃ → 2NaCl + CO₂ + H₂O` (carbonate)
  - mass / mole unit conversions + limiting / excess numeric checks

No existing tests break — the engine is additive; `balanceEquation` and
`solveStoichiometry` are untouched.

## Out of scope (future specs)

- App UI: 1–2 species dropzones, multi-product equation rendering, quantity wiring.
- Redox calculator: oxidation states, redox vs non-redox, oxidizing / reducing
  agent, template text.
- 3+-raw-element formula inference within a dropzone.
- Reaction classes beyond the four listed (e.g. decomposition, precipitation
  solubility rules).
