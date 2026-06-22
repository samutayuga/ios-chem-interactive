import XCTest
import ChemCore
@testable import ChemInteractive

final class BondingExplanationTests: XCTestCase {
    private func z(_ symbol: String, _ cls: ElementClass, ve: Int, charge: Int? = nil,
                   status: ZoneStatus = .neutral, poly: Bool = false,
                   group: Int = 0, period: Int = 0) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: cls, isPolyatomic: poly, isTransition: false,
                  valenceElectrons: ve, oxidationStates: charge.map { [$0] } ?? [],
                  derivedCharge: charge, status: status, group: group, period: period)
    }

    func test_ionicExplanation_containsCrossoverFormula() {
        let na = z("Na", .metal, ve: 1, charge: 1, status: .ionized)
        let cl = z("Cl", .nonMetal, ve: 7, charge: -1, status: .ionized)
        let text = bondingExplanation(.ionic, na, cl)
        XCTAssertTrue(text.contains("NaCl"), text)
    }

    func test_metallicExplanation_mentionsElectronSea() {
        let na = z("Na", .metal, ve: 1)
        let text = bondingExplanation(.metallic, na, na)
        XCTAssertTrue(text.lowercased().contains("electron sea") || text.lowercased().contains("delocalised"), text)
    }

    func test_covalentPairSummary_matchesLayout() {
        let c = z("C", .nonMetal, ve: 4)
        let o = z("O", .nonMetal, ve: 6)
        let layout = covalentLayout(slotA: c, slotB: o)
        let summary = covalentPairSummary(c, o)
        XCTAssertTrue(summary.contains("\(layout.bondOrder) pair"), summary)
        XCTAssertTrue(summary.contains("\(layout.nPeripheral) bond"), summary)
    }

    func test_covalentExplanation_includesPairSummary() {
        let c = z("C", .nonMetal, ve: 4)
        let o = z("O", .nonMetal, ve: 6)
        let text = bondingExplanation(.covalent, c, o)
        XCTAssertTrue(text.contains("share"), text)
        XCTAssertTrue(text.contains("bond"), text)
    }

    func test_covalentExplanation_orbitalMismatchNote_SO2() {
        let s = z("S", .nonMetal, ve: 6, group: 16, period: 3)
        let o = z("O", .nonMetal, ve: 6, group: 16, period: 2)
        let text = bondingExplanation(.covalent, s, o)
        XCTAssertTrue(text.contains("Group 16"), text)
        XCTAssertTrue(text.contains("different periods"), text)
        XCTAssertTrue(text.contains("two O atoms"), text)
    }
    func test_covalentExplanation_noNote_whenRuleOff() {
        let c = z("C", .nonMetal, ve: 4, group: 14, period: 2)
        let o = z("O", .nonMetal, ve: 6, group: 16, period: 2)
        let text = bondingExplanation(.covalent, c, o)
        XCTAssertFalse(text.contains("orbitals differ"), text)
    }
}
