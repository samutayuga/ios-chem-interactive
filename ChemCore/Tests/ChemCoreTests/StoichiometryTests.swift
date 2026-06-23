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
}
