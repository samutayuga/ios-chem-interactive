import XCTest
@testable import ChemCore

final class FormulaTextTests: XCTestCase {
    func test_subscript_hides_one() {
        XCTAssertEqual(formulaSubscript(1), "")
        XCTAssertEqual(formulaSubscript(2), "₂")
        XCTAssertEqual(formulaSubscript(12), "₁₂")
    }
    func test_crossover_nacl() {
        let s = crossoverSubscripts(cationCharge: 1, anionCharge: -1)
        XCTAssertEqual(s.cationSub, 1)
        XCTAssertEqual(s.anionSub, 1)
    }
    func test_crossover_mgcl2() {
        let s = crossoverSubscripts(cationCharge: 2, anionCharge: -1)
        XCTAssertEqual(s.cationSub, 1)
        XCTAssertEqual(s.anionSub, 2)
    }
    func test_crossover_reduces_al2o3_not_needed_but_ca_o() {
        let s = crossoverSubscripts(cationCharge: 2, anionCharge: -2)
        XCTAssertEqual(s.cationSub, 1)
        XCTAssertEqual(s.anionSub, 1)
    }
    func test_binaryFormula_simple() {
        XCTAssertEqual(binaryFormula(first: "H", firstCount: 2, second: "O", secondCount: 1, secondIsPolyatomic: false), "H₂O")
    }
    func test_binaryFormula_polyatomic_parenthesised() {
        XCTAssertEqual(binaryFormula(first: "NH₄", firstCount: 2, second: "SO₄", secondCount: 1, secondIsPolyatomic: true), "(NH₄)₂SO₄")
    }
    func test_binaryFormula_polyatomic_single_no_parens() {
        XCTAssertEqual(binaryFormula(first: "Na", firstCount: 1, second: "OH", secondCount: 1, secondIsPolyatomic: true), "NaOH")
    }
}
