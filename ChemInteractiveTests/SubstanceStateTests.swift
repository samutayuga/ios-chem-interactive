import XCTest
import ChemCore
@testable import ChemInteractive

final class SubstanceStateTests: XCTestCase {
    private func zone(_ z: Int) throws -> ZoneState {
        let pt = try PeriodicTable.load()
        return ZoneState(element: try XCTUnwrap(pt.elements.first { $0.atomicNumber == z }))
    }
    private var elements: [Element] { (try? PeriodicTable.load().elements) ?? [] }

    func test_solidElement() throws {
        XCTAssertEqual(resolveSubstanceState(for: try zone(26), elements: elements), .solid)   // Fe
    }
    func test_gasElement() throws {
        XCTAssertEqual(resolveSubstanceState(for: try zone(8), elements: elements), .gas)       // O
    }
    func test_liquidElement() throws {
        XCTAssertEqual(resolveSubstanceState(for: try zone(80), elements: elements), .liquid)   // Hg
    }
    func test_polyatomicIsAqueous() {
        let oh = ZoneState(polyatomic: PolyatomicIon(symbol: "OH", name: "Hydroxide", charge: -1, formula: "OH⁻"))
        XCTAssertEqual(resolveSubstanceState(for: oh, elements: elements), .aqueous)
    }
    func test_unknownSymbolFallsBackToLiquid() {
        let xx = ZoneState(symbol: "Xx", elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                           valenceElectrons: 0, oxidationStates: [])
        XCTAssertEqual(resolveSubstanceState(for: xx, elements: elements), .liquid)
    }
}
