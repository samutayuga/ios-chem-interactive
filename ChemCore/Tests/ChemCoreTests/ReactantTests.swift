import XCTest
@testable import ChemCore

private func element(_ sym: String, mass: Double, _ cls: ElementClass,
                     charge: Int? = nil, ve: Int = 0, group: Int = 0, period: Int = 0) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: cls,
            isPolyatomic: false, valenceElectrons: ve, group: group, period: period,
            composition: [sym: 1])
}
private func poly(_ sym: String, mass: Double, charge: Int, comp: [String: Int]) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: .nonMetal,
            isPolyatomic: true, valenceElectrons: 0, group: 0, period: 0, composition: comp)
}

final class ReactantTests: XCTestCase {
    func test_bare_metal() {
        let r = makeReactant([element("Zn", mass: 65.38, .metal, charge: 2)])
        XCTAssertTrue(r.isBareElement)
        XCTAssertEqual(r.formula, "Zn")
        XCTAssertEqual(r.composition, ["Zn": 1])
    }
    func test_bare_diatomic() {
        let r = makeReactant([element("O", mass: 16.0, .nonMetal, charge: -2)])
        XCTAssertEqual(r.formula, "O₂")
        XCTAssertEqual(r.composition, ["O": 2])
        XCTAssertEqual(r.molarMass, 32.0, accuracy: 1e-6)
    }
    func test_ionic_nacl() {
        let na = element("Na", mass: 23.0, .metal, charge: 1)
        let cl = element("Cl", mass: 35.45, .nonMetal, charge: -1)
        let r = makeReactant([na, cl])
        XCTAssertEqual(r.formula, "NaCl")
        XCTAssertEqual(r.composition, ["Na": 1, "Cl": 1])
        XCTAssertEqual(r.cation?.symbol, "Na")
        XCTAssertEqual(r.anion?.symbol, "Cl")
        XCTAssertFalse(r.isBareElement)
    }
    func test_ionic_with_polyatomic_sulfate() {
        let na = element("Na", mass: 23.0, .metal, charge: 1)
        let so4 = poly("SO₄", mass: 96.06, charge: -2, comp: ["S": 1, "O": 4])
        let r = makeReactant([na, so4])
        XCTAssertEqual(r.formula, "Na₂SO₄")
        XCTAssertEqual(r.composition, ["Na": 2, "S": 1, "O": 4])
        XCTAssertEqual(r.molarMass, 2 * 23.0 + 96.06, accuracy: 1e-6)
    }
    func test_covalent_methane() {
        let c = element("C", mass: 12.011, .nonMetal, ve: 4, group: 14, period: 2)
        let h = element("H", mass: 1.008, .nonMetal, ve: 1, group: 1, period: 1)
        let r = makeReactant([c, h])
        XCTAssertEqual(r.composition, ["C": 1, "H": 4])
        XCTAssertNil(r.cation)
    }
}
