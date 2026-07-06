import XCTest
import ChemCore
@testable import ChemInteractive

final class SpeciesMappingTests: XCTestCase {
    private let elements = try! PeriodicTable.load().elements
    private let ions = PolyatomicIon.polyatomicIons

    private func el(_ symbol: String) -> ZoneState {
        ZoneState(element: elements.first { $0.symbol == symbol }!)
    }
    private func ion(_ symbol: String) -> ZoneState {
        ZoneState(polyatomic: ions.first { $0.symbol == symbol }!)
    }
    private func build(_ zones: [ZoneState]) -> Reactant? {
        SpeciesMapping.buildReactant(zones, elements: elements, ions: ions)
    }

    func test_bare_metal_carries_charge() {
        let r = build([el("Na")])
        XCTAssertEqual(r?.formula, "Na")
        XCTAssertEqual(r?.species.first?.charge, 1)
        XCTAssertTrue(r?.isBareElement == true)
    }
    func test_ionic_nacl() {
        let r = build([el("Na"), el("Cl")])
        XCTAssertEqual(r?.formula, "NaCl")
        XCTAssertEqual(r?.cation?.symbol, "Na")
        XCTAssertEqual(r?.anion?.symbol, "Cl")
    }
    func test_acid_hcl_is_ionic() {
        let r = build([el("H"), el("Cl")])
        XCTAssertEqual(r?.formula, "HCl")
        XCTAssertEqual(r?.cation?.symbol, "H")
        XCTAssertEqual(r?.anion?.symbol, "Cl")
    }
    func test_methane_is_covalent() {
        let r = build([el("C"), el("H")])
        XCTAssertEqual(r?.composition, ["C": 1, "H": 4])
        XCTAssertNil(r?.cation)     // covalent: no ionic pair
    }
    func test_ionic_with_polyatomic() {
        let r = build([el("Na"), ion("SO₄")])
        XCTAssertEqual(r?.formula, "Na₂SO₄")
        XCTAssertEqual(r?.composition, ["Na": 2, "S": 1, "O": 4])
    }
    func test_pending_transition_metal_returns_nil() {
        // Fe placed but no charge picked yet → cannot build.
        var fe = el("Fe")
        XCTAssertTrue(fe.isTransition)
        fe.derivedCharge = nil
        XCTAssertNil(build([fe, ion("SO₄")]))
    }
}
