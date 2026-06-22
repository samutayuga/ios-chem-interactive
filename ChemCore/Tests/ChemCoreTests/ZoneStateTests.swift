import XCTest
@testable import ChemCore

final class ZoneStateTests: XCTestCase {
    func test_slotOther() {
        XCTAssertEqual(Slot.a.other, .b)
        XCTAssertEqual(Slot.b.other, .a)
    }
    func test_zoneFromElement_iron_isTransition() throws {
        let pt = try PeriodicTable.load()
        let fe = try XCTUnwrap(pt.bySymbol("Fe"))
        let zone = ZoneState(element: fe)
        XCTAssertEqual(zone.symbol, "Fe")
        XCTAssertEqual(zone.elementClass, .metal)
        XCTAssertFalse(zone.isPolyatomic)
        XCTAssertTrue(zone.isTransition)           // D-block -> picker eligible
        XCTAssertEqual(zone.valenceElectrons, 2)
        XCTAssertEqual(zone.oxidationStates, [2, 3])
        XCTAssertEqual(zone.status, .neutral)
    }
    func test_zoneFromElement_sodium_notTransition() throws {
        let pt = try PeriodicTable.load()
        let na = try XCTUnwrap(pt.bySymbol("Na"))
        let zone = ZoneState(element: na)
        XCTAssertFalse(zone.isTransition)
        XCTAssertEqual(zone.valenceElectrons, 1)
    }
    func test_polyatomicIons() {
        XCTAssertEqual(PolyatomicIon.polyatomicIons.count, 6)
        let sulfate = PolyatomicIon.polyatomicIons.first { $0.symbol == "SO₄" }
        XCTAssertEqual(sulfate?.charge, -2)
        let zone = ZoneState(polyatomic: PolyatomicIon.polyatomicIons[0])
        XCTAssertTrue(zone.isPolyatomic)
        XCTAssertEqual(zone.elementClass, .nonMetal)
        XCTAssertEqual(zone.valenceElectrons, 0)
    }
    func test_zoneFromElement_carriesGroupAndPeriod() throws {
        let pt = try PeriodicTable.load()
        let s = try XCTUnwrap(pt.bySymbol("S"))
        let zone = ZoneState(element: s)
        XCTAssertEqual(zone.group, 16)
        XCTAssertEqual(zone.period, 3)
    }
    func test_zoneFromElement_oxygen_period2() throws {
        let pt = try PeriodicTable.load()
        let o = try XCTUnwrap(pt.bySymbol("O"))
        let zone = ZoneState(element: o)
        XCTAssertEqual(zone.group, 16)
        XCTAssertEqual(zone.period, 2)
    }
}
