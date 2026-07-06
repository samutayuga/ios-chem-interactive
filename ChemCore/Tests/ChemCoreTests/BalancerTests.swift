import XCTest
@testable import ChemCore

final class BalancerTests: XCTestCase {
    func test_water_synthesis() {
        // H₂ + O₂ -> H₂O  => [2,1,2]
        let c = balance(reactants: [["H": 2], ["O": 2]], products: [["H": 2, "O": 1]])
        XCTAssertEqual(c, [2, 1, 2])
    }
    func test_neutralisation() {
        // NaOH + HCl -> NaCl + H₂O => [1,1,1,1]
        let c = balance(reactants: [["Na": 1, "O": 1, "H": 1], ["H": 1, "Cl": 1]],
                        products:  [["Na": 1, "Cl": 1], ["H": 2, "O": 1]])
        XCTAssertEqual(c, [1, 1, 1, 1])
    }
    func test_combustion_methane() {
        // CH₄ + O₂ -> CO₂ + H₂O => [1,2,1,2]
        let c = balance(reactants: [["C": 1, "H": 4], ["O": 2]],
                        products:  [["C": 1, "O": 2], ["H": 2, "O": 1]])
        XCTAssertEqual(c, [1, 2, 1, 2])
    }
    func test_carbonate_acid() {
        // 2HCl + Na₂CO₃ -> 2NaCl + CO₂ + H₂O => [2,1,2,1,1]
        let c = balance(reactants: [["H": 1, "Cl": 1], ["Na": 2, "C": 1, "O": 3]],
                        products:  [["Na": 1, "Cl": 1], ["C": 1, "O": 2], ["H": 2, "O": 1]])
        XCTAssertEqual(c, [2, 1, 2, 1, 1])
    }
    func test_unbalanceable_returns_nil() {
        // Element on the left with no home on the right.
        let c = balance(reactants: [["Na": 1]], products: [["Cl": 1]])
        XCTAssertNil(c)
    }
}
