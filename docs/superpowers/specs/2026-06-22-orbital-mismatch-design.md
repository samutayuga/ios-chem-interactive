# Orbital-Mismatch Covalent Stoichiometry ("Double-Bond Rule")

**Date:** 2026-06-22
**Status:** Approved design — ready for implementation plan

## Problem

When two non-metals from the **same group but different periods** form a covalent
bond, the app currently mispredicts the compound. The octet rule alone treats
Sulfur (S) and Oxygen (O) identically — both have 6 valence electrons — so
`calcStoich` returns a 1:1 ratio with a double bond and the app predicts **SO**.

The real product is **SO₂**. Sulfur (period 3) and Oxygen (period 2) hold their
valence electrons in shells of very different size; their orbitals cannot overlap
efficiently enough to sustain a simple 1:1 double bond. Instead the larger,
less-compact atom becomes central and bonds to **two** of the smaller atoms.

## The rule ("double-bond rule")

Trigger when **all** of these hold:

1. Both atoms are non-metals (already guaranteed: this is the covalent path).
2. Same group (`groupA == groupB`).
3. Different periods (`periodA != periodB`).
4. The octet rule would otherwise yield a **1:1 double bond** — i.e.
   `calcStoich(veA, veB)` returns `nA == 1 && nB == 1 && bondOrder == 2`.

Condition 4 is the key insight: it is the **double-bond condition expressed
generally**, and among non-metals it is *only* satisfiable by valence-6 (Group
16) atoms. This is why the rule needs **no hardcoded "Group 16" check** and why it
correctly leaves other groups untouched:

| Group | Valence | Octet 1:1 result | Rule fires? | Example |
|-------|---------|------------------|-------------|---------|
| 14 (C, Si) | 4 | "quadruple" | No (not a double) | SiC stays 1:1 |
| 15 (N, P) | 5 | triple | No (not a double) | stays triple |
| **16 (O, S, Se, Te)** | **6** | **double** | **Yes** | **SO₂, SeO₂, SeS₂** |
| 17 (F, Cl) | 7 | single | No (not a double) | ClF stays single |

When the rule fires:

- **Larger atom (higher period) = central**, count **1**.
- **Smaller atom (lower period) = peripheral**, count **2**.
- **Bond order = 2** (each X=Y a double bond).

Worked example — S + O → SO₂:
- Central S (period 3), peripheral O ×2 (period 2), each bond double.
- Lone pairs (existing formula, unchanged): central S = `(6 − 2·2)/2 = 1`;
  each peripheral O = `(6 − 2)/2 = 2`. Both chemically correct.

Same-period / same-element pairs (e.g. O + O) fail condition 3, so O₂ remains a
normal 1:1 double bond.

## Architecture

Chemistry stays in `ChemCore`; the app target only consumes it (per the existing
layering). The octet function is left untouched and a new, separately-tested unit
wraps it.

### 1. `ChemCore/Sources/ChemCore/Engine/CovalentStoich.swift`

- **`calcStoich(veA:veB:)`** — unchanged (pure octet rule, existing tests intact).
- **New `isOrbitalMismatchDoubleBond(groupA:periodA:veA:groupB:periodB:veB:) -> Bool`**
  — the trigger predicate above. Single source of truth, reused by both the
  stoichiometry wrapper and the explanation layer.
- **New `covalentStoich(veA:groupA:periodA:veB:groupB:periodB:) -> (nA:Int, nB:Int, bondOrder:Int)`**
  — returns the override `(1,2,2)`/`(2,1,2)` (larger period → count 1) when the
  predicate is true, otherwise returns `calcStoich(veA:veB:)`. Same tuple shape as
  `calcStoich`, so downstream consumers need only swap the call.

### 2. `ChemCore/Sources/ChemCore/State/ZoneState.swift`

- Add stored `public var group: Int` and `public var period: Int`.
- `init(element:)` populates them from `element.group` / `element.period`.
- The designated `init` gains `group: Int = 0, period: Int = 0` (defaults keep
  existing call sites and test fixtures compiling).
- `init(polyatomic:)` leaves them at `0` (polyatomics never reach the covalent
  path — they force ionic).

### 3. App consumers — swap `calcStoich(veA:veB:)` → `covalentStoich(...)`

All three already hold `ZoneState` for both slots, so they pass
`slot.group` / `slot.period`:

- `ChemInteractive/Diagrams/LewisLayout.swift` — `covalentLayout(slotA:slotB:)`
  (drives the Lewis diagram and `covalentPairSummary`). Central selection
  `centralIsA = s.nA <= s.nB` is unchanged and remains correct (the count-1 atom
  is central). Verified slot-order-independent for S-in-A and O-in-A.
- `ChemInteractive/Theme/CompoundName.swift` — `covalentCompoundName(...)`.
  IUPAC ordering already yields "sulfur dioxide".
- `ChemInteractive/Views/Bridge/CovalentLewisView.swift` — `formula(...)` glyph
  builder (also calls `covalentCompoundName`, which now routes correctly).

No changes to Lewis geometry, lone-pair placement, or `peripheralPositions`.

### 4. Educational explanation

`ChemInteractive/Views/Bridge/BondingExplanation.swift` — the covalent branch of
`bondingExplanation(_:_:_:)` (or `covalentPairSummary`) appends one sentence when
`isOrbitalMismatchDoubleBond(...)` is true for the two zones. Template:

> "{larger} and {smaller} are both Group {g} but in different periods, so their
> orbitals differ in size and can't overlap efficiently for a simple 1:1 double
> bond — {larger} (larger, period {p}) instead bonds to two {smaller} atoms."

Larger/smaller chosen by period. Uses the shared predicate (no logic duplication).

## Testing

### ChemCore — `CovalentStoichTests.swift`
- `covalentStoich` S+O and O+S → counts give SO₂ (`(1,2,2)` / `(2,1,2)`), central
  is S in both orders.
- Se+O, Te+O, Se+S → XO₂-style override fires.
- Cl+F → unchanged single bond `(1,1,1)`.
- N+P → unchanged triple `(1,1,3)` (predicate false: not a double).
- O+O (same period) → predicate false → octet `(1,1,2)` (O₂ stays double).
- `isOrbitalMismatchDoubleBond` truth-table cases mirroring the above.

### ChemCore — `GoldenFidelityTests.swift` (checkpoint)
- Confirm the golden fixture does **not** assert the old "SO" behavior for any
  pair. This rule is a deliberate divergence from the Rust `pt-domain` port
  (the original lacked it); if golden covers covalent stoich for an affected
  pair, update the fixture and document the divergence.

### App target
- `CompoundNameTests` — S+O → "Sulfur dioxide".
- `LewisLayoutTests` — `covalentLayout` for S+O: `nPeripheral == 2`,
  `bondOrder == 2`, central is S, `centralLone == 1`, `peripheralLone == 2`.
- `BondingExplanationTests` — covalent explanation for S+O contains the
  orbital-mismatch sentence; for a non-triggering pair (e.g. H+O) it does not.

## Out of scope (YAGNI)

- Groups 14/15/17 special-casing (the predicate already excludes them correctly).
- Higher oxides (SO₃) or expanded resonance depictions — the rule targets the
  XO₂ teaching case only.
- Any change to ionic or metallic paths.
