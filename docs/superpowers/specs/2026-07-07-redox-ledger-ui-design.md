# Redox Ledger UI (ChemInteractive)

**Date:** 2026-07-07
**Status:** Approved design, ready for implementation planning
**Scope:** Small additive Reaction Lab UI change. Surfaces the ChemCore redox analysis in the ledger.

## Summary

Wire the existing `analyzeRedox` output into the Reaction Lab result ledger: below the balanced equation + yields + limiting/excess footer, show a redox section — a Redox/Non-redox badge, the oxidising & reducing agents, and the per-element narrative sentences.

`analyzeRedox` (ChemCore) already produces everything and is fully tested (160-test suite). This spec adds only app-side presentation.

### Decisions locked

- **Content:** badge + agents + full narrative (redox.md's complete ask).
- **Naming:** formulas only in v1 (no `name` closure). App compound-naming keys off cation/anion `ZoneState`s, not product formula strings, so name substitution is deferred.

## Architecture

Additive to `ChemInteractive`. No ChemCore change; `analyzeRedox` is consumed as-is.

- `ChemInteractive/Theme/ReactionLedgerFormat.swift` — **modify**: add two pure helpers.
  - `redoxBadge(_ a: RedoxAnalysis) -> String` → `"Redox"` if `a.isRedox`, else `"Non-redox"`.
  - `redoxAgents(_ a: RedoxAnalysis) -> String?` → `"Oxidising: <oxidisingAgent> · Reducing: <reducingAgent>"` when redox (both non-nil), else `nil`.
- `ChemInteractive/Views/ReactionLab/RedoxSectionView.swift` — **create**: takes a `RedoxAnalysis`; renders the badge (via `ReactionTypeBadge`), the agents row (when present), and `analysis.narrative` lines.
- `ChemInteractive/Views/ReactionLab/ReactionLedgerView.swift` — **modify**: in the `.reaction(let r)` case, append `RedoxSectionView(analysis: analyzeRedox(r))` after the footer. Other outcomes (no-reaction, not-classified, can't-balance) unchanged.

**Data flow:** `LedgerOutcome.reaction(ReactionResult)` → `analyzeRedox(r)` → `RedoxAnalysis` → `RedoxSectionView`. `analyzeRedox` is pure and cheap; called inline in the view.

## Testing

- `ReactionLedgerFormatTests` gains assertions (driven through the real `ReactionLabModel` via the existing `solved(...)` helper):
  - `Zn + CuSO₄ → ZnSO₄ + Cu`: `redoxBadge == "Redox"`, `redoxAgents == "Oxidising: CuSO₄ · Reducing: Zn"`.
  - `NaOH + HCl → NaCl + H₂O`: `redoxBadge == "Non-redox"`, `redoxAgents == nil`.
- `RedoxSectionView` is build-gated (pure SwiftUI, no unit test).
- No regressions: all existing app + ChemCore tests stay green.

## Out of scope

- Real substance names in the narrative (needs a formula→name path).
- Collapsible/expandable redox section, styling beyond the existing ledger idiom.
