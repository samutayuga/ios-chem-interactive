import XCTest
@testable import ChemCore

final class OxidationStateTests: XCTestCase {
    func test_free_element_is_zero() {
        XCTAssertEqual(oxidationState(of: ["Zn": 1]), ["Zn": 0])
        XCTAssertEqual(oxidationState(of: ["O": 2]), ["O": 0])   // O₂
    }
    func test_binary_ionic() {
        XCTAssertEqual(oxidationState(of: ["Na": 1, "Cl": 1]), ["Na": 1, "Cl": -1])
        XCTAssertEqual(oxidationState(of: ["Mg": 1, "O": 1]), ["Mg": 2, "O": -2])
    }
    func test_solve_by_difference() {
        XCTAssertEqual(oxidationState(of: ["C": 1, "O": 2]), ["C": 4, "O": -2])          // CO₂
        XCTAssertEqual(oxidationState(of: ["K": 1, "Mn": 1, "O": 4]), ["K": 1, "Mn": 7, "O": -2]) // KMnO₄
        XCTAssertEqual(oxidationState(of: ["Fe": 1, "Cl": 3]), ["Fe": 3, "Cl": -1])       // FeCl₃
    }
    func test_water_uses_element_rules() {
        XCTAssertEqual(oxidationState(of: ["H": 2, "O": 1]), ["H": 1, "O": -2])
    }
    func test_polyatomic_factoring() {
        XCTAssertEqual(oxidationState(of: ["Na": 1, "O": 1, "H": 1]), ["Na": 1, "O": -2, "H": 1]) // NaOH
        XCTAssertEqual(oxidationState(of: ["Na": 2, "S": 1, "O": 4]), ["Na": 1, "S": 6, "O": -2]) // Na₂SO₄
        XCTAssertEqual(oxidationState(of: ["Cu": 1, "S": 1, "O": 4]), ["Cu": 2, "S": 6, "O": -2]) // CuSO₄
        XCTAssertEqual(oxidationState(of: ["Na": 2, "C": 1, "O": 3]), ["Na": 1, "C": 4, "O": -2]) // Na₂CO₃
        XCTAssertEqual(oxidationState(of: ["N": 1, "H": 4, "Cl": 1]), ["N": -3, "H": 1, "Cl": -1]) // NH₄Cl
    }
    func test_indeterminate_returns_nil() {
        XCTAssertNil(oxidationState(of: ["Cu": 1, "S": 1]))   // CuS: two rule-less elements
    }
}
