# Redox Analyzer (ChemCore)

**Date:** 2026-07-07
**Status:** Approved design, ready for implementation planning
**Scope:** ChemCore pure-logic engine only. No app UI.

## Summary

The final piece of the original `redox.md` ask: a calculator that takes a solved reaction, computes the oxidation state of every element before and after, decides whether the reaction is **redox or non-redox**, identifies the **oxidising agent** and **reducing agent**, and produces a template narrative.

It is a pure ChemCore function, `analyzeRedox`, that consumes the existing `ReactionResult` (from `solveReaction`) and returns a `RedoxAnalysis`. `solveReaction` is untouched; the analysis is opt-in.

**Depends on** the compound-reactant engine (branch `feat/compound-reactant-engine`): `ReactionResult`, `BalancedTerm`, and the `PolyatomicIon` table (with `composition`).

**Out of scope (future spec):** wiring the redox output into the Reaction Lab ledger UI (redox/non-redox badge, agents, narrative lines).

### Key design insight — no engine change needed

`BalancedTerm` carries only a flat element-count `composition` (`[String: Int]`) + `formula`, having "lost" the constituent-ion provenance. Earlier reviews flagged that a redox calc might therefore need an enriched product term. It does not: the analyzer **re-factors** a compound's flat composition against ChemCore's known `PolyatomicIon` table. E.g. `CuSO₄ {Cu:1, S:1, O:4}` factors as `1 Cu + 1 SO₄²⁻` → Cu balances −2 → Cu = +2; inside SO₄, O = −2 → S = +6. This recovers exactly the structure needed, so the analyzer is a clean separate function over the existing `ReactionResult`.

(Note: `redox.md`'s KMnO₄/permanganate example illustrates the desired *output format*; permanganate is not in this engine's polyatomic set and no supported reaction produces it. The analyzer is specified against the reactions this engine actually generates: element synthesis, single/double displacement, neutralisation, carbonate, and combustion.)

### Decisions locked during brainstorming

- **Integration:** a separate pure function `analyzeRedox(_ result:) -> RedoxAnalysis`; `solveReaction` and `ReactionResult` are unchanged.
- **Oxidation-state rules:** standard rules only (F=−1, O=−2, H=+1, halogen=−1, group 1=+1, group 2=+2, monatomic/free element by charge/0), plus polyatomic-ion factoring and single-unknown solve-by-difference. **No** peroxide/hydride/OF₂ exceptions (this engine never produces them).
- **Indeterminate handling:** if a compound has ≥2 elements the rules can't pin down, that compound is marked indeterminate, excluded from the verdict, and reported — never guessed, never crashes.
- **Naming:** narrative uses formulas by default; `analyzeRedox` accepts an optional `name: (String) -> String?` closure (mirroring `solveReaction`'s `atomicMass` closure) so the app can substitute real substance names.

## Architecture

New files, pure logic, additive:

```
ChemCore/Sources/ChemCore/Reaction/
  OxidationState.swift   // assign oxidation numbers to a compound's atoms
  RedoxAnalysis.swift     // analyzeRedox + types + narrative
```

Nothing existing is modified.

### Types

```swift
public enum OxidationChange: Equatable, Sendable { case oxidised, reduced, unchanged }

public struct ElementRedox: Equatable, Sendable {
    public let symbol: String
    public let before: Int            // oxidation state in the reactant it appears in
    public let after: Int             // ... in the product
    public let change: OxidationChange
    public let reactantFormula: String
    public let productFormula: String
}

public struct RedoxAnalysis: Equatable, Sendable {
    public let isRedox: Bool
    public let oxidisingAgent: String?               // reactant formula (contains the reduced element)
    public let reducingAgent: String?                // reactant formula (contains the oxidised element)
    public let changes: [ElementRedox]               // redox-active elements only
    public let oxidationStates: [String: [String: Int]] // formula → (element → oxidation state)
    public let indeterminate: [String]               // formulas whose states couldn't be resolved
    public let narrative: [String]                   // template sentences
}

public func analyzeRedox(_ result: ReactionResult,
                         name: (String) -> String? = { _ in nil }) -> RedoxAnalysis
```

`analyzeRedox` runs only on a feasible result with products; an infeasible or empty result returns `isRedox: false` with empty collections and a single explanatory narrative line.

## Oxidation-state assignment

`oxidationState(of composition: [String: Int]) -> [String: Int]?` — returns element→state, or `nil` if indeterminate. Every reactant/product compound is neutral, so Σ(state × count) = 0.

1. **Free element** (composition has exactly one element key) → that element = **0**. (Zn, O₂, Cu, Cl₂.)
2. **Polyatomic-ion factoring:** for each `PolyatomicIon`, find the largest integer `k` such that `composition − k·ionComposition` is non-negative; if the remainder is a single element (the cation) with count `m`:
   - cation total charge = `−ionCharge · k`; cation state = `(−ionCharge · k) / m` (must divide evenly).
   - within the ion: O = −2, H = +1 (fixed); the central atom is solved so its atoms sum to `ionCharge` (SO₄²⁻→S=+6, NO₃⁻→N=+5, CO₃²⁻→C=+4, PO₄³⁻→P=+5, NH₄⁺→N=−3, OH⁻→O=−2/H=+1).
   - Handles NaOH, Na₂SO₄, CuSO₄, ZnSO₄, Na₂CO₃, (NH₄)₂SO₄, etc. Try ions deterministically (e.g. by descending atom count) so factoring is unambiguous for this engine's compounds.
3. **Element rules + single-unknown difference:** assign each atom a fixed state where a rule applies —
   - F = −1, O = −2, H = +1, halogen (Cl/Br/I) = −1, group 1 (Li/Na/K/Rb/Cs) = +1, group 2 (Be/Mg/Ca/Sr/Ba) = +2.
   - Sum the assigned contributions; if **exactly one** element has no rule, solve it by difference so the total is 0. (NaCl, MgO, CaCl₂, CO₂, KMnO₄→Mn=+7, FeCl₃→Fe=+3.)
   - If **≥2** elements are unresolved, return **nil**.

Fixed-rule membership uses small hard-coded symbol sets (group 1, group 2, halogens) — no `PeriodicTable` load; the function stays pure and dependency-free. No peroxide/hydride exceptions.

## Redox verdict, agents, narrative

`analyzeRedox` computes `oxidationState` for every reactant and product term (nil → into `indeterminate`), then:

**Per-element change.** For each element E, gather its state across reactant terms and across product terms. For this engine's reactions E has one state per side.
- `after > before` → **oxidised**; `after < before` → **reduced**; equal → **unchanged**.
- Emit an `ElementRedox` only for changed elements, recording the reactant and product formulas where E appears.
- If E shows conflicting states within a single side, skip E and add the offending formula(s) to `indeterminate`.

**Verdict.** `isRedox = !changes.isEmpty`.

**Agents** (only when `isRedox`):
- **reducing agent** = the reactant formula containing the **oxidised** element.
- **oxidising agent** = the reactant formula containing the **reduced** element.

**Narrative** (with `display(f) = name(f) ?? f`), following the `redox.md` template
`"[Substance] is [oxidised|reduced] because its oxidation state [increases|decreases] from [Initial] in [Reactant] to [Final] in [Product]."`:
- One line per changed element:
  `"<display(reactant)> is <oxidised|reduced> because <E>'s oxidation state <increases|decreases> from <before> in <display(reactant)> to <after> in <display(product)>."`
- An agent summary pair (mirroring the `redox.md` example):
  `"<display(oxidisingAgent)> is the oxidising agent — it oxidises <display(reducingAgent)> and is itself reduced, its oxidation state decreasing from <+X> to <+Y>."` and the reducing-agent counterpart.
- Non-redox → a single line: `"This is a non-redox reaction — no oxidation states change."`

Oxidation-state integers render with an explicit sign in the narrative (`+7`, `−2`, `0`).

### Worked cases

- `2Na + Cl₂ → 2NaCl` — Na 0→+1 (oxidised, reducing agent Na), Cl 0→−1 (reduced, oxidising agent Cl₂) → **redox**.
- `Zn + CuSO₄ → ZnSO₄ + Cu` — Zn 0→+2 (oxidised, reducing agent Zn), Cu +2→0 (reduced, oxidising agent CuSO₄); S,O unchanged → **redox**.
- `CH₄ + 2O₂ → CO₂ + 2H₂O` — C −4→+4 (oxidised, reducing agent CH₄), O 0→−2 (reduced, oxidising agent O₂); H unchanged → **redox**.
- `NaOH + HCl → NaCl + H₂O` — Na +1, O −2, H +1, Cl −1 all unchanged → **non-redox**.
- `2HCl + Na₂CO₃ → 2NaCl + CO₂ + H₂O` — all states unchanged → **non-redox**.

## Testing

XCTest, pure, command-line runnable (`cd ChemCore && swift test`), mirroring the existing ChemCore style. New files under `ChemCore/Tests/ChemCoreTests/`:

- **OxidationStateTests** — free element → 0; NaCl (Na +1, Cl −1); MgO (+2/−2); CO₂ (C +4); H₂O; KMnO₄ (Mn +7); FeCl₃ (Fe +3); polyatomic factoring: NaOH, Na₂SO₄ (S +6), CuSO₄ (Cu +2, S +6), Na₂CO₃ (C +4), NH₄ compounds (N −3); an intentionally under-determined composition → nil.
- **RedoxAnalysisTests** — end-to-end via real `solveReaction` results:
  - `2Na + Cl₂ → 2NaCl`: isRedox, reducing agent Na, oxidising agent Cl₂, changes for Na (0→+1) and Cl (0→−1).
  - `Zn + CuSO₄ → ZnSO₄ + Cu`: isRedox, reducing Zn, oxidising CuSO₄, Zn 0→+2, Cu +2→0, S/O unchanged (absent from `changes`).
  - `CH₄ + 2O₂ → CO₂ + 2H₂O`: isRedox, reducing CH₄, oxidising O₂, C −4→+4, O 0→−2.
  - `NaOH + HCl → NaCl + H₂O`: `isRedox == false`, empty agents, non-redox narrative line.
  - `2HCl + Na₂CO₃ → 2NaCl + CO₂ + H₂O`: non-redox.
  - infeasible result (e.g. `Cu + ZnSO₄`) → `isRedox == false`, empty.
  - `name` closure substitutes a supplied name into the narrative; default uses the formula.
- **No regressions:** the engine is untouched; all existing ChemCore tests stay green (147 baseline) plus the new redox tests.

## Out of scope (future specs)

- Reaction Lab UI for the redox output (badge, agents, narrative section in `ReactionLedgerView`).
- Reaction classes or compounds beyond those this engine produces.
- Oxidation-state exceptions (peroxides, metal hydrides, OF₂) — unreachable from this engine.
