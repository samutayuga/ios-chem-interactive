import XCTest
import ChemCore
@testable import ChemInteractive

final class CompoundNameTests: XCTestCase {
    private var elements: [Element] { (try? PeriodicTable.load().elements) ?? [] }
    private var ions: [PolyatomicIon] { PolyatomicIon.polyatomicIons }

    private func ion(_ symbol: String, _ cls: ElementClass, ve: Int, charge: Int,
                     transition: Bool = false, oxStates: [Int]? = nil, poly: Bool = false,
                     group: Int = 0, period: Int = 0) -> ZoneState {
        ZoneState(symbol: symbol, elementClass: cls, isPolyatomic: poly, isTransition: transition,
                  valenceElectrons: ve, oxidationStates: oxStates ?? [charge],
                  derivedCharge: charge, status: .ionized, group: group, period: period)
    }

    func test_ionic_fixedCharge() {
        let na = ion("Na", .metal, ve: 1, charge: 1)
        let cl = ion("Cl", .nonMetal, ve: 7, charge: -1)
        XCTAssertEqual(ionicCompoundName(cation: na, anion: cl, elements: elements, ions: ions),
                       "Sodium chloride")
    }

    func test_ionic_variableChargeRomanNumeral() {
        let fe = ion("Fe", .metal, ve: 2, charge: 3, transition: true, oxStates: [2, 3])
        let o = ion("O", .nonMetal, ve: 6, charge: -2)
        XCTAssertEqual(ionicCompoundName(cation: fe, anion: o, elements: elements, ions: ions),
                       "Iron(III) oxide")
    }

    func test_ionic_polyatomicAnion() {
        let na = ion("Na", .metal, ve: 1, charge: 1)
        let oh = ion("OH", .nonMetal, ve: 0, charge: -1, poly: true)
        XCTAssertEqual(ionicCompoundName(cation: na, anion: oh, elements: elements, ions: ions),
                       "Sodium hydroxide")
    }

    func test_ionic_polyatomicCation() {
        let nh4 = ion("NH₄", .metal, ve: 0, charge: 1, poly: true)
        let cl = ion("Cl", .nonMetal, ve: 7, charge: -1)
        XCTAssertEqual(ionicCompoundName(cation: nh4, anion: cl, elements: elements, ions: ions),
                       "Ammonium chloride")
    }

    func test_covalentName_prefixesAndElision() {
        XCTAssertEqual(covalentName(firstSymbol: "C", firstCount: 1, secondSymbol: "O", secondCount: 2, elements: elements),
                       "Carbon dioxide")
        XCTAssertEqual(covalentName(firstSymbol: "C", firstCount: 1, secondSymbol: "O", secondCount: 1, elements: elements),
                       "Carbon monoxide")
        XCTAssertEqual(covalentName(firstSymbol: "N", firstCount: 2, secondSymbol: "O", secondCount: 4, elements: elements),
                       "Dinitrogen tetroxide")
        XCTAssertEqual(covalentName(firstSymbol: "N", firstCount: 2, secondSymbol: "O", secondCount: 1, elements: elements),
                       "Dinitrogen monoxide")
    }

    func test_covalentCompound_homonuclear() {
        let n = ion("N", .nonMetal, ve: 5, charge: 0)
        XCTAssertEqual(covalentCompoundName(slotA: n, slotB: n, elements: elements), "Nitrogen")
    }

    func test_covalentCompound_integratesStoich() {
        let c = ion("C", .nonMetal, ve: 4, charge: 0)
        let o = ion("O", .nonMetal, ve: 6, charge: 0)
        // calcStoich(C,O) → CO₂; iupacFirst puts C first.
        XCTAssertEqual(covalentCompoundName(slotA: c, slotB: o, elements: elements), "Carbon dioxide")
    }

    func test_covalentCompound_orbitalMismatch_SO2() {
        let s = ion("S", .nonMetal, ve: 6, charge: 0, group: 16, period: 3)
        let o = ion("O", .nonMetal, ve: 6, charge: 0, group: 16, period: 2)
        XCTAssertEqual(covalentCompoundName(slotA: s, slotB: o, elements: elements), "Sulfur dioxide")
    }
}
