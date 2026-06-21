# Result: Compound Name

Date: 2026-06-21
Branch: feat/domain-logic-core

## Problem

When a bond completes, the result shows the chemical formula (e.g. `NaCl`,
`CO₂`) and a diagram, but never the compound's *name*. We want the produced
compound's name shown on the result for ionic and covalent bonds.

## Goals

1. Ionic results show the compound name (e.g. "Sodium chloride", "Iron(III)
   oxide", "Sodium hydroxide").
2. Covalent results show the systematic name (e.g. "Carbon dioxide", "Carbon
   monoxide", "Dinitrogen tetroxide").
3. Variable-charge (transition) metals include a Roman-numeral charge.
4. Naming is pure and unit-tested; no model/reducer change.

## Non-Goals

- No metallic naming (alloys/pure metals have no systematic compound name).
- No exhaustive nomenclature (acids, hydrates, organic, common names like
  "water"). Systematic binary naming only.
- No new chemistry in the reducer — naming is a presentation helper.

## Current State (reference)

- `BridgeView` `.complete` (ionic): computes `pair = ionicPair(a, b)` and shows
  `Text(ionicFormula(...))` (size 22) then `BondingDiagramView`. `BridgeView`
  has `@Environment(CanvasModel.self) private var model` → `model.elements:
  [Element]`, `model.polyatomicIons: [PolyatomicIon]`.
- `CovalentLewisView.formula(_:)` shows `Text(text)` (the formula, size 20) +
  a subline. The view has `slotA`/`slotB: ZoneState` but NO model reference.
- `ZoneState` carries `symbol`, `elementClass`, `isPolyatomic`, `isTransition`,
  `oxidationStates`, `derivedCharge` — but NOT the element/ion display name.
- Helpers: `ionicPair(_:_:)`, `calcStoich(veA:veB:) -> (nA, nB, bondOrder)`,
  `iupacFirst(_:_:) -> Bool` (electronegativity order). `Element` has `symbol`,
  `name`. `PolyatomicIon` has `symbol`, `name`.
- Existing string helpers live in `ChemInteractive/Theme/IonFormat.swift`.

## Design

### Component 1 — `CompoundName.swift` (new, pure)

`ChemInteractive/Theme/CompoundName.swift`, alongside `IonFormat.swift`:

- **Anion -ide roots** — `[String: String]` keyed by symbol:
  `F→Fluoride, Cl→Chloride, Br→Bromide, I→Iodide, O→Oxide, S→Sulfide,
  Se→Selenide, Te→Telluride, N→Nitride, P→Phosphide, As→Arsenide,
  C→Carbide, H→Hydride`. Lookup fallback: capitalized element name (from the
  elements list) — acceptable for the rare uncovered case.
- **Greek prefixes** — `prefixes = ["", "di", "tri", "tetra", "penta", "hexa",
  "hepta", "octa", "nona", "deca"]` indexed by count; the value for count 1 is
  `""` (no prefix). A separate rule adds "mono" for the *second* element when
  its count is 1 (covalent only).
- **Roman numerals** — `roman(_ n: Int) -> String` for 1…8 (`I`…`VIII`).
- Helpers:
  - `elementName(_ symbol: String, _ elements: [Element]) -> String` — the
    element's `name`, or the symbol if not found.
  - `func ionicCompoundName(cation: ZoneState, anion: ZoneState, elements:
    [Element], ions: [PolyatomicIon]) -> String`:
    - cation part = `elementName(cation.symbol, elements)`; if the cation is
      variable-charge (`cation.isTransition || cation.oxidationStates.count >
      1`) and `cation.derivedCharge` is set & positive, append
      ` (\(roman(charge)))`.
    - anion part = if `anion.isPolyatomic`, the matching `ions` entry's `name`
      (fallback symbol); else the -ide root for `anion.symbol` (fallback
      element name). Lowercased as the second word.
    - result = `"\(cationName) \(anionWordLowercased)"`, e.g. "Sodium
      chloride", "Iron(III) oxide", "Sodium hydroxide".
  - `func covalentCompoundName(slotA: ZoneState, slotB: ZoneState, elements:
    [Element]) -> String`:
    - homonuclear (`slotA.symbol == slotB.symbol`) → `elementName(slotA.symbol,
      elements)` (e.g. "Nitrogen").
    - else order by `iupacFirst(slotA.symbol, slotB.symbol)`; counts from
      `calcStoich(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)`
      mapped to the first/second by the same order.
    - first word = `prefix(firstCount, allowMono: false) + firstElementName`
      (lowercased prefix + Capitalized element name; first element never takes
      "mono"; if count 1, no prefix).
    - second word = `prefix(secondCount, allowMono: true) + secondRoot`, where
      `secondRoot` is the -ide root for the second symbol, lowercased; "mono"
      applied when count 1 (e.g. "monoxide").
    - result capitalized as a sentence, e.g. "Carbon dioxide", "Carbon
      monoxide", "Dinitrogen tetroxide".

All functions are free, pure, and depend only on their parameters.

### Component 2 — Ionic name line (`BridgeView`)

In `.complete`, under the formula `Text`, add:

```swift
Text(ionicCompoundName(cation: pair.cation, anion: pair.anion,
                       elements: model.elements, ions: model.polyatomicIons))
    .font(.system(size: 14)).foregroundStyle(Theme.text)
    .multilineTextAlignment(.center)
```

### Component 3 — Covalent name line (`CovalentLewisView`)

Add `@Environment(CanvasModel.self) private var model` to `CovalentLewisView`.
In `formula(_:)`, under the formula `Text`, add:

```swift
Text(covalentCompoundName(slotA: slotA, slotB: slotB, elements: model.elements))
    .font(.system(size: 14)).foregroundStyle(Theme.text)
    .multilineTextAlignment(.center)
```

## Data Flow

The views read the already-resolved `ZoneState`s plus `model.elements` /
`model.polyatomicIons` and call the pure naming functions. No model mutation;
the reducer is untouched.

## Error / Edge Handling

- Unknown anion symbol (not in the -ide map): fall back to the element name —
  imperfect but rare for this app's element set.
- Fixed-charge cation: no Roman numeral.
- Variable-charge cation with nil `derivedCharge` (shouldn't reach `.complete`):
  no numeral.
- Homonuclear covalent: element name only (no prefixes).
- Polyatomic cation (NH₄): named via the `ions` list ("Ammonium ...").

## Testing

Unit-test `CompoundName.swift` (build minimal `ZoneState`s + element/ion
arrays from `PeriodicTable.load()` / `PolyatomicIon.polyatomicIons`):
- ionic fixed: Na+Cl → "Sodium chloride"; Mg+O → "Magnesium oxide".
- ionic variable: Fe³⁺ + O²⁻ → "Iron(III) oxide".
- ionic polyatomic: Na + OH → "Sodium hydroxide".
- covalent: C+O with counts → "Carbon dioxide" and "Carbon monoxide"
  (drive via valence electrons / calcStoich); N+O di/tetra → "Dinitrogen
  tetroxide".
- homonuclear: N+N → "Nitrogen".

View lines verified by running the app (name appears under the formula for
ionic + covalent; metallic shows none).

## Files

- New: `ChemInteractive/Theme/CompoundName.swift` (+ test
  `ChemInteractiveTests/CompoundNameTests.swift`).
- Modify: `ChemInteractive/Views/Bridge/BridgeView.swift` (ionic name line).
- Modify: `ChemInteractive/Views/Bridge/CovalentLewisView.swift` (model +
  covalent name line).
- Unchanged: `CanvasModel`, reducer, `MetallicSeaView`.
