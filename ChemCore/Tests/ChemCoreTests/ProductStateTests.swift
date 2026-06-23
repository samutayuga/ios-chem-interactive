import XCTest
@testable import ChemCore

final class ProductStateTests: XCTestCase {
    private func atom(_ symbol: String, _ cls: ElementClass, _ state: StateOfMatter) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: cls, isPolyatomic: false, isTransition: false,
                  valenceElectrons: 0, oxidationStates: [], stateOfMatter: state)
    }

    func test_ionic_isSolid() {
        // NaCl and every salt: ionic lattice → solid.
        let na = atom("Na", .metal, .solid)
        let cl = atom("Cl", .nonMetal, .gas)
        XCTAssertEqual(predictProductState(bonding: .ionic, a: na, b: cl), .solid)
    }

    func test_metallic_isSolid() {
        let na = atom("Na", .metal, .solid)
        let mg = atom("Mg", .metal, .solid)
        XCTAssertEqual(predictProductState(bonding: .metallic, a: na, b: mg), .solid)
    }

    func test_covalent_anyGasConstituent_isGas() {
        // CO₂: C solid + O gas → gas. SO₂: S solid + O gas → gas.
        let c = atom("C", .nonMetal, .solid)
        let o = atom("O", .nonMetal, .gas)
        XCTAssertEqual(predictProductState(bonding: .covalent, a: c, b: o), .gas)
        let s = atom("S", .nonMetal, .solid)
        XCTAssertEqual(predictProductState(bonding: .covalent, a: s, b: o), .gas)
    }

    func test_covalent_bothGas_isGas() {
        // O₂, N₂: both gas → gas.
        let o = atom("O", .nonMetal, .gas)
        XCTAssertEqual(predictProductState(bonding: .covalent, a: o, b: o), .gas)
    }

    func test_covalent_water_specialCasedLiquid() {
        // H + O would predict gas (both light), but H₂O is liquid at STP.
        let h = atom("H", .nonMetal, .gas)
        let o = atom("O", .nonMetal, .gas)
        XCTAssertEqual(predictProductState(bonding: .covalent, a: h, b: o), .liquid)
        XCTAssertEqual(predictProductState(bonding: .covalent, a: o, b: h), .liquid)
    }

    func test_covalent_liquidConstituent_isLiquid() {
        // Br (liquid) + a solid nonmetal, no gas → liquid.
        let br = atom("Br", .nonMetal, .liquid)
        let i = atom("I", .nonMetal, .solid)
        XCTAssertEqual(predictProductState(bonding: .covalent, a: br, b: i), .liquid)
    }

    func test_covalent_allSolid_isSolid() {
        // Two solid nonmetals, no gas/liquid → solid (e.g. Si + C heuristic).
        let si = atom("Si", .metalloid, .solid)
        let c = atom("C", .nonMetal, .solid)
        XCTAssertEqual(predictProductState(bonding: .covalent, a: si, b: c), .solid)
    }
}
