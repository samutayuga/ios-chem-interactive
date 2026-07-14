// ChemCore/Tests/ChemCoreTests/ReactionClassTests.swift
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

final class ReactionClassTests: XCTestCase {
    func test_combustion_methane_and_o2() {
        let ch4 = makeReactant([el("C", mass: 12, .nonMetal, ve: 4, group: 14, period: 2),
                                el("H", mass: 1, .nonMetal, ve: 1, group: 1, period: 1)])
        let o2 = makeReactant([el("O", mass: 16, .nonMetal, charge: -2)])
        XCTAssertEqual(classifyReaction(ch4, o2), .combustion)
    }
    func test_single_displacement_zn_and_cuso4() {
        let zn = makeReactant([el("Zn", mass: 65.38, .metal, charge: 2)])
        let cuso4 = makeReactant([el("Cu", mass: 63.55, .metal, charge: 2),
                                  polyIon("SO₄", mass: 96.06, charge: -2, comp: ["S": 1, "O": 4])])
        XCTAssertEqual(classifyReaction(zn, cuso4), .singleDisplacement)
    }
    func test_double_displacement_naoh_and_hcl() {
        let naoh = makeReactant([el("Na", mass: 23, .metal, charge: 1),
                                 polyIon("OH", mass: 17, charge: -1, comp: ["O": 1, "H": 1])])
        let hcl = makeReactant([el("H", mass: 1, .nonMetal, charge: 1),
                                el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        XCTAssertEqual(classifyReaction(naoh, hcl), .doubleDisplacement)
    }
    func test_synthesis_two_bare_elements() {
        let na = makeReactant([el("Na", mass: 23, .metal, charge: 1)])
        let cl = makeReactant([el("Cl", mass: 35.45, .nonMetal, charge: -1)])
        XCTAssertEqual(classifyReaction(na, cl), .synthesis)
    }
    func test_metal_plus_o2_is_synthesis_not_combustion() {
        // A bare metal + O₂ is direct combination (oxidation), not combustion.
        let fe = makeReactant([el("Fe", mass: 55.85, .metal, charge: 2)])
        let o2 = makeReactant([el("O", mass: 16, .nonMetal, charge: -2)])
        XCTAssertEqual(classifyReaction(fe, o2), .synthesis)
    }
}
