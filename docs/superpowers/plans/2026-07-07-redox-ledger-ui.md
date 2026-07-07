# Redox Ledger UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the ChemCore redox analysis in the Reaction Lab ledger — a Redox/Non-redox badge, oxidising/reducing agents, and the per-element narrative — below the existing yields/footer.

**Architecture:** Two pure format helpers on `ReactionLedgerFormat` + one new build-gated SwiftUI view `RedoxSectionView`, wired into `ReactionLedgerView`'s `.reaction` case. `analyzeRedox` (ChemCore) is consumed unchanged.

**Tech Stack:** Swift 5, SwiftUI (iOS 17), XCTest, `xcodebuild`. ChemCore consumed as a package.

## Global Constraints

- **Depends on** the redox analyzer (branch `feat/compound-reactant-engine`): `analyzeRedox(_ result: ReactionResult, name: (String) -> String? = { _ in nil }) -> RedoxAnalysis`; `RedoxAnalysis { let isRedox: Bool; let oxidisingAgent: String?; let reducingAgent: String?; let changes: [ElementRedox]; let oxidationStates: [String: [String: Int]]; let indeterminate: [String]; let narrative: [String] }`.
- **Additive only.** No ChemCore change. Do not modify existing ledger behavior beyond appending the redox section in the `.reaction` case.
- **Naming:** formulas only — call `analyzeRedox(r)` with no `name` closure.
- **Xcode:** file-system-synchronized folders; new files under `ChemInteractive/` auto-join the target (no `.pbxproj` edits).
- **App test command:** `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/<TestClass> 2>&1 | tail -20`. If unavailable, pick one from `xcrun simctl list devices available`. SourceKit "No such module" warnings are IDE noise; `xcodebuild` is authoritative.
- **App build gate:** `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -8` → `BUILD SUCCEEDED`.
- **Commit convention:** end body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

- `ChemInteractive/Theme/ReactionLedgerFormat.swift` — **modify**: add `redoxBadge`, `redoxAgents`.
- `ChemInteractive/Views/ReactionLab/RedoxSectionView.swift` — **create**.
- `ChemInteractive/Views/ReactionLab/ReactionLedgerView.swift` — **modify**: append the section.
- Test: `ChemInteractiveTests/ReactionLedgerFormatTests.swift` — **modify**: add redox assertions.

Two tasks: format helpers (tested) → view + wiring (build-gated).

---

### Task 1: Redox format helpers

**Files:**
- Modify: `ChemInteractive/Theme/ReactionLedgerFormat.swift`
- Test: `ChemInteractiveTests/ReactionLedgerFormatTests.swift`

**Interfaces:**
- Consumes: `RedoxAnalysis`, `analyzeRedox` (ChemCore); the existing `solved(...)` test helper in `ReactionLedgerFormatTests`.
- Produces: `ReactionLedgerFormat.redoxBadge(_ a: RedoxAnalysis) -> String`; `ReactionLedgerFormat.redoxAgents(_ a: RedoxAnalysis) -> String?`.

- [ ] **Step 1: Write the failing test**

Add these two methods to `ChemInteractiveTests/ReactionLedgerFormatTests.swift` (inside the existing `final class ReactionLedgerFormatTests`, reusing its private `solved(...)` helper):

```swift
    func test_redox_badge_and_agents_for_displacement() {
        // Zn + CuSO₄ → ZnSO₄ + Cu (both metals are transition → charge picks 2,2)
        let res = solved([("Zn", false)], [("Cu", false), ("SO₄", true)], picks: [2, 2])!
        guard case .success(let r) = res else { return XCTFail() }
        let a = analyzeRedox(r)
        XCTAssertEqual(ReactionLedgerFormat.redoxBadge(a), "Redox")
        XCTAssertEqual(ReactionLedgerFormat.redoxAgents(a), "Oxidising: CuSO₄ · Reducing: Zn")
    }

    func test_redox_badge_and_agents_for_neutralisation() {
        let res = solved([("Na", false), ("OH", true)], [("H", false), ("Cl", false)])!
        guard case .success(let r) = res else { return XCTFail() }
        let a = analyzeRedox(r)
        XCTAssertEqual(ReactionLedgerFormat.redoxBadge(a), "Non-redox")
        XCTAssertNil(ReactionLedgerFormat.redoxAgents(a))
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/ReactionLedgerFormatTests 2>&1 | tail -20`
Expected: FAIL — `type 'ReactionLedgerFormat' has no member 'redoxBadge'`.

- [ ] **Step 3: Write minimal implementation**

Add these two functions inside the `enum ReactionLedgerFormat` in `ChemInteractive/Theme/ReactionLedgerFormat.swift` (e.g. after `footer`):

```swift
    static func redoxBadge(_ a: RedoxAnalysis) -> String {
        a.isRedox ? "Redox" : "Non-redox"
    }

    static func redoxAgents(_ a: RedoxAnalysis) -> String? {
        guard a.isRedox, let ox = a.oxidisingAgent, let red = a.reducingAgent else { return nil }
        return "Oxidising: \(ox) · Reducing: \(red)"
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ChemInteractiveTests/ReactionLedgerFormatTests 2>&1 | tail -20`
Expected: PASS (existing tests + 2 new).

- [ ] **Step 5: Commit**

```bash
git add ChemInteractive/Theme/ReactionLedgerFormat.swift ChemInteractiveTests/ReactionLedgerFormatTests.swift
git commit -m "feat(app): add redox badge + agents ledger format helpers"
```

---

### Task 2: RedoxSectionView + wire into the ledger

**Files:**
- Create: `ChemInteractive/Views/ReactionLab/RedoxSectionView.swift`
- Modify: `ChemInteractive/Views/ReactionLab/ReactionLedgerView.swift`

**Interfaces:**
- Consumes: `RedoxAnalysis`, `analyzeRedox` (ChemCore); `ReactionLedgerFormat.redoxBadge`/`redoxAgents` (Task 1); existing `ReactionTypeBadge`, `Theme`.
- Produces: `struct RedoxSectionView: View { let analysis: RedoxAnalysis }`.

Pure SwiftUI; gate is the app build.

- [ ] **Step 1: Verify the app builds first (baseline green)**

Run: `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2: Create RedoxSectionView**

```swift
// ChemInteractive/Views/ReactionLab/RedoxSectionView.swift
import SwiftUI
import ChemCore

struct RedoxSectionView: View {
    let analysis: RedoxAnalysis

    var body: some View {
        VStack(spacing: 6) {
            ReactionTypeBadge(text: ReactionLedgerFormat.redoxBadge(analysis))
            if let agents = ReactionLedgerFormat.redoxAgents(analysis) {
                Text(agents).font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(analysis.narrative, id: \.self) { line in
                Text(line)
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 3: Wire into ReactionLedgerView**

In `ChemInteractive/Views/ReactionLab/ReactionLedgerView.swift`, the `.reaction(let r)` case currently ends with the footer line. Add the redox section as the last child of that `VStack`. Replace:

```swift
                Text(ReactionLedgerFormat.footer(r)).font(.caption2).foregroundStyle(.secondary)
            }
```

with:

```swift
                Text(ReactionLedgerFormat.footer(r)).font(.caption2).foregroundStyle(.secondary)
                RedoxSectionView(analysis: analyzeRedox(r))
            }
```

(Leave the `.noReaction`, `.notClassified`, `.cannotBalance` cases unchanged.)

- [ ] **Step 4: Build the app**

Run: `xcodebuild build -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Run the full app test suite (no regressions)**

Run: `xcodebuild test -scheme ChemInteractive -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -12`
Expected: all `ChemInteractiveTests` pass.

- [ ] **Step 6: Commit**

```bash
git add ChemInteractive/Views/ReactionLab/RedoxSectionView.swift ChemInteractive/Views/ReactionLab/ReactionLedgerView.swift
git commit -m "feat(app): show redox analysis in the reaction ledger"
```

---

## Self-Review Notes (addressed)

- **Spec coverage:** badge + agents helpers (Task 1), narrative + agents + badge rendering + wiring (Task 2). Formulas-only (no `name` closure) per spec.
- **Placeholder scan:** none.
- **Type consistency:** `redoxBadge`/`redoxAgents`/`RedoxSectionView`/`analyzeRedox` signatures match the redox analyzer and Task 1↔2.
- **Additive:** only the `.reaction` ledger case changes; ChemCore untouched.
