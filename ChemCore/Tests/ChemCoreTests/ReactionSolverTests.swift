// ChemCore/Tests/ChemCoreTests/ReactionSolverTests.swift
import XCTest
@testable import ChemCore

private func el(_ sym: String, mass: Double, _ cls: ElementClass, charge: Int? = nil,
                ve: Int = 0, group: Int = 0, period: Int = 0) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: cls,
            isPolyatomic: false, valenceElectrons: ve, group: group, period: period,
            composition: [sym: 1])
}
private func polyIon(_ sym: String, mass: Double, charge: Int, comp: [String: Int]) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: .nonMetal,
            isPolyatomic: true, valenceElectrons: 0, group: 0, period: 0, composition: comp)
}
private let masses: [String: Double] = [
    "H": 1.008, "O": 16.0, "Na": 22.99, "Cl": 35.45, "C": 12.011,
    "S": 32.06, "Zn": 65.38, "Cu": 63.55,
]
private func mass(_ s: String) -> Double? { masses[s] }

final class ReactionSolverTests: XCTestCase {
    func test_neutralisation_balances_and_is_feasible() {
        let naoh = makeReactant([el("Na", mass: 22.99, .metal, charge: 1),
                                 polyIon("OH", mass: 17.008, charge: -1, comp: ["O": 1, "H": 1])])
        let hcl = makeReactant([el("H", mass: 1.008, .nonMetal, charge: 1),
                               el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        let out = solveReaction(naoh, hcl, entry1: nil, entry2: nil, atomicMass: mass)
        guard case let .success(r) = out else { return XCTFail("expected success") }
        XCTAssertEqual(r.reactionClass, .doubleDisplacement)
        XCTAssertTrue(r.feasible)
        XCTAssertEqual(r.reactants.map(\.coeff), [1, 1])
        XCTAssertEqual(Set(r.products.map(\.formula)), ["NaCl", "H₂O"])
    }
    func test_combustion_methane_coefficients() {
        let ch4 = makeReactant([el("C", mass: 12.011, .nonMetal, ve: 4, group: 14, period: 2),
                                el("H", mass: 1.008, .nonMetal, ve: 1, group: 1, period: 1)])
        let o2 = makeReactant([el("O", mass: 16.0, .nonMetal, charge: -2)])
        let out = solveReaction(ch4, o2, entry1: nil, entry2: nil, atomicMass: mass)
        guard case let .success(r) = out else { return XCTFail("expected success") }
        XCTAssertEqual(r.reactionClass, .combustion)
        // CH₄ + 2O₂ -> CO₂ + 2H₂O
        XCTAssertEqual(r.reactants.map(\.coeff), [1, 2])
        let co2 = r.products.first { $0.formula == "CO₂" }
        let h2o = r.products.first { $0.formula == "H₂O" }
        XCTAssertEqual(co2?.coeff, 1)
        XCTAssertEqual(h2o?.coeff, 2)
    }
    func test_single_displacement_infeasible_result() {
        let cu = makeReactant([el("Cu", mass: 63.55, .metal, charge: 2)])
        let znso4 = makeReactant([el("Zn", mass: 65.38, .metal, charge: 2),
                                  polyIon("SO₄", mass: 96.06, charge: -2, comp: ["S": 1, "O": 4])])
        let out = solveReaction(cu, znso4, entry1: nil, entry2: nil, atomicMass: mass)
        guard case let .success(r) = out else { return XCTFail("expected success") }
        XCTAssertFalse(r.feasible)
        XCTAssertTrue(r.messages.contains { $0.contains("activity series") })
    }
    func test_yield_scales_with_limiting_reactant() {
        // 2 mol NaOH + 1 mol HCl -> HCl limits, 1 mol NaCl + 1 mol H₂O, 1 mol NaOH excess.
        let naoh = makeReactant([el("Na", mass: 22.99, .metal, charge: 1),
                                 polyIon("OH", mass: 17.008, charge: -1, comp: ["O": 1, "H": 1])])
        let hcl = makeReactant([el("H", mass: 1.008, .nonMetal, charge: 1),
                               el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        let out = solveReaction(naoh, hcl,
                                entry1: ReactantEntry(value: 2, unit: .mole),
                                entry2: ReactantEntry(value: 1, unit: .mole),
                                atomicMass: mass)
        guard case let .success(r) = out else { return XCTFail("expected success") }
        XCTAssertEqual(r.limiting, .b)
        let nacl = r.products.first { $0.formula == "NaCl" }!
        let yieldIndex = r.products.firstIndex { $0.formula == "NaCl" }!
        XCTAssertEqual(nacl.coeff, 1)
        XCTAssertEqual(r.yields[yieldIndex].moles, 1.0, accuracy: 1e-6)
        XCTAssertEqual(r.excess.moles, 1.0, accuracy: 1e-6)
    }
}
