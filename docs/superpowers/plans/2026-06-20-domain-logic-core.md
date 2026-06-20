# ChemInteractive — Domain & Logic Core Implementation Plan (Plan 1 of 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the tested, UI-free chemistry core of the iOS app — a faithful Swift port of the Rust `pt-domain` crate plus the React bonding logic — as a Swift package that builds and passes all tests from the command line.

**Architecture:** A Swift Package `ChemCore` with one library target split into four areas: `PTDomain` (port of Rust `pt-domain`: electron configuration, classification, calc), `Data` (raw element model + loader + derived `Element`), `Engine` (React bonding pedagogy: valence, gcd, bonding rules, covalent stoichiometry, metallic count), and `State` (a pure value-type reducer mirroring `reducer.ts`). All logic is platform-agnostic pure Swift, so `swift test` runs it natively on macOS. Plan 2 builds the SwiftUI iOS app on top of this package.

**Tech Stack:** Swift 6.3, Swift Package Manager, XCTest. Node.js (dev-time only) for the two data-extraction scripts. No third-party runtime dependencies. No WebAssembly in any shipped artifact.

## Global Constraints

- Swift tools version: **6.0** (`// swift-tools-version: 6.0`). Host build/test target: macOS; the iOS deployment floor (iOS 17) is enforced by Plan 2's app target, not here.
- **No WebAssembly, no FFI, no JS bridge** in the package or app. Rust/WASM is the porting *source* only.
- Authoritative source of domain logic: `~/Developer/codews/periodic-table/crates/pt-domain` (files `config.rs`, `classification.rs`, `calc.rs`). Port behavior exactly; translate that crate's `#[cfg(test)]` vectors into XCTest.
- Raw element data source: the 118 YAML files in `~/Developer/codews/periodic-table/data/elements/`. Ship only the minified `elements.raw.json` derived from them.
- Atomic numbers are valid in `1...118`; out-of-range throws `DomainError.invalidAtomicNumber`.
- Known divergence from React (intentional fix): React's `makeZoneState` sets `isTransition: el.block === 'd'`, but the data emits block `"D"` (uppercase), so `isTransition` is always false in React. The Swift port uses a `Block` enum and sets `isTransition = (element.block == .d)`, so D-block elements correctly trigger the transition-metal picker. Document this in the relevant commit.
- All floating-point comparisons in tests use an explicit tolerance (`accuracy:`), never `==`.
- Commit after every task. Commit prefixes: `feat:`, `fix:`, `chore:` (no scopes).

---

### Task 1: Initialize the ChemCore Swift package

**Files:**
- Create: `ChemCore/Package.swift`
- Create: `ChemCore/Sources/ChemCore/ChemCore.swift`
- Test: `ChemCore/Tests/ChemCoreTests/SmokeTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: a buildable package named `ChemCore` with library target `ChemCore` and test target `ChemCoreTests`; a public `chemCoreVersion: String` constant.

- [ ] **Step 1: Create `ChemCore/Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChemCore",
    products: [
        .library(name: "ChemCore", targets: ["ChemCore"]),
    ],
    targets: [
        .target(
            name: "ChemCore",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ChemCoreTests",
            dependencies: ["ChemCore"],
            resources: [
                .process("Fixtures"),
            ]
        ),
    ]
)
```

- [ ] **Step 2: Create placeholder resource dirs so SPM resolves**

Run:
```bash
mkdir -p ChemCore/Sources/ChemCore/Resources ChemCore/Tests/ChemCoreTests/Fixtures
touch ChemCore/Sources/ChemCore/Resources/.gitkeep ChemCore/Tests/ChemCoreTests/Fixtures/.gitkeep
```

- [ ] **Step 3: Create `ChemCore/Sources/ChemCore/ChemCore.swift`**

```swift
/// Marker for the ChemCore package version.
public let chemCoreVersion = "0.1.0"
```

- [ ] **Step 4: Write the smoke test `SmokeTests.swift`**

```swift
import XCTest
@testable import ChemCore

final class SmokeTests: XCTestCase {
    func test_packageLoads() {
        XCTAssertEqual(chemCoreVersion, "0.1.0")
    }
}
```

- [ ] **Step 5: Run the test — expect PASS**

Run: `cd ChemCore && swift test 2>&1 | tail -20`
Expected: build succeeds; `test_packageLoads` passes. (A warning about `.process("Resources")` finding only `.gitkeep` is acceptable.)

- [ ] **Step 6: Commit**

```bash
git add ChemCore
git commit -m "chore: initialize ChemCore swift package"
```

---

### Task 2: PTDomain — Subshell, Orbital, Aufbau fill

**Files:**
- Create: `ChemCore/Sources/ChemCore/PTDomain/Subshell.swift`
- Create: `ChemCore/Sources/ChemCore/PTDomain/Aufbau.swift`
- Create: `ChemCore/Sources/ChemCore/PTDomain/DomainError.swift`
- Test: `ChemCore/Tests/ChemCoreTests/AufbauTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum Subshell: CaseIterable { case s, p, d, f }` with `var azimuthal: Int`, `var capacity: Int`, `var orbitalCount: Int`, `var label: Character`.
  - `struct Orbital: Equatable { let n: Int; let subshell: Subshell; var electrons: Int }`.
  - `enum DomainError: Error, Equatable { case invalidAtomicNumber(Int) }`.
  - `func validate(_ z: Int) throws` (throws `.invalidAtomicNumber` outside `1...118`).
  - `func aufbauFill(_ z: Int) -> [Orbital]` (naive Madelung fill, fill order).

- [ ] **Step 1: Write the failing test `AufbauTests.swift`**

```swift
import XCTest
@testable import ChemCore

final class AufbauTests: XCTestCase {
    func test_subshellProperties() {
        XCTAssertEqual(Subshell.p.azimuthal, 1)
        XCTAssertEqual(Subshell.d.capacity, 10)
        XCTAssertEqual(Subshell.p.orbitalCount, 3)   // 2*1 + 1
        XCTAssertEqual(Subshell.f.label, "f")
    }

    func test_aufbauFill_hydrogenAndIron() {
        XCTAssertEqual(aufbauFill(1), [Orbital(n: 1, subshell: .s, electrons: 1)])
        // Fe (26) naive fill, in fill order: 1s2 2s2 2p6 3s2 3p6 4s2 3d6
        XCTAssertEqual(aufbauFill(26), [
            Orbital(n: 1, subshell: .s, electrons: 2),
            Orbital(n: 2, subshell: .s, electrons: 2),
            Orbital(n: 2, subshell: .p, electrons: 6),
            Orbital(n: 3, subshell: .s, electrons: 2),
            Orbital(n: 3, subshell: .p, electrons: 6),
            Orbital(n: 4, subshell: .s, electrons: 2),
            Orbital(n: 3, subshell: .d, electrons: 6),
        ])
    }

    func test_aufbauFill_total_oganesson() {
        XCTAssertEqual(aufbauFill(118).reduce(0) { $0 + $1.electrons }, 118)
    }

    func test_validate() {
        XCTAssertThrowsError(try validate(0)) { XCTAssertEqual($0 as? DomainError, .invalidAtomicNumber(0)) }
        XCTAssertThrowsError(try validate(119)) { XCTAssertEqual($0 as? DomainError, .invalidAtomicNumber(119)) }
        XCTAssertNoThrow(try validate(1))
        XCTAssertNoThrow(try validate(118))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter AufbauTests 2>&1 | tail -15`
Expected: FAIL — `Subshell`/`Orbital`/`aufbauFill`/`validate` not found.

- [ ] **Step 3: Create `DomainError.swift`**

```swift
public enum DomainError: Error, Equatable {
    case invalidAtomicNumber(Int)
}

func validate(_ z: Int) throws {
    guard (1...118).contains(z) else { throw DomainError.invalidAtomicNumber(z) }
}
```

- [ ] **Step 4: Create `Subshell.swift`**

```swift
public enum Subshell: CaseIterable {
    case s, p, d, f

    public var azimuthal: Int {
        switch self { case .s: 0; case .p: 1; case .d: 2; case .f: 3 }
    }
    public var capacity: Int {
        switch self { case .s: 2; case .p: 6; case .d: 10; case .f: 14 }
    }
    public var orbitalCount: Int { 2 * azimuthal + 1 }
    public var label: Character {
        switch self { case .s: "s"; case .p: "p"; case .d: "d"; case .f: "f" }
    }
}

public struct Orbital: Equatable {
    public let n: Int
    public let subshell: Subshell
    public var electrons: Int

    public init(n: Int, subshell: Subshell, electrons: Int) {
        self.n = n; self.subshell = subshell; self.electrons = electrons
    }
}
```

- [ ] **Step 5: Create `Aufbau.swift`**

```swift
/// Madelung (n + l) fill order, covering atomic numbers 1...118.
let madelungOrder: [(n: Int, subshell: Subshell)] = [
    (1, .s), (2, .s), (2, .p), (3, .s), (3, .p), (4, .s), (3, .d),
    (4, .p), (5, .s), (4, .d), (5, .p), (6, .s), (4, .f), (5, .d),
    (6, .p), (7, .s), (5, .f), (6, .d), (7, .p),
]

/// Naive Aufbau fill (before anomaly corrections), in fill order.
func aufbauFill(_ z: Int) -> [Orbital] {
    var remaining = z
    var orbitals: [Orbital] = []
    for (n, subshell) in madelungOrder {
        if remaining == 0 { break }
        let electrons = min(remaining, subshell.capacity)
        orbitals.append(Orbital(n: n, subshell: subshell, electrons: electrons))
        remaining -= electrons
    }
    return orbitals
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter AufbauTests 2>&1 | tail -15`
Expected: PASS (all 4 tests).

- [ ] **Step 7: Commit**

```bash
git add ChemCore/Sources/ChemCore/PTDomain ChemCore/Tests/ChemCoreTests/AufbauTests.swift
git commit -m "feat: port pt-domain aufbau fill and subshells"
```

---

### Task 3: PTDomain — ElectronConfiguration (anomalies, display, helpers)

**Files:**
- Create: `ChemCore/Sources/ChemCore/PTDomain/ElectronConfiguration.swift`
- Test: `ChemCore/Tests/ChemCoreTests/ElectronConfigurationTests.swift`

**Interfaces:**
- Consumes: `Subshell`, `Orbital`, `aufbauFill`, `validate`.
- Produces:
  - `struct ElectronConfiguration: Equatable { let orbitals: [Orbital] }` with `var description: String` (standard `(n,l)` order, e.g. `"1s2 2s2 2p6 3s2 3p6 3d6 4s2"`), `var unpairedElectrons: Int`, `func electrons(in n: Int, _ subshell: Subshell) -> Int`.
  - `func electronConfiguration(_ z: Int) throws -> ElectronConfiguration` (Aufbau + ground-state anomalies).

- [ ] **Step 1: Write the failing test `ElectronConfigurationTests.swift`** (vectors translated from `config.rs`)

```swift
import XCTest
@testable import ChemCore

final class ElectronConfigurationTests: XCTestCase {
    private func config(_ z: Int) throws -> String { try electronConfiguration(z).description }

    func test_hydrogenAndHelium() throws {
        XCTAssertEqual(try config(1), "1s1")
        XCTAssertEqual(try config(2), "1s2")
    }
    func test_ironStandardOrder() throws {
        XCTAssertEqual(try config(26), "1s2 2s2 2p6 3s2 3p6 3d6 4s2")
    }
    func test_neonFilled() throws {
        XCTAssertEqual(try config(10), "1s2 2s2 2p6")
    }
    func test_chromiumAnomaly() throws {
        XCTAssertEqual(try config(24), "1s2 2s2 2p6 3s2 3p6 3d5 4s1")
    }
    func test_copperAnomaly() throws {
        XCTAssertEqual(try config(29), "1s2 2s2 2p6 3s2 3p6 3d10 4s1")
    }
    func test_palladiumDrops5s() throws {
        XCTAssertEqual(try config(46), "1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10")
    }
    func test_lanthanumAnomaly() throws {
        XCTAssertEqual(try config(57), "1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 5d1 6s2")
    }
    func test_lawrenciumNaiveFill() throws {
        XCTAssertEqual(try config(103),
            "1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 4f14 5s2 5p6 5d10 5f14 6s2 6p6 6d1 7s2")
    }
    func test_oganessonFillsTo118() throws {
        let c = try electronConfiguration(118)
        XCTAssertEqual(c.orbitals.reduce(0) { $0 + $1.electrons }, 118)
        XCTAssertEqual(c.electrons(in: 7, .p), 6)
    }
    func test_unpairedElectrons_hundsRule() throws {
        XCTAssertEqual(try electronConfiguration(7).unpairedElectrons, 3)  // N: 2p3
        XCTAssertEqual(try electronConfiguration(10).unpairedElectrons, 0) // Ne
        XCTAssertEqual(try electronConfiguration(8).unpairedElectrons, 2)  // O
        XCTAssertEqual(try electronConfiguration(26).unpairedElectrons, 4) // Fe: 3d6
    }
    func test_invalidZ() {
        XCTAssertThrowsError(try electronConfiguration(0))
        XCTAssertThrowsError(try electronConfiguration(119))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter ElectronConfigurationTests 2>&1 | tail -15`
Expected: FAIL — `electronConfiguration`/`ElectronConfiguration` not found.

- [ ] **Step 3: Create `ElectronConfiguration.swift`**

```swift
public struct ElectronConfiguration: Equatable {
    public let orbitals: [Orbital]

    /// Renders in standard (n, l) order, e.g. "1s2 2s2 2p6 3s2 3p6 3d6 4s2".
    public var description: String {
        orbitals
            .sorted { ($0.n, $0.subshell.azimuthal) < ($1.n, $1.subshell.azimuthal) }
            .map { "\($0.n)\($0.subshell.label)\($0.electrons)" }
            .joined(separator: " ")
    }

    /// Total number of unpaired electrons (Hund's rule).
    public var unpairedElectrons: Int {
        orbitals.reduce(0) { acc, o in
            let half = o.subshell.orbitalCount
            let unpaired = o.electrons <= half ? o.electrons : 2 * half - o.electrons
            return acc + unpaired
        }
    }

    /// Electrons in a specific (n, subshell), or 0 if absent.
    public func electrons(in n: Int, _ subshell: Subshell) -> Int {
        orbitals.first { $0.n == n && $0.subshell == subshell }?.electrons ?? 0
    }
}

/// Known ground-state anomalies: absolute occupancies for the orbitals that
/// deviate from naive Aufbau. Orbitals set to 0 are dropped after applying.
private let anomalies: [Int: [(n: Int, subshell: Subshell, electrons: Int)]] = [
    24: [(3, .d, 5), (4, .s, 1)],   // Cr
    29: [(3, .d, 10), (4, .s, 1)],  // Cu
    41: [(4, .d, 4), (5, .s, 1)],   // Nb
    42: [(4, .d, 5), (5, .s, 1)],   // Mo
    44: [(4, .d, 7), (5, .s, 1)],   // Ru
    45: [(4, .d, 8), (5, .s, 1)],   // Rh
    46: [(4, .d, 10), (5, .s, 0)],  // Pd
    47: [(4, .d, 10), (5, .s, 1)],  // Ag
    57: [(4, .f, 0), (5, .d, 1)],   // La
    58: [(4, .f, 1), (5, .d, 1)],   // Ce
    64: [(4, .f, 7), (5, .d, 1)],   // Gd
    78: [(5, .d, 9), (6, .s, 1)],   // Pt
    79: [(5, .d, 10), (6, .s, 1)],  // Au
    89: [(5, .f, 0), (6, .d, 1)],   // Ac
    90: [(5, .f, 0), (6, .d, 2)],   // Th
    91: [(5, .f, 2), (6, .d, 1)],   // Pa
    92: [(5, .f, 3), (6, .d, 1)],   // U
    93: [(5, .f, 4), (6, .d, 1)],   // Np
    96: [(5, .f, 7), (6, .d, 1)],   // Cm
]

/// Ground-state electron configuration for atomic number `z`.
public func electronConfiguration(_ z: Int) throws -> ElectronConfiguration {
    try validate(z)
    var orbitals = aufbauFill(z)
    if let overrides = anomalies[z] {
        for o in overrides {
            if let idx = orbitals.firstIndex(where: { $0.n == o.n && $0.subshell == o.subshell }) {
                orbitals[idx].electrons = o.electrons
            } else {
                orbitals.append(Orbital(n: o.n, subshell: o.subshell, electrons: o.electrons))
            }
        }
        orbitals.removeAll { $0.electrons == 0 }
    }
    return ElectronConfiguration(orbitals: orbitals)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter ElectronConfigurationTests 2>&1 | tail -15`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/PTDomain/ElectronConfiguration.swift ChemCore/Tests/ChemCoreTests/ElectronConfigurationTests.swift
git commit -m "feat: port pt-domain electron configuration with anomalies"
```

---

### Task 4: PTDomain — Classification block / period / group

**Files:**
- Create: `ChemCore/Sources/ChemCore/PTDomain/Classification.swift`
- Test: `ChemCore/Tests/ChemCoreTests/ClassificationPlacementTests.swift`

**Interfaces:**
- Consumes: `Subshell`, `aufbauFill`, `electronConfiguration`, `validate`.
- Produces:
  - `enum Block: String, Equatable { case s = "S", p = "P", d = "D", f = "F" }` with `init(_ subshell: Subshell)`.
  - `func naiveBlock(_ z: Int) throws -> Subshell` (subshell of the last naive-fill orbital).
  - `func block(_ z: Int) throws -> Block`.
  - `func period(_ z: Int) throws -> Int`.
  - `func group(_ z: Int) throws -> Int`.

- [ ] **Step 1: Write the failing test `ClassificationPlacementTests.swift`** (vectors from `classification.rs`)

```swift
import XCTest
@testable import ChemCore

final class ClassificationPlacementTests: XCTestCase {
    func test_blocks() throws {
        XCTAssertEqual(try block(2), .s)   // He: naive last orbital is 1s
        XCTAssertEqual(try block(11), .s)  // Na
        XCTAssertEqual(try block(26), .d)  // Fe
        XCTAssertEqual(try block(9), .p)   // F
        XCTAssertEqual(try block(60), .f)  // Nd
    }
    func test_periods() throws {
        XCTAssertEqual(try period(1), 1)
        XCTAssertEqual(try period(11), 3)
        XCTAssertEqual(try period(26), 4)
        XCTAssertEqual(try period(46), 5)  // Pd keeps 5s in naive fill
        XCTAssertEqual(try period(60), 6)
    }
    func test_groups_mainBlock() throws {
        XCTAssertEqual(try group(1), 1)    // H
        XCTAssertEqual(try group(2), 18)   // He
        XCTAssertEqual(try group(3), 1)    // Li
        XCTAssertEqual(try group(4), 2)    // Be
        XCTAssertEqual(try group(8), 16)   // O
        XCTAssertEqual(try group(9), 17)   // F
        XCTAssertEqual(try group(10), 18)  // Ne
        XCTAssertEqual(try group(5), 13)   // B
    }
    func test_groups_transitionBlock() throws {
        XCTAssertEqual(try group(21), 3)   // Sc
        XCTAssertEqual(try group(26), 8)   // Fe
        XCTAssertEqual(try group(30), 12)  // Zn
        XCTAssertEqual(try group(24), 6)   // Cr (anomaly)
        XCTAssertEqual(try group(29), 11)  // Cu (anomaly)
        XCTAssertEqual(try group(46), 10)  // Pd (anomaly, 5s dropped)
    }
    func test_groups_fBlockConvention() throws {
        XCTAssertEqual(try group(60), 3)   // Nd
        XCTAssertEqual(try group(92), 3)   // U
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter ClassificationPlacementTests 2>&1 | tail -15`
Expected: FAIL — `block`/`period`/`group`/`Block` not found.

- [ ] **Step 3: Create `Classification.swift` (placement portion)**

```swift
public enum Block: String, Equatable {
    case s = "S", p = "P", d = "D", f = "F"

    public init(_ subshell: Subshell) {
        switch subshell {
        case .s: self = .s; case .p: self = .p; case .d: self = .d; case .f: self = .f
        }
    }
}

/// Subshell of the differentiating electron (naive Aufbau).
func naiveBlock(_ z: Int) throws -> Subshell {
    try validate(z)
    return aufbauFill(z).last!.subshell
}

/// The block of the periodic table.
public func block(_ z: Int) throws -> Block {
    Block(try naiveBlock(z))
}

/// The period (row), from the highest principal quantum number in the naive fill.
public func period(_ z: Int) throws -> Int {
    try validate(z)
    return aufbauFill(z).map(\.n).max()!
}

/// The group (column) 1...18. f-block elements are assigned group 3 by convention.
public func group(_ z: Int) throws -> Int {
    try validate(z)
    if z == 1 { return 1 }   // Hydrogen
    if z == 2 { return 18 }  // Helium
    let config = try electronConfiguration(z)
    let p = try period(z)
    switch try naiveBlock(z) {
    case .s: return config.electrons(in: p, .s)
    case .p: return 12 + config.electrons(in: p, .p)
    case .d: return config.electrons(in: p - 1, .d) + config.electrons(in: p, .s)
    case .f: return 3
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter ClassificationPlacementTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/PTDomain/Classification.swift ChemCore/Tests/ChemCoreTests/ClassificationPlacementTests.swift
git commit -m "feat: port pt-domain block, period and group placement"
```

---

### Task 5: PTDomain — category, element class, oxidation states

**Files:**
- Modify: `ChemCore/Sources/ChemCore/PTDomain/Classification.swift` (append)
- Test: `ChemCore/Tests/ChemCoreTests/ClassificationChemistryTests.swift`

**Interfaces:**
- Consumes: `block`, `naiveBlock`, `group`, `period`, `validate`.
- Produces:
  - `enum Category: String { case alkaliMetal = "AlkaliMetal", alkalineEarthMetal = "AlkalineEarthMetal", transitionMetal = "TransitionMetal", postTransitionMetal = "PostTransitionMetal", metalloid = "Metalloid", reactiveNonmetal = "ReactiveNonmetal", nobleGas = "NobleGas", halogen = "Halogen", lanthanide = "Lanthanide", actinide = "Actinide" }`.
  - `enum ElementClass: String { case metal = "Metal", nonMetal = "NonMetal", metalloid = "Metalloid" }`.
  - `func category(_ z: Int) throws -> Category`.
  - `func elementClass(_ z: Int) throws -> ElementClass`.
  - `func oxidationStates(_ z: Int) throws -> [Int]`.

- [ ] **Step 1: Write the failing test `ClassificationChemistryTests.swift`** (vectors from `classification.rs`)

```swift
import XCTest
@testable import ChemCore

final class ClassificationChemistryTests: XCTestCase {
    func test_categories() throws {
        XCTAssertEqual(try category(1), .reactiveNonmetal)     // H
        XCTAssertEqual(try category(2), .nobleGas)             // He
        XCTAssertEqual(try category(11), .alkaliMetal)         // Na
        XCTAssertEqual(try category(12), .alkalineEarthMetal)  // Mg
        XCTAssertEqual(try category(26), .transitionMetal)     // Fe
        XCTAssertEqual(try category(5), .metalloid)            // B
        XCTAssertEqual(try category(17), .halogen)             // Cl
        XCTAssertEqual(try category(13), .postTransitionMetal) // Al
        XCTAssertEqual(try category(8), .reactiveNonmetal)     // O
        XCTAssertEqual(try category(60), .lanthanide)          // Nd
        XCTAssertEqual(try category(92), .actinide)            // U
    }
    func test_elementClass() throws {
        XCTAssertEqual(try elementClass(1), .nonMetal)   // H exception
        XCTAssertEqual(try elementClass(17), .nonMetal)  // Cl (group 17)
        XCTAssertEqual(try elementClass(2), .nonMetal)   // He
        XCTAssertEqual(try elementClass(57), .metal)     // La
        XCTAssertEqual(try elementClass(92), .metal)     // U
        for z in [5, 14, 32, 33, 51, 52, 84] {
            XCTAssertEqual(try elementClass(z), .metalloid, "z=\(z)")
        }
        XCTAssertEqual(try elementClass(85), .nonMetal)  // At (group 17, not metalloid)
        XCTAssertEqual(try elementClass(6), .nonMetal)   // C
        XCTAssertEqual(try elementClass(16), .nonMetal)  // S
        XCTAssertEqual(try elementClass(34), .nonMetal)  // Se
        XCTAssertEqual(try elementClass(11), .metal)     // Na
        XCTAssertEqual(try elementClass(79), .metal)     // Au
    }
    func test_oxidationStates() throws {
        XCTAssertEqual(try oxidationStates(11), [1])        // Na
        XCTAssertEqual(try oxidationStates(12), [2])        // Mg
        XCTAssertEqual(try oxidationStates(8), [-2])        // O
        XCTAssertEqual(try oxidationStates(9), [-1])        // F
        XCTAssertEqual(try oxidationStates(10), [0])        // Ne (group 18 catch-all)
        XCTAssertEqual(try oxidationStates(5), [3])         // B
        XCTAssertEqual(try oxidationStates(6), [-4, 4])     // C
        XCTAssertEqual(try oxidationStates(7), [-3, 3, 5])  // N
        XCTAssertEqual(try oxidationStates(26), [2, 3])     // Fe
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter ClassificationChemistryTests 2>&1 | tail -15`
Expected: FAIL — `category`/`elementClass`/`oxidationStates` not found.

- [ ] **Step 3: Append to `Classification.swift`**

```swift
public enum Category: String, Equatable {
    case alkaliMetal = "AlkaliMetal"
    case alkalineEarthMetal = "AlkalineEarthMetal"
    case transitionMetal = "TransitionMetal"
    case postTransitionMetal = "PostTransitionMetal"
    case metalloid = "Metalloid"
    case reactiveNonmetal = "ReactiveNonmetal"
    case nobleGas = "NobleGas"
    case halogen = "Halogen"
    case lanthanide = "Lanthanide"
    case actinide = "Actinide"
}

public enum ElementClass: String, Equatable {
    case metal = "Metal"
    case nonMetal = "NonMetal"
    case metalloid = "Metalloid"
}

// The 7 metalloids per spec: B Si Ge As Sb Te Po (used by element_class).
private let classMetalloids: Set<Int> = [5, 14, 32, 33, 51, 52, 84]
// Category metalloids: B Si Ge As Sb Te At (note At(85), not Po).
private let categoryMetalloids: Set<Int> = [5, 14, 32, 33, 51, 52, 85]
private let postTransition: Set<Int> = [13, 31, 49, 50, 81, 82, 83, 84, 113, 114, 115, 116]

/// Broad Metal / NonMetal / Metalloid classification derived from atomic number.
public func elementClass(_ z: Int) throws -> ElementClass {
    let g = try group(z)
    if z == 1 { return .nonMetal }
    if g == 17 || g == 18 { return .nonMetal }
    if (57...71).contains(z) || (89...103).contains(z) { return .metal }
    if classMetalloids.contains(z) { return .metalloid }
    let p = try period(z)
    if p == 2 && (14...16).contains(g) { return .nonMetal }
    if p == 3 && (15...16).contains(g) { return .nonMetal }
    if p == 4 && g == 16 { return .nonMetal }
    return .metal
}

/// Best-effort element category derived from group, block, and atomic number.
public func category(_ z: Int) throws -> Category {
    try validate(z)
    let g = try group(z)
    let b = try block(z)
    if (57...71).contains(z) { return .lanthanide }
    if (89...103).contains(z) { return .actinide }
    if g == 18 { return .nobleGas }
    if g == 1 && z != 1 { return .alkaliMetal }
    if g == 2 { return .alkalineEarthMetal }
    if g == 17 { return .halogen }
    if b == .d { return .transitionMetal }
    if categoryMetalloids.contains(z) { return .metalloid }
    if postTransition.contains(z) { return .postTransitionMetal }
    return .reactiveNonmetal
}

/// Best-effort common oxidation states derived from the group.
public func oxidationStates(_ z: Int) throws -> [Int] {
    try validate(z)
    switch try group(z) {
    case 1: return [1]
    case 2: return [2]
    case 3...12: return [2, 3]
    case 13: return [3]
    case 14: return [-4, 4]
    case 15: return [-3, 3, 5]
    case 16: return [-2]
    case 17: return [-1]
    default: return [0]
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter ClassificationChemistryTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/PTDomain/Classification.swift ChemCore/Tests/ChemCoreTests/ClassificationChemistryTests.swift
git commit -m "feat: port pt-domain category, element class and oxidation states"
```

---

### Task 6: PTDomain — Calc (atomic mass, state)

**Files:**
- Create: `ChemCore/Sources/ChemCore/PTDomain/Calc.swift`
- Test: `ChemCore/Tests/ChemCoreTests/CalcTests.swift`

**Interfaces:**
- Consumes: nothing (operates on plain values).
- Produces:
  - `enum StateOfMatter: String { case solid = "Solid", liquid = "Liquid", gas = "Gas" }`.
  - `struct Isotope: Equatable { let massNumber: Int; let relativeMass: Double; let abundance: Double }`.
  - `func atomicMassFromIsotopes(_ isotopes: [Isotope]) -> Double?`.
  - `func isotopeMassMatches(storedMass: Double, isotopes: [Isotope], tolerance: Double) -> Bool`.
  - `func stateAt(meltingPoint: Double?, boilingPoint: Double?, temperatureK: Double) -> StateOfMatter?`.

Note: `Isotope` and `StateOfMatter` here are the canonical domain types; the `Data` layer (Task 7) decodes JSON into these same types.

- [ ] **Step 1: Write the failing test `CalcTests.swift`** (vectors from `calc.rs`)

```swift
import XCTest
@testable import ChemCore

final class CalcTests: XCTestCase {
    private let chlorine = [
        Isotope(massNumber: 35, relativeMass: 34.968853, abundance: 0.7576),
        Isotope(massNumber: 37, relativeMass: 36.965903, abundance: 0.2424),
    ]

    func test_weightedMassOfChlorine() {
        let mass = atomicMassFromIsotopes(chlorine)
        XCTAssertNotNil(mass)
        XCTAssertEqual(mass!, 35.45, accuracy: 0.01)
    }
    func test_noIsotopesYieldsNil() {
        XCTAssertNil(atomicMassFromIsotopes([]))
    }
    func test_zeroAbundanceYieldsNil() {
        XCTAssertNil(atomicMassFromIsotopes([Isotope(massNumber: 1, relativeMass: 1.0, abundance: 0.0)]))
    }
    func test_isotopeMatch() {
        XCTAssertTrue(isotopeMassMatches(storedMass: 35.45, isotopes: chlorine, tolerance: 0.01))
        XCTAssertFalse(isotopeMassMatches(storedMass: 35.45, isotopes: [], tolerance: 0.01))
    }
    func test_stateTransitions() {
        // Iron: mp 1811 K, bp 3134 K.
        XCTAssertEqual(stateAt(meltingPoint: 1811, boilingPoint: 3134, temperatureK: 300), .solid)
        XCTAssertEqual(stateAt(meltingPoint: 1811, boilingPoint: 3134, temperatureK: 2000), .liquid)
        XCTAssertEqual(stateAt(meltingPoint: 1811, boilingPoint: 3134, temperatureK: 4000), .gas)
        XCTAssertNil(stateAt(meltingPoint: nil, boilingPoint: nil, temperatureK: 300))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter CalcTests 2>&1 | tail -15`
Expected: FAIL — `Isotope`/`atomicMassFromIsotopes`/`stateAt` not found.

- [ ] **Step 3: Create `Calc.swift`**

```swift
public enum StateOfMatter: String, Equatable {
    case solid = "Solid", liquid = "Liquid", gas = "Gas"
}

public struct Isotope: Equatable {
    public let massNumber: Int
    public let relativeMass: Double
    public let abundance: Double
    public init(massNumber: Int, relativeMass: Double, abundance: Double) {
        self.massNumber = massNumber; self.relativeMass = relativeMass; self.abundance = abundance
    }
}

/// Abundance-weighted mean of isotope relative masses, or nil if empty / zero abundance.
public func atomicMassFromIsotopes(_ isotopes: [Isotope]) -> Double? {
    if isotopes.isEmpty { return nil }
    let total = isotopes.reduce(0.0) { $0 + $1.abundance }
    if total == 0.0 { return nil }
    let weighted = isotopes.reduce(0.0) { $0 + $1.relativeMass * $1.abundance }
    return weighted / total
}

public func isotopeMassMatches(storedMass: Double, isotopes: [Isotope], tolerance: Double) -> Bool {
    guard let mass = atomicMassFromIsotopes(isotopes) else { return false }
    return abs(mass - storedMass) <= tolerance
}

/// Physical state at `temperatureK`, or nil when either point is unknown.
public func stateAt(meltingPoint: Double?, boilingPoint: Double?, temperatureK: Double) -> StateOfMatter? {
    guard let mp = meltingPoint, let bp = boilingPoint else { return nil }
    if temperatureK < mp { return .solid }
    if temperatureK < bp { return .liquid }
    return .gas
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter CalcTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/PTDomain/Calc.swift ChemCore/Tests/ChemCoreTests/CalcTests.swift
git commit -m "feat: port pt-domain atomic mass and state calculations"
```

---

### Task 7: Data — RawElement decoding

**Files:**
- Create: `ChemCore/Sources/ChemCore/Data/RawElement.swift`
- Test: `ChemCore/Tests/ChemCoreTests/RawElementTests.swift`

**Interfaces:**
- Consumes: `Isotope`, `StateOfMatter`.
- Produces:
  - `struct RawElement: Decodable, Equatable` with stored fields: `atomicNumber: Int`, `name: String`, `symbol: String`, `atomicMass: Double`, `massNumber: Int`, `meltingPoint: Double?`, `boilingPoint: Double?`, `density: Double?`, `electronegativity: Double?`, `state: StateOfMatter`, `discoveryYear: Int?`, `discoverer: String?`, `isotopes: [Isotope]`.
  - `extension Isotope: Decodable` (snake_case via decoder strategy).
  - `static func RawElement.decodeAll(from data: Data) throws -> [RawElement]` using a JSONDecoder with `.convertFromSnakeCase`.

- [ ] **Step 1: Write the failing test `RawElementTests.swift`**

```swift
import XCTest
@testable import ChemCore

final class RawElementTests: XCTestCase {
    let json = """
    [{
      "atomic_number": 26, "name": "Iron", "symbol": "Fe",
      "atomic_mass": 55.845, "mass_number": 56,
      "melting_point": 1811.0, "boiling_point": 3134.0,
      "density": 7.874, "electronegativity": 1.83, "state": "Solid",
      "isotopes": [
        { "mass_number": 56, "relative_mass": 55.934936, "abundance": 0.91754 }
      ]
    }]
    """.data(using: .utf8)!

    func test_decodesRawElement() throws {
        let all = try RawElement.decodeAll(from: json)
        XCTAssertEqual(all.count, 1)
        let fe = all[0]
        XCTAssertEqual(fe.atomicNumber, 26)
        XCTAssertEqual(fe.symbol, "Fe")
        XCTAssertEqual(fe.atomicMass, 55.845, accuracy: 1e-6)
        XCTAssertEqual(fe.state, .solid)
        XCTAssertNil(fe.discoverer)
        XCTAssertEqual(fe.isotopes.first?.massNumber, 56)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter RawElementTests 2>&1 | tail -15`
Expected: FAIL — `RawElement` not found.

- [ ] **Step 3: Create `RawElement.swift`**

```swift
import Foundation

extension Isotope: Decodable {
    enum CodingKeys: String, CodingKey { case massNumber, relativeMass, abundance }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            massNumber: try c.decode(Int.self, forKey: .massNumber),
            relativeMass: try c.decode(Double.self, forKey: .relativeMass),
            abundance: try c.decode(Double.self, forKey: .abundance)
        )
    }
}

extension StateOfMatter: Decodable {}

public struct RawElement: Decodable, Equatable {
    public let atomicNumber: Int
    public let name: String
    public let symbol: String
    public let atomicMass: Double
    public let massNumber: Int
    public let meltingPoint: Double?
    public let boilingPoint: Double?
    public let density: Double?
    public let electronegativity: Double?
    public let state: StateOfMatter
    public let discoveryYear: Int?
    public let discoverer: String?
    public let isotopes: [Isotope]

    public static func decodeAll(from data: Data) throws -> [RawElement] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([RawElement].self, from: data)
    }
}
```

Note: `StateOfMatter`'s raw values are capitalized (`"Solid"`), matching the JSON, so the default `Decodable` synthesis from its `String` raw value works without a key strategy.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter RawElementTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Data/RawElement.swift ChemCore/Tests/ChemCoreTests/RawElementTests.swift
git commit -m "feat: add RawElement JSON decoding"
```

---

### Task 8: Data pipeline — generate elements.raw.json and golden fixture

**Files:**
- Create: `tools/package.json`
- Create: `tools/yaml-to-raw-json.mjs`
- Create: `tools/dump-elements.mjs`
- Create (generated): `ChemCore/Sources/ChemCore/Resources/elements.raw.json`
- Create (generated): `ChemCore/Tests/ChemCoreTests/Fixtures/elements.golden.json`
- Test: `ChemCore/Tests/ChemCoreTests/DataPresenceTests.swift`

**Interfaces:**
- Consumes: the YAML files at `~/Developer/codews/periodic-table/data/elements/*.yaml` and the WASM at `~/Developer/codews/chem-interactive/src/wasm/pkg/pt_wasm.js`.
- Produces: two committed JSON files; a test asserting the shipped raw file has 118 elements.

Hardcode the absolute source paths (this is a one-machine dev tool); both scripts are committed for reproducibility.

- [ ] **Step 1: Create `tools/package.json`**

```json
{
  "name": "chem-data-tools",
  "private": true,
  "type": "module",
  "version": "0.1.0",
  "dependencies": { "js-yaml": "^4.1.0" }
}
```

- [ ] **Step 2: Install the dev dependency**

Run: `cd tools && npm install 2>&1 | tail -5`
Expected: `js-yaml` installed under `tools/node_modules` (not shipped).

- [ ] **Step 3: Create `tools/yaml-to-raw-json.mjs`**

```javascript
// Converts the 118 canonical YAML files into a single minified elements.raw.json
// containing only the stored fields pt-domain::Element holds.
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import yaml from 'js-yaml';

const SRC = '/Users/samutup/Developer/codews/periodic-table/data/elements';
const OUT = new URL('../ChemCore/Sources/ChemCore/Resources/elements.raw.json', import.meta.url);

const STATE = { solid: 'Solid', liquid: 'Liquid', gas: 'Gas' };
const KEYS = ['atomic_number','name','symbol','atomic_mass','mass_number','melting_point',
  'boiling_point','density','electronegativity','state','discovery_year','discoverer','isotopes'];

const elements = readdirSync(SRC)
  .filter(f => f.endsWith('.yaml'))
  .map(f => yaml.load(readFileSync(join(SRC, f), 'utf8')))
  .map(e => {
    const out = {};
    for (const k of KEYS) {
      if (e[k] === undefined || e[k] === null) continue;
      out[k] = k === 'state' ? (STATE[e[k]] ?? e[k]) : e[k];
    }
    return out;
  })
  .sort((a, b) => a.atomic_number - b.atomic_number);

if (elements.length !== 118) throw new Error(`expected 118 elements, got ${elements.length}`);
writeFileSync(OUT, JSON.stringify(elements));
console.log(`wrote ${elements.length} elements to elements.raw.json`);
```

- [ ] **Step 4: Create `tools/dump-elements.mjs`** (golden fixture, full computed output)

```javascript
// Dumps the existing WASM's full computed output to the golden test fixture.
// This file is a dev-time fidelity check only and never ships in the app.
import { writeFileSync } from 'node:fs';
import { PeriodicTable } from '/Users/samutup/Developer/codews/chem-interactive/src/wasm/pkg/pt_wasm.js';

const OUT = new URL('../ChemCore/Tests/ChemCoreTests/Fixtures/elements.golden.json', import.meta.url);
const all = PeriodicTable.load().all().sort((a, b) => a.atomic_number - b.atomic_number);
if (all.length !== 118) throw new Error(`expected 118 elements, got ${all.length}`);
writeFileSync(OUT, JSON.stringify(all));
console.log(`wrote ${all.length} elements to elements.golden.json`);
```

- [ ] **Step 5: Generate both data files**

Run:
```bash
cd tools && node yaml-to-raw-json.mjs && node dump-elements.mjs
```
Expected: prints `wrote 118 elements to elements.raw.json` and `wrote 118 elements to elements.golden.json`.

- [ ] **Step 6: Write the failing test `DataPresenceTests.swift`**

```swift
import XCTest
@testable import ChemCore

final class DataPresenceTests: XCTestCase {
    func test_rawDataBundlesAll118() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "elements.raw", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let all = try RawElement.decodeAll(from: data)
        XCTAssertEqual(all.count, 118)
        let fe = try XCTUnwrap(all.first { $0.symbol == "Fe" })
        XCTAssertEqual(fe.atomicNumber, 26)
        XCTAssertEqual(fe.massNumber, 56)
    }
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter DataPresenceTests 2>&1 | tail -15`
Expected: PASS (resource bundled, 118 elements, Fe present).

- [ ] **Step 8: Ignore tools/node_modules and commit**

Run:
```bash
printf 'node_modules/\n' > tools/.gitignore
git add tools/package.json tools/.gitignore tools/yaml-to-raw-json.mjs tools/dump-elements.mjs
git add ChemCore/Sources/ChemCore/Resources/elements.raw.json
git add ChemCore/Tests/ChemCoreTests/Fixtures/elements.golden.json
git add ChemCore/Tests/ChemCoreTests/DataPresenceTests.swift
git commit -m "chore: generate element data from yaml and golden fixture"
```

---

### Task 9: Data — derived Element and PeriodicTable loader

**Files:**
- Create: `ChemCore/Sources/ChemCore/Data/Element.swift`
- Create: `ChemCore/Sources/ChemCore/Data/PeriodicTable.swift`
- Test: `ChemCore/Tests/ChemCoreTests/PeriodicTableTests.swift`

**Interfaces:**
- Consumes: `RawElement`, `Block`, `Category`, `ElementClass`, `block`, `period`, `group`, `category`, `elementClass`, `oxidationStates`, `electronConfiguration`, `atomicMassFromIsotopes`.
- Produces:
  - `struct Element` wrapping a `RawElement` plus derived `block: Block`, `period: Int`, `group: Int`, `category: Category`, `elementClass: ElementClass`, `oxidationStates: [Int]`, `electronConfiguration: String`, `computedAtomicMass: Double?`; with passthrough `symbol`, `name`, `atomicNumber`, `massNumber`, `atomicMass`. Built by `init(raw: RawElement) throws`.
  - `struct PeriodicTable { let elements: [Element] }` with `static func load() throws -> PeriodicTable` (reads bundled `elements.raw.json`), `func bySymbol(_:) -> Element?`, `func byAtomicNumber(_:) -> Element?`.

- [ ] **Step 1: Write the failing test `PeriodicTableTests.swift`**

```swift
import XCTest
@testable import ChemCore

final class PeriodicTableTests: XCTestCase {
    func test_loadsAll118() throws {
        let pt = try PeriodicTable.load()
        XCTAssertEqual(pt.elements.count, 118)
    }
    func test_ironDerivedFields() throws {
        let pt = try PeriodicTable.load()
        let fe = try XCTUnwrap(pt.bySymbol("Fe"))
        XCTAssertEqual(fe.group, 8)
        XCTAssertEqual(fe.period, 4)
        XCTAssertEqual(fe.block, .d)
        XCTAssertEqual(fe.category, .transitionMetal)
        XCTAssertEqual(fe.elementClass, .metal)
        XCTAssertEqual(fe.oxidationStates, [2, 3])
        XCTAssertEqual(fe.electronConfiguration, "1s2 2s2 2p6 3s2 3p6 3d6 4s2")
        XCTAssertEqual(try XCTUnwrap(fe.computedAtomicMass), 55.845, accuracy: 0.01)
    }
    func test_lookupByAtomicNumber() throws {
        let pt = try PeriodicTable.load()
        XCTAssertEqual(pt.byAtomicNumber(1)?.symbol, "H")
        XCTAssertEqual(pt.byAtomicNumber(118)?.symbol, "Og")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter PeriodicTableTests 2>&1 | tail -15`
Expected: FAIL — `Element`/`PeriodicTable` not found.

- [ ] **Step 3: Create `Element.swift`**

```swift
import Foundation

public struct Element {
    public let raw: RawElement
    public let block: Block
    public let period: Int
    public let group: Int
    public let category: Category
    public let elementClass: ElementClass
    public let oxidationStates: [Int]
    public let electronConfiguration: String
    public let computedAtomicMass: Double?

    public var atomicNumber: Int { raw.atomicNumber }
    public var symbol: String { raw.symbol }
    public var name: String { raw.name }
    public var massNumber: Int { raw.massNumber }
    public var atomicMass: Double { raw.atomicMass }

    public init(raw: RawElement) throws {
        let z = raw.atomicNumber
        self.raw = raw
        self.block = try ChemCore.block(z)
        self.period = try ChemCore.period(z)
        self.group = try ChemCore.group(z)
        self.category = try ChemCore.category(z)
        self.elementClass = try ChemCore.elementClass(z)
        self.oxidationStates = try ChemCore.oxidationStates(z)
        self.electronConfiguration = try electronConfiguration(z).description
        self.computedAtomicMass = atomicMassFromIsotopes(raw.isotopes)
    }
}
```

- [ ] **Step 4: Create `PeriodicTable.swift`**

```swift
import Foundation

public struct PeriodicTable {
    public let elements: [Element]

    public static func load() throws -> PeriodicTable {
        guard let url = Bundle.module.url(forResource: "elements.raw", withExtension: "json") else {
            throw DataError.missingResource
        }
        let data = try Data(contentsOf: url)
        let raws = try RawElement.decodeAll(from: data)
        let elements = try raws
            .sorted { $0.atomicNumber < $1.atomicNumber }
            .map { try Element(raw: $0) }
        return PeriodicTable(elements: elements)
    }

    public func bySymbol(_ symbol: String) -> Element? {
        elements.first { $0.symbol == symbol }
    }
    public func byAtomicNumber(_ z: Int) -> Element? {
        elements.first { $0.atomicNumber == z }
    }

    public enum DataError: Error { case missingResource }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter PeriodicTableTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add ChemCore/Sources/ChemCore/Data/Element.swift ChemCore/Sources/ChemCore/Data/PeriodicTable.swift ChemCore/Tests/ChemCoreTests/PeriodicTableTests.swift
git commit -m "feat: compute derived element fields and load periodic table"
```

---

### Task 10: Golden fidelity — Swift-computed fields match the WASM for all 118

**Files:**
- Create: `ChemCore/Tests/ChemCoreTests/GoldenFidelityTests.swift`

**Interfaces:**
- Consumes: `PeriodicTable`, `Element`, and the bundled `elements.golden.json` fixture.
- Produces: a single test asserting every derived field matches the WASM output for all 118 elements.

- [ ] **Step 1: Write the test `GoldenFidelityTests.swift`**

```swift
import XCTest
@testable import ChemCore

private struct Golden: Decodable {
    let atomic_number: Int
    let symbol: String
    let group: Int
    let period: Int
    let block: String
    let category: String
    let `class`: String
    let oxidation_states: [Int]
    let electron_configuration: String
    let computed_atomic_mass: Double?
}

final class GoldenFidelityTests: XCTestCase {
    func test_allDerivedFieldsMatchWasm() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "elements.golden", withExtension: "json"))
        let golden = try JSONDecoder().decode([Golden].self, from: Data(contentsOf: url))
        XCTAssertEqual(golden.count, 118)

        let pt = try PeriodicTable.load()
        for g in golden {
            let e = try XCTUnwrap(pt.byAtomicNumber(g.atomic_number), "z=\(g.atomic_number)")
            let ctx = "\(g.symbol) (z=\(g.atomic_number))"
            XCTAssertEqual(e.symbol, g.symbol, ctx)
            XCTAssertEqual(e.group, g.group, ctx)
            XCTAssertEqual(e.period, g.period, ctx)
            XCTAssertEqual(e.block.rawValue, g.block, ctx)
            XCTAssertEqual(e.category.rawValue, g.category, ctx)
            XCTAssertEqual(e.elementClass.rawValue, g.class, ctx)
            XCTAssertEqual(e.oxidationStates, g.oxidation_states, ctx)
            XCTAssertEqual(e.electronConfiguration, g.electron_configuration, ctx)
            if let expected = g.computed_atomic_mass {
                XCTAssertEqual(try XCTUnwrap(e.computedAtomicMass, ctx), expected, accuracy: 1e-6, ctx)
            }
        }
    }
}
```

- [ ] **Step 2: Run the test**

Run: `cd ChemCore && swift test --filter GoldenFidelityTests 2>&1 | tail -25`
Expected: PASS. If any element fails, the failure message names the element — fix the corresponding `PTDomain` logic before continuing (this is the fidelity gate).

- [ ] **Step 3: Commit**

```bash
git add ChemCore/Tests/ChemCoreTests/GoldenFidelityTests.swift
git commit -m "test: assert PTDomain matches WASM for all 118 elements"
```

---

### Task 11: Engine — gcd

**Files:**
- Create: `ChemCore/Sources/ChemCore/Engine/MathUtil.swift`
- Test: `ChemCore/Tests/ChemCoreTests/MathUtilTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `func gcd(_ a: Int, _ b: Int) -> Int` (Euclidean; `gcd(a, 0) == a`).

- [ ] **Step 1: Write the failing test `MathUtilTests.swift`**

```swift
import XCTest
@testable import ChemCore

final class MathUtilTests: XCTestCase {
    func test_gcd() {
        XCTAssertEqual(gcd(12, 8), 4)
        XCTAssertEqual(gcd(2, 2), 2)
        XCTAssertEqual(gcd(3, 1), 1)
        XCTAssertEqual(gcd(5, 0), 5)
        XCTAssertEqual(gcd(6, 4), 2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter MathUtilTests 2>&1 | tail -15`
Expected: FAIL — `gcd` not found.

- [ ] **Step 3: Create `MathUtil.swift`**

```swift
/// Greatest common divisor (Euclidean). gcd(a, 0) == a.
public func gcd(_ a: Int, _ b: Int) -> Int {
    b == 0 ? a : gcd(b, a % b)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter MathUtilTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Engine/MathUtil.swift ChemCore/Tests/ChemCoreTests/MathUtilTests.swift
git commit -m "feat: add gcd helper"
```

---

### Task 12: Engine — valence electrons

**Files:**
- Create: `ChemCore/Sources/ChemCore/Engine/Valence.swift`
- Test: `ChemCore/Tests/ChemCoreTests/ValenceTests.swift`

**Interfaces:**
- Consumes: nothing (string + group input).
- Produces:
  - `func groupToValenceFallback(_ group: Int) -> Int`.
  - `func isTransitionMetal(_ group: Int) -> Bool`.
  - `func parseValenceElectrons(config: String, group: Int) -> Int` (ports `valence.ts` exactly: strip noble-gas prefix, parse `\d[spdf]\d+` tokens, sum electrons in the highest principal shell; fall back to the group rule).

- [ ] **Step 1: Write the failing test `ValenceTests.swift`**

```swift
import XCTest
@testable import ChemCore

final class ValenceTests: XCTestCase {
    func test_fallback() {
        XCTAssertEqual(groupToValenceFallback(1), 1)
        XCTAssertEqual(groupToValenceFallback(2), 2)
        XCTAssertEqual(groupToValenceFallback(14), 4)
        XCTAssertEqual(groupToValenceFallback(17), 7)
        XCTAssertEqual(groupToValenceFallback(8), 0)   // transition: no fallback
    }
    func test_isTransitionMetal() {
        XCTAssertTrue(isTransitionMetal(3))
        XCTAssertTrue(isTransitionMetal(12))
        XCTAssertFalse(isTransitionMetal(2))
        XCTAssertFalse(isTransitionMetal(13))
    }
    func test_parseHighestShell() {
        // Na: 1s2 2s2 2p6 3s1 -> highest n=3 -> 1
        XCTAssertEqual(parseValenceElectrons(config: "1s2 2s2 2p6 3s1", group: 1), 1)
        // Cl: highest n=3 -> 3s2 + 3p5 = 7
        XCTAssertEqual(parseValenceElectrons(config: "1s2 2s2 2p6 3s2 3p5", group: 17), 7)
        // Fe: highest n=4 -> 4s2 = 2
        XCTAssertEqual(parseValenceElectrons(config: "1s2 2s2 2p6 3s2 3p6 3d6 4s2", group: 8), 2)
    }
    func test_stripsNobleGasPrefix() {
        XCTAssertEqual(parseValenceElectrons(config: "[Ne] 3s2 3p3", group: 15), 5)
    }
    func test_emptyFallsBackToGroup() {
        XCTAssertEqual(parseValenceElectrons(config: "", group: 16), 6)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter ValenceTests 2>&1 | tail -15`
Expected: FAIL — `parseValenceElectrons` not found.

- [ ] **Step 3: Create `Valence.swift`**

```swift
import Foundation

public func groupToValenceFallback(_ group: Int) -> Int {
    if group <= 2 { return group }
    if group >= 13 { return group - 10 }
    return 0
}

public func isTransitionMetal(_ group: Int) -> Bool {
    group >= 3 && group <= 12
}

public func parseValenceElectrons(config: String, group: Int) -> Int {
    // Strip a noble-gas prefix e.g. "[Ne] 3s2" -> "3s2".
    let stripped = config
        .replacingOccurrences(of: #"\[[A-Z][a-z]?\]\s*"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)
    if stripped.isEmpty { return groupToValenceFallback(group) }

    var subshells: [(n: Int, count: Int)] = []
    for token in stripped.split(whereSeparator: { $0.isWhitespace }) {
        if let m = token.wholeMatch(of: /^(\d)[spdf](\d+)$/),
           let n = Int(m.1), let count = Int(m.2) {
            subshells.append((n, count))
        }
    }
    if subshells.isEmpty { return groupToValenceFallback(group) }

    let maxN = subshells.map(\.n).max()!
    return subshells.filter { $0.n == maxN }.reduce(0) { $0 + $1.count }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter ValenceTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Engine/Valence.swift ChemCore/Tests/ChemCoreTests/ValenceTests.swift
git commit -m "feat: port valence electron parsing"
```

---

### Task 13: Engine — bonding rules

**Files:**
- Create: `ChemCore/Sources/ChemCore/Engine/Bonding.swift`
- Test: `ChemCore/Tests/ChemCoreTests/BondingTests.swift`

**Interfaces:**
- Consumes: `ElementClass`.
- Produces:
  - `enum BondingType: String, Equatable { case ionic = "Ionic", covalent = "Covalent", metallic = "Metallic" }`.
  - `func determineBonding(_ a: ElementClass, _ b: ElementClass) -> BondingType`.
  - `func bondingType(aClass: ElementClass, bClass: ElementClass, aPolyatomic: Bool, bPolyatomic: Bool) -> BondingType` (polyatomic involved ⇒ `.ionic`).

- [ ] **Step 1: Write the failing test `BondingTests.swift`**

```swift
import XCTest
@testable import ChemCore

final class BondingTests: XCTestCase {
    func test_determineBonding() {
        XCTAssertEqual(determineBonding(.metal, .metal), .metallic)
        XCTAssertEqual(determineBonding(.nonMetal, .nonMetal), .covalent)
        XCTAssertEqual(determineBonding(.metalloid, .nonMetal), .covalent)
        XCTAssertEqual(determineBonding(.metalloid, .metalloid), .covalent)
        XCTAssertEqual(determineBonding(.metal, .nonMetal), .ionic)
        XCTAssertEqual(determineBonding(.metal, .metalloid), .ionic)
    }
    func test_polyatomicAlwaysIonic() {
        XCTAssertEqual(bondingType(aClass: .nonMetal, bClass: .nonMetal,
                                   aPolyatomic: true, bPolyatomic: false), .ionic)
        XCTAssertEqual(bondingType(aClass: .metal, bClass: .metal,
                                   aPolyatomic: false, bPolyatomic: true), .ionic)
        XCTAssertEqual(bondingType(aClass: .metal, bClass: .metal,
                                   aPolyatomic: false, bPolyatomic: false), .metallic)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter BondingTests 2>&1 | tail -15`
Expected: FAIL — `determineBonding`/`BondingType` not found.

- [ ] **Step 3: Create `Bonding.swift`**

```swift
public enum BondingType: String, Equatable {
    case ionic = "Ionic", covalent = "Covalent", metallic = "Metallic"
}

public func determineBonding(_ a: ElementClass, _ b: ElementClass) -> BondingType {
    if a == .metal && b == .metal { return .metallic }
    if (a == .metalloid || a == .nonMetal) && (b == .metalloid || b == .nonMetal) { return .covalent }
    return .ionic
}

public func bondingType(aClass: ElementClass, bClass: ElementClass,
                        aPolyatomic: Bool, bPolyatomic: Bool) -> BondingType {
    if aPolyatomic || bPolyatomic { return .ionic }
    return determineBonding(aClass, bClass)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter BondingTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Engine/Bonding.swift ChemCore/Tests/ChemCoreTests/BondingTests.swift
git commit -m "feat: port bond-type determination rules"
```

---

### Task 14: Engine — covalent stoichiometry and IUPAC ordering

**Files:**
- Create: `ChemCore/Sources/ChemCore/Engine/CovalentStoich.swift`
- Test: `ChemCore/Tests/ChemCoreTests/CovalentStoichTests.swift`

**Interfaces:**
- Consumes: `gcd`.
- Produces:
  - `func calcStoich(veA: Int, veB: Int) -> (nA: Int, nB: Int, bondOrder: Int)` (ports `shellTarget`/`bondsNeeded`/`calcStoich`).
  - `func iupacFirst(_ symbolA: String, _ symbolB: String) -> Bool` (true when A is written first; missing symbols rank 0).

- [ ] **Step 1: Write the failing test `CovalentStoichTests.swift`**

```swift
import XCTest
@testable import ChemCore

final class CovalentStoichTests: XCTestCase {
    func test_stoich_HCl_singleBond() {
        let s = calcStoich(veA: 1, veB: 7)   // H + Cl
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 1); XCTAssertEqual(s.bondOrder, 1)
    }
    func test_stoich_H2O() {
        let s = calcStoich(veA: 1, veB: 6)   // H + O -> needs 1 and 2 -> nH=2, nO=1
        XCTAssertEqual(s.nA, 2); XCTAssertEqual(s.nB, 1); XCTAssertEqual(s.bondOrder, 1)
    }
    func test_stoich_N2_tripleBond() {
        let s = calcStoich(veA: 5, veB: 5)   // N + N -> 3 and 3 -> 1:1 triple
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 1); XCTAssertEqual(s.bondOrder, 3)
    }
    func test_stoich_fullShellFallsBackTo1_1_1() {
        let s = calcStoich(veA: 8, veB: 4)   // bondsNeeded(8)=0 -> (1,1,1)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 1); XCTAssertEqual(s.bondOrder, 1)
    }
    func test_iupacFirst() {
        XCTAssertTrue(iupacFirst("C", "O"))   // C(3) <= O(12)
        XCTAssertFalse(iupacFirst("O", "C"))
        XCTAssertTrue(iupacFirst("B", "F"))
        XCTAssertTrue(iupacFirst("Na", "Cl")) // both default 0 -> a first when equal
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter CovalentStoichTests 2>&1 | tail -15`
Expected: FAIL — `calcStoich`/`iupacFirst` not found.

- [ ] **Step 3: Create `CovalentStoich.swift`**

```swift
private func shellTarget(_ ve: Int) -> Int { ve <= 2 ? 2 : 8 }
private func bondsNeeded(_ ve: Int) -> Int { max(0, shellTarget(ve) - ve) }

public func calcStoich(veA: Int, veB: Int) -> (nA: Int, nB: Int, bondOrder: Int) {
    let bA = bondsNeeded(veA), bB = bondsNeeded(veB)
    if bA == 0 || bB == 0 { return (1, 1, 1) }
    let g = gcd(bA, bB)
    return (nA: bB / g, nB: bA / g, bondOrder: g)
}

private let iupacOrder: [String: Int] = [
    "B": 1, "Si": 2, "C": 3, "Sb": 4, "As": 5, "P": 6, "N": 7, "H": 8,
    "Te": 9, "Se": 10, "S": 11, "O": 12, "I": 13, "Br": 14, "Cl": 15, "F": 16,
]

/// True when symbol A is written first (lower or equal IUPAC index; unknown symbols rank 0).
public func iupacFirst(_ symbolA: String, _ symbolB: String) -> Bool {
    (iupacOrder[symbolA] ?? 0) <= (iupacOrder[symbolB] ?? 0)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter CovalentStoichTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Engine/CovalentStoich.swift ChemCore/Tests/ChemCoreTests/CovalentStoichTests.swift
git commit -m "feat: port covalent stoichiometry and IUPAC ordering"
```

---

### Task 15: Engine — metallic electron count

**Files:**
- Create: `ChemCore/Sources/ChemCore/Engine/Metallic.swift`
- Test: `ChemCore/Tests/ChemCoreTests/MetallicTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `func metallicElectronCount(veA: Int, veB: Int, poolSize: Int = 12) -> Int` (`min(3*veA + 3*veB, poolSize)`).

- [ ] **Step 1: Write the failing test `MetallicTests.swift`**

```swift
import XCTest
@testable import ChemCore

final class MetallicTests: XCTestCase {
    func test_electronCount() {
        XCTAssertEqual(metallicElectronCount(veA: 1, veB: 1), 6)   // 3 + 3
        XCTAssertEqual(metallicElectronCount(veA: 2, veB: 2), 12)  // 6 + 6
        XCTAssertEqual(metallicElectronCount(veA: 3, veB: 3), 12)  // 18 capped to 12
        XCTAssertEqual(metallicElectronCount(veA: 1, veB: 0), 3)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter MetallicTests 2>&1 | tail -15`
Expected: FAIL — `metallicElectronCount` not found.

- [ ] **Step 3: Create `Metallic.swift`**

```swift
/// Delocalised electron count for the electron-sea model, capped at the pool size.
public func metallicElectronCount(veA: Int, veB: Int, poolSize: Int = 12) -> Int {
    min(3 * veA + 3 * veB, poolSize)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter MetallicTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ChemCore/Sources/ChemCore/Engine/Metallic.swift ChemCore/Tests/ChemCoreTests/MetallicTests.swift
git commit -m "feat: port metallic electron count"
```

---

### Task 16: State — value types (phases, zone, polyatomic ions)

**Files:**
- Create: `ChemCore/Sources/ChemCore/State/Phase.swift`
- Create: `ChemCore/Sources/ChemCore/State/ZoneState.swift`
- Create: `ChemCore/Sources/ChemCore/State/PolyatomicIon.swift`
- Test: `ChemCore/Tests/ChemCoreTests/ZoneStateTests.swift`

**Interfaces:**
- Consumes: `Element`, `ElementClass`, `BondingType`, `parseValenceElectrons`.
- Produces:
  - `enum CanvasPhase { case selecting, slotAFilled, explaining, animatingCrossover, showingCovalent, showingMetallic, complete }`.
  - `enum Slot { case a, b }` with `var other: Slot`.
  - `enum ZoneStatus { case neutral, deducing, ionized }`.
  - `struct ZoneState: Equatable` with `symbol, elementClass, isPolyatomic, isTransition, valenceElectrons, oxidationStates, derivedCharge: Int?, wrongCount, status`; plus `init(element: Element)` and `init(polyatomic: PolyatomicIon)`.
  - `struct PolyatomicIon: Equatable { let symbol, name: String; let charge: Int; let formula: String }` and `static let polyatomicIons: [PolyatomicIon]` (the 6 ions).

- [ ] **Step 1: Write the failing test `ZoneStateTests.swift`**

```swift
import XCTest
@testable import ChemCore

final class ZoneStateTests: XCTestCase {
    func test_slotOther() {
        XCTAssertEqual(Slot.a.other, .b)
        XCTAssertEqual(Slot.b.other, .a)
    }
    func test_zoneFromElement_iron_isTransition() throws {
        let pt = try PeriodicTable.load()
        let fe = try XCTUnwrap(pt.bySymbol("Fe"))
        let zone = ZoneState(element: fe)
        XCTAssertEqual(zone.symbol, "Fe")
        XCTAssertEqual(zone.elementClass, .metal)
        XCTAssertFalse(zone.isPolyatomic)
        XCTAssertTrue(zone.isTransition)           // D-block -> picker eligible
        XCTAssertEqual(zone.valenceElectrons, 2)
        XCTAssertEqual(zone.oxidationStates, [2, 3])
        XCTAssertEqual(zone.status, .neutral)
    }
    func test_zoneFromElement_sodium_notTransition() throws {
        let pt = try PeriodicTable.load()
        let na = try XCTUnwrap(pt.bySymbol("Na"))
        let zone = ZoneState(element: na)
        XCTAssertFalse(zone.isTransition)
        XCTAssertEqual(zone.valenceElectrons, 1)
    }
    func test_polyatomicIons() {
        XCTAssertEqual(PolyatomicIon.polyatomicIons.count, 6)
        let sulfate = PolyatomicIon.polyatomicIons.first { $0.symbol == "SO₄" }
        XCTAssertEqual(sulfate?.charge, -2)
        let zone = ZoneState(polyatomic: PolyatomicIon.polyatomicIons[0])
        XCTAssertTrue(zone.isPolyatomic)
        XCTAssertEqual(zone.elementClass, .nonMetal)
        XCTAssertEqual(zone.valenceElectrons, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter ZoneStateTests 2>&1 | tail -15`
Expected: FAIL — `Slot`/`ZoneState`/`PolyatomicIon` not found.

- [ ] **Step 3: Create `Phase.swift`**

```swift
public enum CanvasPhase: Equatable {
    case selecting
    case slotAFilled
    case explaining
    case animatingCrossover
    case showingCovalent
    case showingMetallic
    case complete
}

public enum Slot: Equatable {
    case a, b
    public var other: Slot { self == .a ? .b : .a }
}

public enum ZoneStatus: Equatable {
    case neutral, deducing, ionized
}
```

- [ ] **Step 4: Create `PolyatomicIon.swift`**

```swift
public struct PolyatomicIon: Equatable {
    public let symbol: String
    public let name: String
    public let charge: Int
    public let formula: String

    public static let polyatomicIons: [PolyatomicIon] = [
        PolyatomicIon(symbol: "OH",  name: "Hydroxide", charge: -1, formula: "OH⁻"),
        PolyatomicIon(symbol: "NO₃", name: "Nitrate",   charge: -1, formula: "NO₃⁻"),
        PolyatomicIon(symbol: "SO₄", name: "Sulfate",   charge: -2, formula: "SO₄²⁻"),
        PolyatomicIon(symbol: "CO₃", name: "Carbonate", charge: -2, formula: "CO₃²⁻"),
        PolyatomicIon(symbol: "PO₄", name: "Phosphate", charge: -3, formula: "PO₄³⁻"),
        PolyatomicIon(symbol: "NH₄", name: "Ammonium",  charge: 1,  formula: "NH₄⁺"),
    ]
}
```

- [ ] **Step 5: Create `ZoneState.swift`**

```swift
public struct ZoneState: Equatable {
    public var symbol: String
    public var elementClass: ElementClass
    public var isPolyatomic: Bool
    public var isTransition: Bool
    public var valenceElectrons: Int
    public var oxidationStates: [Int]
    public var derivedCharge: Int?
    public var wrongCount: Int
    public var status: ZoneStatus

    public init(symbol: String, elementClass: ElementClass, isPolyatomic: Bool,
                isTransition: Bool, valenceElectrons: Int, oxidationStates: [Int],
                derivedCharge: Int? = nil, wrongCount: Int = 0, status: ZoneStatus = .neutral) {
        self.symbol = symbol; self.elementClass = elementClass; self.isPolyatomic = isPolyatomic
        self.isTransition = isTransition; self.valenceElectrons = valenceElectrons
        self.oxidationStates = oxidationStates; self.derivedCharge = derivedCharge
        self.wrongCount = wrongCount; self.status = status
    }

    public init(element: Element) {
        self.init(
            symbol: element.symbol,
            elementClass: element.elementClass,
            isPolyatomic: false,
            isTransition: element.block == .d,
            valenceElectrons: parseValenceElectrons(config: element.electronConfiguration, group: element.group),
            oxidationStates: element.oxidationStates
        )
    }

    public init(polyatomic ion: PolyatomicIon) {
        self.init(
            symbol: ion.symbol,
            elementClass: .nonMetal,
            isPolyatomic: true,
            isTransition: false,
            valenceElectrons: 0,
            oxidationStates: [ion.charge]
        )
    }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter ZoneStateTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add ChemCore/Sources/ChemCore/State/Phase.swift ChemCore/Sources/ChemCore/State/ZoneState.swift ChemCore/Sources/ChemCore/State/PolyatomicIon.swift ChemCore/Tests/ChemCoreTests/ZoneStateTests.swift
git commit -m "feat: add canvas value types and zone state factories

React's makeZoneState compares block to lowercase 'd' against
uppercase data, so isTransition is always false; the Swift port
uses the Block enum so D-block elements trigger the picker."
```

---

### Task 17: State — the canvas reducer

**Files:**
- Create: `ChemCore/Sources/ChemCore/State/CanvasState.swift`
- Create: `ChemCore/Sources/ChemCore/State/CanvasReducer.swift`
- Test: `ChemCore/Tests/ChemCoreTests/CanvasReducerTests.swift`

**Interfaces:**
- Consumes: `CanvasPhase`, `Slot`, `ZoneStatus`, `ZoneState`, `BondingType`, `bondingType(...)`.
- Produces:
  - `struct CanvasState: Equatable { var canvasPhase: CanvasPhase; var bondingType: BondingType?; var slotA: ZoneState?; var slotB: ZoneState?; static let initial: CanvasState }`.
  - `enum CanvasAction { case dropElement(slot: Slot, zone: ZoneState); case pickTMCharge(slot: Slot, charge: Int); case dismissExplanation; case replaceElement(slot: Slot); case crossoverComplete; case reset }`.
  - `func canvasReducer(_ state: CanvasState, _ action: CanvasAction) -> CanvasState` (pure; faithful port of `reducer.ts`).

- [ ] **Step 1: Write the failing test `CanvasReducerTests.swift`** (mirrors `reducer.ts` behavior)

```swift
import XCTest
@testable import ChemCore

final class CanvasReducerTests: XCTestCase {
    private func metal(_ s: String, oxidation: [Int] = [1], transition: Bool = false) -> ZoneState {
        ZoneState(symbol: s, elementClass: .metal, isPolyatomic: false, isTransition: transition,
                  valenceElectrons: 1, oxidationStates: oxidation)
    }
    private func nonmetal(_ s: String, oxidation: [Int] = [-1]) -> ZoneState {
        ZoneState(symbol: s, elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                  valenceElectrons: 7, oxidationStates: oxidation)
    }

    func test_firstDrop_goesToSlotAFilled() {
        let s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na")))
        XCTAssertEqual(s.canvasPhase, .slotAFilled)
        XCTAssertEqual(s.slotA?.symbol, "Na")
        XCTAssertNil(s.bondingType)
    }

    func test_ionic_autoIonizesBothSlots() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na", oxidation: [1])))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl", oxidation: [-1])))
        XCTAssertEqual(s.bondingType, .ionic)
        XCTAssertEqual(s.canvasPhase, .explaining)
        XCTAssertEqual(s.slotA?.status, .ionized)
        XCTAssertEqual(s.slotA?.derivedCharge, 1)
        XCTAssertEqual(s.slotB?.status, .ionized)
        XCTAssertEqual(s.slotB?.derivedCharge, -1)
    }

    func test_ionic_transitionMetalDeduces() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Fe", oxidation: [2, 3], transition: true)))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl")))
        XCTAssertEqual(s.bondingType, .ionic)
        XCTAssertEqual(s.slotA?.status, .deducing)
        // dismiss is blocked while a slot is still deducing
        let blocked = canvasReducer(s, .dismissExplanation)
        XCTAssertEqual(blocked.canvasPhase, .explaining)
        // pick charge, then dismiss advances to crossover
        let picked = canvasReducer(s, .pickTMCharge(slot: .a, charge: 3))
        XCTAssertEqual(picked.slotA?.status, .ionized)
        XCTAssertEqual(picked.slotA?.derivedCharge, 3)
        let advanced = canvasReducer(picked, .dismissExplanation)
        XCTAssertEqual(advanced.canvasPhase, .animatingCrossover)
    }

    func test_covalent_goesToExplainingThenShowing() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: nonmetal("H")))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl")))
        XCTAssertEqual(s.bondingType, .covalent)
        XCTAssertEqual(s.canvasPhase, .explaining)
        let shown = canvasReducer(s, .dismissExplanation)
        XCTAssertEqual(shown.canvasPhase, .showingCovalent)
    }

    func test_metallic_goesToShowing() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na")))
        s = canvasReducer(s, .dropElement(slot: .b, zone: metal("Mg")))
        XCTAssertEqual(s.bondingType, .metallic)
        let shown = canvasReducer(s, .dismissExplanation)
        XCTAssertEqual(shown.canvasPhase, .showingMetallic)
    }

    func test_dropOnBothFilled_clearsOtherAndRestarts() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na")))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl")))
        s = canvasReducer(s, .dropElement(slot: .a, zone: metal("K")))
        XCTAssertEqual(s.slotA?.symbol, "K")
        XCTAssertNil(s.slotB)
        XCTAssertEqual(s.canvasPhase, .slotAFilled)
        XCTAssertNil(s.bondingType)
    }

    func test_replaceElement_resetsOtherToNeutral() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na")))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl")))
        s = canvasReducer(s, .replaceElement(slot: .a))
        XCTAssertNil(s.slotA)
        XCTAssertEqual(s.slotB?.status, .neutral)
        XCTAssertNil(s.slotB?.derivedCharge)
        XCTAssertEqual(s.canvasPhase, .slotAFilled)
    }

    func test_crossoverCompleteAndReset() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na")))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl")))
        s = canvasReducer(s, .dismissExplanation)   // -> animatingCrossover
        s = canvasReducer(s, .crossoverComplete)
        XCTAssertEqual(s.canvasPhase, .complete)
        let r = canvasReducer(s, .reset)
        XCTAssertEqual(r, .initial)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ChemCore && swift test --filter CanvasReducerTests 2>&1 | tail -15`
Expected: FAIL — `CanvasState`/`canvasReducer` not found.

- [ ] **Step 3: Create `CanvasState.swift`**

```swift
public struct CanvasState: Equatable {
    public var canvasPhase: CanvasPhase
    public var bondingType: BondingType?
    public var slotA: ZoneState?
    public var slotB: ZoneState?

    public init(canvasPhase: CanvasPhase, bondingType: BondingType?, slotA: ZoneState?, slotB: ZoneState?) {
        self.canvasPhase = canvasPhase; self.bondingType = bondingType
        self.slotA = slotA; self.slotB = slotB
    }

    public static let initial = CanvasState(
        canvasPhase: .selecting, bondingType: nil, slotA: nil, slotB: nil
    )
}

public enum CanvasAction {
    case dropElement(slot: Slot, zone: ZoneState)
    case pickTMCharge(slot: Slot, charge: Int)
    case dismissExplanation
    case replaceElement(slot: Slot)
    case crossoverComplete
    case reset
}
```

- [ ] **Step 4: Create `CanvasReducer.swift`** (faithful port of `reducer.ts`)

```swift
private func get(_ state: CanvasState, _ slot: Slot) -> ZoneState? {
    slot == .a ? state.slotA : state.slotB
}
private func set(_ state: CanvasState, _ slot: Slot, _ zone: ZoneState?) -> CanvasState {
    var s = state
    if slot == .a { s.slotA = zone } else { s.slotB = zone }
    return s
}

/// Transition/empty-oxidation zones must be deduced; otherwise ionize to the first state.
private func autoIonize(_ zone: ZoneState) -> ZoneState {
    var z = zone
    if z.isTransition { z.status = .deducing; return z }
    if z.oxidationStates.isEmpty { z.status = .deducing; return z }
    z.status = .ionized
    z.derivedCharge = z.oxidationStates[0]
    return z
}

public func canvasReducer(_ state: CanvasState, _ action: CanvasAction) -> CanvasState {
    switch action {
    case let .dropElement(slot, zone):
        var newZone = zone
        newZone.status = .neutral
        newZone.wrongCount = 0

        // Both slots filled -> new drop resets the other slot and restarts.
        if state.slotA != nil && state.slotB != nil {
            let next = set(state, slot, newZone)
            var cleared = set(next, slot.other, nil)
            cleared.canvasPhase = .slotAFilled
            cleared.bondingType = nil
            return cleared
        }

        var next = set(state, slot, newZone)
        guard let other = get(next, slot.other) else {
            next.canvasPhase = .slotAFilled
            next.bondingType = nil
            return next
        }

        let bonding = bondingType(
            aClass: newZone.elementClass, bClass: other.elementClass,
            aPolyatomic: newZone.isPolyatomic, bPolyatomic: other.isPolyatomic
        )

        if bonding == .covalent || bonding == .metallic {
            next.bondingType = bonding
            next.canvasPhase = .explaining
            return next
        }

        // Ionic — auto-ionise both slots immediately.
        let ionizedNew = autoIonize(newZone)
        let ionizedOther = autoIonize(other)
        next = set(next, slot, ionizedNew)
        next = set(next, slot.other, ionizedOther)
        next.bondingType = bonding
        next.canvasPhase = .explaining
        return next

    case let .pickTMCharge(slot, charge):
        guard var zone = get(state, slot) else { return state }
        zone.status = .ionized
        zone.derivedCharge = charge
        return set(state, slot, zone)

    case .dismissExplanation:
        if state.bondingType == .ionic
            && (state.slotA?.status == .deducing || state.slotB?.status == .deducing) {
            return state
        }
        var s = state
        switch state.bondingType {
        case .ionic:    s.canvasPhase = .animatingCrossover
        case .covalent: s.canvasPhase = .showingCovalent
        case .metallic: s.canvasPhase = .showingMetallic
        case .none:     return state
        }
        return s

    case let .replaceElement(slot):
        let other = get(state, slot.other)
        var resetOther = other
        resetOther?.status = .neutral
        resetOther?.derivedCharge = nil
        resetOther?.wrongCount = 0
        var cleared = set(state, slot, nil)
        cleared = set(cleared, slot.other, resetOther)
        cleared.canvasPhase = resetOther != nil ? .slotAFilled : .selecting
        cleared.bondingType = nil
        return cleared

    case .crossoverComplete:
        var s = state
        s.canvasPhase = .complete
        return s

    case .reset:
        return .initial
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd ChemCore && swift test --filter CanvasReducerTests 2>&1 | tail -20`
Expected: PASS (all transitions).

- [ ] **Step 6: Run the full suite**

Run: `cd ChemCore && swift test 2>&1 | tail -20`
Expected: all tests pass (PTDomain, Data, golden fidelity, Engine, State).

- [ ] **Step 7: Commit**

```bash
git add ChemCore/Sources/ChemCore/State/CanvasState.swift ChemCore/Sources/ChemCore/State/CanvasReducer.swift ChemCore/Tests/ChemCoreTests/CanvasReducerTests.swift
git commit -m "feat: port canvas state machine reducer"
```

---

## Self-Review

**Spec coverage:**
- Port of `pt-domain` (config/classification/calc) → Tasks 2–6. ✓
- Raw data from 118 YAML → Task 8 (`yaml-to-raw-json.mjs`). ✓
- `elements.raw.json` bundled, derived fields computed at load → Tasks 8–9. ✓
- Golden fidelity vs WASM for all 118 → Task 10. ✓
- Engine (valence, gcd, bonding, covalent stoich, IUPAC, metallic) → Tasks 11–15. ✓
- State machine (all reducer transitions) → Tasks 16–17. ✓
- Polyatomic ions (6 constants) → Task 16. ✓
- No WebAssembly in shipped artifact (Node/WASM only in dev `tools/`) → Tasks 8 scripts are dev-only. ✓
- `isTransition` fix documented → Global Constraints + Task 16 commit. ✓
- Not in this plan (deferred to Plan 2 — UI): SwiftUI views, drag/drop, diagrams, animations, theme, `.xcodeproj`, `@Observable` wrapper around the reducer, app-bundle build/boot verification. The reducer and all logic are intentionally pure value types so Plan 2 can wrap them in `@Observable` without change.

**Placeholder scan:** No TBD/TODO; every code and test step contains complete content. ✓

**Type consistency:** `ElementClass`/`Category`/`Block` raw values match the golden JSON strings ("Metal", "TransitionMetal", "D"). `BondingType` defined once (Task 13) and consumed by State (Tasks 16–17). `ZoneState`/`CanvasState`/`CanvasAction`/`canvasReducer` names are consistent across Tasks 16–17. `Isotope`/`StateOfMatter` defined in `Calc.swift` (Task 6) and reused by `RawElement` (Task 7) — single definition, no duplication. ✓
