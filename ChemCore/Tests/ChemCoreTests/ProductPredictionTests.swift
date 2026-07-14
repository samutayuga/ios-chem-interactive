import XCTest
@testable import ChemCore

private func el(_ sym: String, mass: Double, _ cls: ElementClass, charge: Int? = nil,
                ve: Int = 0, group: Int = 0, period: Int = 0) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: cls,
            isPolyatomic: false, valenceElectrons: ve, group: group, period: period,
            composition: [sym: 1])
}
private func polyIon(_ sym: String, mass: Double, charge: Int, comp: [String: Int]) -> Species {
    Species(symbol: sym, atomicMass: mass, charge: charge, elementClass: .nonMetal,
            isPolyatomic: true, valenceElectrons: 0, group: 0, period: 0, composition: comp)
}
private func formulas(_ p: Prediction) -> [String] {
    if case let .products(list) = p { return list.map(\.formula).sorted() }
    return []
}

final class ProductPredictionTests: XCTestCase {
    func test_neutralisation_to_water() {
        let naoh = makeReactant([el("Na", mass: 23, .metal, charge: 1),
                                 polyIon("OH", mass: 17, charge: -1, comp: ["O": 1, "H": 1])])
        let hcl = makeReactant([el("H", mass: 1, .nonMetal, charge: 1),
                                el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        XCTAssertEqual(formulas(predictProducts(.doubleDisplacement, naoh, hcl)),
                       ["H₂O", "NaCl"].sorted())
    }
    func test_carbonate_gives_co2_and_water() {
        let na2co3 = makeReactant([el("Na", mass: 23, .metal, charge: 1),
                                   polyIon("CO₃", mass: 60, charge: -2, comp: ["C": 1, "O": 3])])
        let hcl = makeReactant([el("H", mass: 1, .nonMetal, charge: 1),
                               el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        XCTAssertEqual(formulas(predictProducts(.doubleDisplacement, na2co3, hcl)),
                       ["CO₂", "H₂O", "NaCl"].sorted())
    }
    func test_single_displacement_feasible() {
        let zn = makeReactant([el("Zn", mass: 65.38, .metal, charge: 2)])
        let cuso4 = makeReactant([el("Cu", mass: 63.55, .metal, charge: 2),
                                  polyIon("SO₄", mass: 96.06, charge: -2, comp: ["S": 1, "O": 4])])
        XCTAssertEqual(formulas(predictProducts(.singleDisplacement, zn, cuso4)),
                       ["Cu", "ZnSO₄"].sorted())
    }
    func test_single_displacement_infeasible() {
        let cu = makeReactant([el("Cu", mass: 63.55, .metal, charge: 2)])
        let znso4 = makeReactant([el("Zn", mass: 65.38, .metal, charge: 2),
                                  polyIon("SO₄", mass: 96.06, charge: -2, comp: ["S": 1, "O": 4])])
        if case let .infeasible(reason) = predictProducts(.singleDisplacement, cu, znso4) {
            XCTAssertTrue(reason.contains("activity series"))
        } else {
            XCTFail("expected infeasible")
        }
    }
    func test_combustion_hydrocarbon() {
        let ch4 = makeReactant([el("C", mass: 12, .nonMetal, ve: 4, group: 14, period: 2),
                                el("H", mass: 1, .nonMetal, ve: 1, group: 1, period: 1)])
        let o2 = makeReactant([el("O", mass: 16, .nonMetal, charge: -2)])
        XCTAssertEqual(formulas(predictProducts(.combustion, ch4, o2)),
                       ["CO₂", "H₂O"].sorted())
    }
    func test_halogen_displacement_frees_diatomic() {
        let cl2 = makeReactant([el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        let kbr = makeReactant([el("K", mass: 39.1, .metal, charge: 1),
                                el("Br", mass: 79.9, .nonMetal, charge: -1)])
        XCTAssertEqual(formulas(predictProducts(.singleDisplacement, cl2, kbr)),
                       ["Br₂", "KCl"].sorted())
    }
    func test_metal_displaces_hydrogen_as_h2() {
        let zn = makeReactant([el("Zn", mass: 65.38, .metal, charge: 2)])
        let hcl = makeReactant([el("H", mass: 1.008, .nonMetal, charge: 1),
                                el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        XCTAssertEqual(formulas(predictProducts(.singleDisplacement, zn, hcl)),
                       ["H₂", "ZnCl₂"].sorted())
    }
    func test_bare_element_combustion_makes_correct_oxide() {
        let mg = makeReactant([el("Mg", mass: 24.3, .metal, charge: 2)])
        let o2 = makeReactant([el("O", mass: 16, .nonMetal, charge: -2)])
        XCTAssertEqual(formulas(predictProducts(.combustion, mg, o2)),
                       ["MgO"])

        let al = makeReactant([el("Al", mass: 27, .metal, charge: 3)])
        XCTAssertEqual(formulas(predictProducts(.combustion, al, o2)),
                       ["Al₂O₃"])
    }
}
