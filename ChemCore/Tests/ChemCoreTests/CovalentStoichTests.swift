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
