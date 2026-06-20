import XCTest
@testable import ChemCore

final class PeriodicTableTests: XCTestCase {
    func test_loadsAll118() throws {
        let pt = try PeriodicTable.load()
        XCTAssertEqual(pt.elements.count, 118)
    }
    func test_ironDerivedFields() throws {
        let pt = try PeriodicTable.load()
        let fe = try XCTUnwrap(pt.bySymbol("Fe"))
        XCTAssertEqual(fe.group, 8)
        XCTAssertEqual(fe.period, 4)
        XCTAssertEqual(fe.block, .d)
        XCTAssertEqual(fe.category, .transitionMetal)
        XCTAssertEqual(fe.elementClass, .metal)
        XCTAssertEqual(fe.oxidationStates, [2, 3])
        XCTAssertEqual(fe.electronConfiguration, "1s2 2s2 2p6 3s2 3p6 3d6 4s2")
        XCTAssertEqual(try XCTUnwrap(fe.computedAtomicMass), 55.845, accuracy: 0.01)
    }
    func test_lookupByAtomicNumber() throws {
        let pt = try PeriodicTable.load()
        XCTAssertEqual(pt.byAtomicNumber(1)?.symbol, "H")
        XCTAssertEqual(pt.byAtomicNumber(118)?.symbol, "Og")
    }
}
