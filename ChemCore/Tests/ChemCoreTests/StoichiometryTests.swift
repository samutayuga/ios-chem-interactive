// ChemCore/Tests/ChemCoreTests/StoichiometryTests.swift
import XCTest
@testable import ChemCore

final class StoichiometryTests: XCTestCase {
    func test_balance_water() {
        // H (subscript 2, diatomic) + O (subscript 1, diatomic) -> 2H₂ + O₂ -> 2H₂O
        let e = balanceEquation(subscriptA: 2, molecularityA: 2, subscriptB: 1, molecularityB: 2)
        XCTAssertEqual([e.coeffA, e.coeffB, e.coeffProduct], [2, 1, 2])
    }
    func test_balance_nacl() {
        // Na (1, mono) + Cl (1, diatomic) -> 2Na + Cl₂ -> 2NaCl
        let e = balanceEquation(subscriptA: 1, molecularityA: 1, subscriptB: 1, molecularityB: 2)
        XCTAssertEqual([e.coeffA, e.coeffB, e.coeffProduct], [2, 1, 2])
    }
    func test_balance_mgcl2() {
        // Mg (1, mono) + Cl (2, diatomic) -> Mg + Cl₂ -> MgCl₂
        let e = balanceEquation(subscriptA: 1, molecularityA: 1, subscriptB: 2, molecularityB: 2)
        XCTAssertEqual([e.coeffA, e.coeffB, e.coeffProduct], [1, 1, 1])
    }
    func test_diatomic_set() {
        XCTAssertEqual(naturallyDiatomic, ["H", "N", "O", "F", "Cl", "Br", "I"])
        XCTAssertEqual(molecularity(isDiatomic: true), 2)
        XCTAssertEqual(molecularity(isDiatomic: false), 1)
    }

    // MARK: - Task 2: solveStoichiometry

    private func spec(_ sym: String, _ mass: Double, _ sub: Int, _ di: Bool,
                      _ entry: ReactantEntry?) -> ReactantSpec {
        ReactantSpec(symbol: sym, atomicMass: mass, subscriptInProduct: sub,
                     isDiatomic: di, entry: entry)
    }

    func test_yield_water_stoichiometric() {
        // 2 mol H₂ + 1 mol O₂ -> 2 mol H₂O ; masses H=1, O=16 -> product 18 g/mol
        let h = spec("H", 1, 2, true, ReactantEntry(value: 2, unit: .mole))
        let o = spec("O", 16, 1, true, ReactantEntry(value: 1, unit: .mole))
        let r = solveStoichiometry(a: h, b: o)
        XCTAssertEqual(r.limiting, .both)
        XCTAssertEqual(r.yield.moles, 2, accuracy: 1e-9)
        XCTAssertEqual(r.productMolarMass, 18, accuracy: 1e-9)
        XCTAssertEqual(r.yield.mass, 36, accuracy: 1e-9)
        XCTAssertEqual(r.excess.moles, 0, accuracy: 1e-9)
    }

    func test_excess_hydrogen() {
        // 3 mol H₂ + 1 mol O₂ : extents 1.5 vs 1 -> O limiting, 1 mol H₂ left (2 g)
        let h = spec("H", 1, 2, true, ReactantEntry(value: 3, unit: .mole))
        let o = spec("O", 16, 1, true, ReactantEntry(value: 1, unit: .mole))
        let r = solveStoichiometry(a: h, b: o)
        XCTAssertEqual(r.limiting, .b)
        XCTAssertEqual(r.yield.moles, 2, accuracy: 1e-9)
        XCTAssertEqual(r.excess.moles, 1, accuracy: 1e-9)
        XCTAssertEqual(r.excess.mass, 2, accuracy: 1e-9)   // 1 mol H₂ × 2 g/mol
    }

    func test_mass_unit_conversion() {
        // 32 g O₂ = 1 mol O₂ ; pair with 4 mol H₂ -> O limiting, yield 2 mol H₂O
        let h = spec("H", 1, 2, true, ReactantEntry(value: 4, unit: .mole))
        let o = spec("O", 16, 1, true, ReactantEntry(value: 32, unit: .mass))
        let r = solveStoichiometry(a: h, b: o)
        XCTAssertEqual(r.limiting, .b)
        XCTAssertEqual(r.yield.moles, 2, accuracy: 1e-9)
    }

    func test_blank_is_enough() {
        // A entered, B blank -> A limiting, no excess
        let h = spec("H", 1, 2, true, ReactantEntry(value: 2, unit: .mole))
        let o = spec("O", 16, 1, true, nil)
        let r = solveStoichiometry(a: h, b: o)
        XCTAssertEqual(r.limiting, .a)
        XCTAssertEqual(r.yield.moles, 2, accuracy: 1e-9)
        XCTAssertEqual(r.excess.moles, 0, accuracy: 1e-9)
    }

    func test_both_blank_one_mol_basis() {
        let h = spec("H", 1, 2, true, nil)
        let o = spec("O", 16, 1, true, nil)
        let r = solveStoichiometry(a: h, b: o)
        XCTAssertEqual(r.limiting, .both)
        XCTAssertEqual(r.yield.moles, 2, accuracy: 1e-9)   // coeffProduct × ξ(=1)
    }

    func test_diatomic_messages() {
        let na = spec("Na", 23, 1, false, ReactantEntry(value: 1, unit: .mole))
        let cl = spec("Cl", 35.45, 1, true, ReactantEntry(value: 1, unit: .mole))
        let r = solveStoichiometry(a: na, b: cl)
        XCTAssertEqual(r.diatomicMessages,
                       ["Cl cannot exist as monoatomic, It only exist in Cl₂"])
    }
}
