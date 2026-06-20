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
        // 1:2 ratio (distinct from the 1:1 and 2:3 cases above).
        let mgcl2 = lewisTransfer(cation: ion("Mg", .metal, ve: 2, charge: 2),
                                  anion: ion("Cl", .nonMetal, ve: 7, charge: -1))
        XCTAssertEqual(mgcl2.cCount, 1)
        XCTAssertEqual(mgcl2.aCount, 2)
        XCTAssertEqual(mgcl2.eMoved, 2)
        XCTAssertEqual(mgcl2.anionAfterDots, 8)       // min(7 + 1, 8)
    }

    func test_dotPositions_count() {
        XCTAssertEqual(dotPositions(3).count, 3)
        XCTAssertEqual(dotPositions(10).count, 8)     // capped at 8
        XCTAssertEqual(dotPositions(0).count, 0)
        XCTAssertEqual(dotPositions(1).first?.dx, 22) // first slot = right
    }
}

final class CovalentMetallicLayoutTests: XCTestCase {
    private func atom(_ symbol: String, ve: Int) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                  valenceElectrons: ve, oxidationStates: [], derivedCharge: nil, status: .neutral)
    }
    private func metal(_ symbol: String, ve: Int) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: .metal, isPolyatomic: false, isTransition: false,
                  valenceElectrons: ve, oxidationStates: [], derivedCharge: nil, status: .neutral)
    }

    func test_covalent_CO2() {
        let l = covalentLayout(slotA: atom("C", ve: 4), slotB: atom("O", ve: 6))
        XCTAssertTrue(l.centralIsA)          // C is central
        XCTAssertEqual(l.nPeripheral, 2)
        XCTAssertEqual(l.bondOrder, 2)
        XCTAssertEqual(l.centralLone, 0)
        XCTAssertEqual(l.peripheralLone, 2)
    }

    func test_covalent_H2O() {
        let l = covalentLayout(slotA: atom("H", ve: 1), slotB: atom("O", ve: 6))
        XCTAssertFalse(l.centralIsA)         // O is central
        XCTAssertEqual(l.nPeripheral, 2)     // 2 H
        XCTAssertEqual(l.bondOrder, 1)
        XCTAssertEqual(l.centralLone, 2)
        XCTAssertEqual(l.peripheralLone, 0)
    }

    func test_covalent_N2_triple() {
        let l = covalentLayout(slotA: atom("N", ve: 5), slotB: atom("N", ve: 5))
        XCTAssertEqual(l.nPeripheral, 1)
        XCTAssertEqual(l.bondOrder, 3)
        XCTAssertEqual(l.centralLone, 1)
        XCTAssertEqual(l.peripheralLone, 1)
    }

    func test_peripheralPositions_counts() {
        let c = CGPoint(x: 100, y: 100)
        XCTAssertEqual(peripheralPositions(1, center: c, distance: 50).count, 1)
        XCTAssertEqual(peripheralPositions(2, center: c, distance: 50).count, 2)
        XCTAssertEqual(peripheralPositions(3, center: c, distance: 50).count, 3)
        XCTAssertEqual(peripheralPositions(4, center: c, distance: 50).count, 4)
        XCTAssertEqual(peripheralPositions(5, center: c, distance: 50).count, 1) // 5+ simplified
    }

    func test_lonePairAngles_avoidsBond() {
        let angles = lonePairAngles(bondAngles: [0], count: 2)
        XCTAssertEqual(angles.count, 2)
        // None coincides with the bond direction (0); the farthest slot (π) is chosen.
        XCTAssertFalse(angles.contains { abs($0) < 0.01 })
        XCTAssertTrue(angles.contains { abs($0 - Double.pi) < 0.01 })
    }

    func test_metallic_electronCount_andPattern() {
        XCTAssertEqual(metallicElectronsShown(slotA: metal("Na", ve: 1), slotB: metal("Na", ve: 1)), 6)
        XCTAssertEqual(metallicElectronsShown(slotA: metal("Al", ve: 3), slotB: metal("Al", ve: 3)), 12) // capped
        XCTAssertEqual(metallicIonIndexPattern, [0, 1, 0, 1, 0, 1])
    }
}
