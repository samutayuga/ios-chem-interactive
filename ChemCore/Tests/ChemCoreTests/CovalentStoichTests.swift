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
    func test_covalentStoich_SO2_centralSulfur() {
        // S (group 16, period 3) + O (group 16, period 2) → S central ×1, O ×2, double bond.
        let s = covalentStoich(veA: 6, groupA: 16, periodA: 3, veB: 6, groupB: 16, periodB: 2)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 2); XCTAssertEqual(s.bondOrder, 2)
    }
    func test_covalentStoich_SO2_slotOrderIndependent() {
        // O in slot A, S in slot B → still SO₂ (S central, count 1).
        let s = covalentStoich(veA: 6, groupA: 16, periodA: 2, veB: 6, groupB: 16, periodB: 3)
        XCTAssertEqual(s.nA, 2); XCTAssertEqual(s.nB, 1); XCTAssertEqual(s.bondOrder, 2)
    }
    func test_covalentStoich_SeS2() {
        // Se (period 4) central, S (period 3) ×2.
        let s = covalentStoich(veA: 6, groupA: 16, periodA: 4, veB: 6, groupB: 16, periodB: 3)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 2); XCTAssertEqual(s.bondOrder, 2)
    }
    func test_covalentStoich_O2_samePeriod_unchanged() {
        // O + O: same group AND same period → rule off → octet 1:1 double bond.
        let s = covalentStoich(veA: 6, groupA: 16, periodA: 2, veB: 6, groupB: 16, periodB: 2)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 1); XCTAssertEqual(s.bondOrder, 2)
    }
    func test_covalentStoich_ClF_singleBond_unchanged() {
        // Group 17, different periods → octet gives single bond (not double) → rule off.
        let s = covalentStoich(veA: 7, groupA: 17, periodA: 3, veB: 7, groupB: 17, periodB: 2)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 1); XCTAssertEqual(s.bondOrder, 1)
    }
    func test_covalentStoich_NP_tripleBond_unchanged() {
        // Group 15, different periods → octet gives triple (not double) → rule off.
        let s = covalentStoich(veA: 5, groupA: 15, periodA: 3, veB: 5, groupB: 15, periodB: 2)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 1); XCTAssertEqual(s.bondOrder, 3)
    }
    func test_covalentStoich_differentGroup_unchanged() {
        // C (group 14) + O (group 16) → different group → octet CO₂.
        let s = covalentStoich(veA: 4, groupA: 14, periodA: 2, veB: 6, groupB: 16, periodB: 2)
        XCTAssertEqual(s.nA, 1); XCTAssertEqual(s.nB, 2); XCTAssertEqual(s.bondOrder, 2)
    }
    func test_isOrbitalMismatchDoubleBond_truthTable() {
        XCTAssertTrue(isOrbitalMismatchDoubleBond(groupA: 16, periodA: 3, veA: 6,
                                                  groupB: 16, periodB: 2, veB: 6))   // S+O
        XCTAssertFalse(isOrbitalMismatchDoubleBond(groupA: 16, periodA: 2, veA: 6,
                                                   groupB: 16, periodB: 2, veB: 6))  // O+O same period
        XCTAssertFalse(isOrbitalMismatchDoubleBond(groupA: 17, periodA: 3, veA: 7,
                                                   groupB: 17, periodB: 2, veB: 7))  // halogens single
        XCTAssertFalse(isOrbitalMismatchDoubleBond(groupA: 14, periodA: 2, veA: 4,
                                                   groupB: 16, periodB: 2, veB: 6))  // different group
    }
}
