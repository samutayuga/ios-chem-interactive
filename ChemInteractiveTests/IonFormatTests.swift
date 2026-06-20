import XCTest
import ChemCore
@testable import ChemInteractive

final class IonFormatTests: XCTestCase {
    func test_superscript() {
        XCTAssertEqual(superscript(1), "¹")
        XCTAssertEqual(superscript(3), "³")
        XCTAssertEqual(superscript(9), "9")
    }

    func test_subscriptGlyphs() {
        XCTAssertEqual(subscriptGlyphs(2), "₂")
        XCTAssertEqual(subscriptGlyphs(10), "₁₀")
    }

    func test_formatIon() {
        XCTAssertEqual(formatIon(symbol: "Na", charge: 1), "Na⁺")
        XCTAssertEqual(formatIon(symbol: "Mg", charge: 2), "Mg²⁺")
        XCTAssertEqual(formatIon(symbol: "Cl", charge: -1), "Cl⁻")
        XCTAssertEqual(formatIon(symbol: "O", charge: -2), "O²⁻")
    }

    func test_electronsNeeded() {
        XCTAssertEqual(electronsNeeded(1), 1)   // H
        XCTAssertEqual(electronsNeeded(6), 2)   // O
        XCTAssertEqual(electronsNeeded(7), 1)   // F/Cl
    }

    func test_ionicFormula() {
        // NaCl: 1+/1- → NaCl
        XCTAssertEqual(ionicFormula(cationSymbol: "Na", cationCharge: 1, anionSymbol: "Cl", anionCharge: -1, anionIsPolyatomic: false), "NaCl")
        // MgCl2: 2+/1- → MgCl₂
        XCTAssertEqual(ionicFormula(cationSymbol: "Mg", cationCharge: 2, anionSymbol: "Cl", anionCharge: -1, anionIsPolyatomic: false), "MgCl₂")
        // Al2O3: 3+/2- → Al₂O₃
        XCTAssertEqual(ionicFormula(cationSymbol: "Al", cationCharge: 3, anionSymbol: "O", anionCharge: -2, anionIsPolyatomic: false), "Al₂O₃")
        // Ca(OH)2: 2+/1- polyatomic → Ca(OH)₂
        XCTAssertEqual(ionicFormula(cationSymbol: "Ca", cationCharge: 2, anionSymbol: "OH", anionCharge: -1, anionIsPolyatomic: true), "Ca(OH)₂")
        // Na with polyatomic subscript 1 → no parens: NaOH
        XCTAssertEqual(ionicFormula(cationSymbol: "Na", cationCharge: 1, anionSymbol: "OH", anionCharge: -1, anionIsPolyatomic: true), "NaOH")
    }

    func test_chargeExplanation_metal() {
        let na = ZoneState(symbol: "Na", elementClass: .metal, isPolyatomic: false, isTransition: false,
                           valenceElectrons: 1, oxidationStates: [1], derivedCharge: 1, status: .ionized)
        XCTAssertEqual(chargeExplanation(na), "Na has 1 valence electron → loses 1e⁻ → Na⁺")
    }

    func test_chargeExplanation_nonmetal() {
        let o = ZoneState(symbol: "O", elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                          valenceElectrons: 6, oxidationStates: [-2], derivedCharge: -2, status: .ionized)
        XCTAssertEqual(chargeExplanation(o), "O has 6 valence electrons → gains 2e⁻ → O²⁻")
    }

    func test_chargeExplanation_polyatomic() {
        let oh = ZoneState(symbol: "OH", elementClass: .nonMetal, isPolyatomic: true, isTransition: false,
                           valenceElectrons: 0, oxidationStates: [-1], derivedCharge: -1, status: .ionized)
        XCTAssertEqual(chargeExplanation(oh), "OH is a polyatomic ion with a fixed charge of -1")
    }

    func test_chargeExplanation_metalloid() {
        let b = ZoneState(symbol: "B", elementClass: .metalloid, isPolyatomic: false, isTransition: false,
                          valenceElectrons: 3, oxidationStates: [3], derivedCharge: 3, status: .ionized)
        XCTAssertEqual(chargeExplanation(b), "B has 3 valence electrons → loses 3e⁻ → B³⁺")
    }
}
