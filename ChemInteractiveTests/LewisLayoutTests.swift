import XCTest
import ChemCore
@testable import ChemInteractive

final class LewisLayoutTests: XCTestCase {
    // Helpers to build ionized cation/anion zones.
    private func ion(_ symbol: String, _ cls: ElementClass, ve: Int, charge: Int, poly: Bool = false) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: cls, isPolyatomic: poly, isTransition: false,
                  valenceElectrons: ve, oxidationStates: [charge], derivedCharge: charge, status: .ionized)
    }

    func test_ionicPair_byChargeSign() {
        let na = ion("Na", .metal, ve: 1, charge: 1)
        let cl = ion("Cl", .nonMetal, ve: 7, charge: -1)
        let p = ionicPair(cl, na)            // pass anion first
        XCTAssertEqual(p.cation.symbol, "Na")
        XCTAssertEqual(p.anion.symbol, "Cl")
    }

    func test_crossover_NaCl_noBracketsNoGcd() {
        let m = crossoverModel(cation: ion("Na", .metal, ve: 1, charge: 1),
                               anion: ion("Cl", .nonMetal, ve: 7, charge: -1))
        XCTAssertEqual(m.cationSub, 1)
        XCTAssertEqual(m.anionSub, 1)
        XCTAssertFalse(m.showBrackets)
        XCTAssertFalse(m.showGcd)
        XCTAssertEqual(m.steps, [.isolate, .crisscross, .done])
    }

    func test_crossover_MgCl2_AndAl2O3_subscripts() {
        let mg = crossoverModel(cation: ion("Mg", .metal, ve: 2, charge: 2),
                                anion: ion("Cl", .nonMetal, ve: 7, charge: -1))
        XCTAssertEqual([mg.cationSub, mg.anionSub], [1, 2])
        let al = crossoverModel(cation: ion("Al", .metal, ve: 3, charge: 3),
                                anion: ion("O", .nonMetal, ve: 6, charge: -2))
        XCTAssertEqual([al.cationSub, al.anionSub], [2, 3])
    }

    func test_crossover_CaCO3_showsGcd() {
        let m = crossoverModel(cation: ion("Ca", .metal, ve: 2, charge: 2),
                               anion: ion("CO₃", .nonMetal, ve: 0, charge: -2, poly: true))
        XCTAssertEqual([m.cationSub, m.anionSub], [1, 1])
        XCTAssertTrue(m.showGcd)
        XCTAssertFalse(m.showBrackets)
        XCTAssertEqual(m.steps, [.isolate, .crisscross, .gcdReduce, .done])
    }

    func test_crossover_MgOH2_showsBrackets() {
        let m = crossoverModel(cation: ion("Mg", .metal, ve: 2, charge: 2),
                               anion: ion("OH", .nonMetal, ve: 0, charge: -1, poly: true))
        XCTAssertEqual([m.cationSub, m.anionSub], [1, 2])
        XCTAssertTrue(m.showBrackets)
        XCTAssertFalse(m.showGcd)
        XCTAssertEqual(m.steps, [.isolate, .crisscross, .brackets, .done])
    }

    func test_lewisTransfer_NaCl_andAl2O3() {
        let nacl = lewisTransfer(cation: ion("Na", .metal, ve: 1, charge: 1),
                                 anion: ion("Cl", .nonMetal, ve: 7, charge: -1))
        XCTAssertEqual(nacl.cCount, 1)
        XCTAssertEqual(nacl.aCount, 1)
        XCTAssertEqual(nacl.eMoved, 1)
        XCTAssertEqual(nacl.anionAfterDots, 8)        // min(7 + 1, 8)
        let al2o3 = lewisTransfer(cation: ion("Al", .metal, ve: 3, charge: 3),
                                  anion: ion("O", .nonMetal, ve: 6, charge: -2))
        XCTAssertEqual(al2o3.cCount, 2)
        XCTAssertEqual(al2o3.aCount, 3)
        XCTAssertEqual(al2o3.eMoved, 3)
        XCTAssertEqual(al2o3.anionAfterDots, 8)       // min(6 + 2, 8)
    }

    func test_dotPositions_count() {
        XCTAssertEqual(dotPositions(3).count, 3)
        XCTAssertEqual(dotPositions(10).count, 8)     // capped at 8
        XCTAssertEqual(dotPositions(0).count, 0)
        XCTAssertEqual(dotPositions(1).first?.dx, 22) // first slot = right
    }
}
