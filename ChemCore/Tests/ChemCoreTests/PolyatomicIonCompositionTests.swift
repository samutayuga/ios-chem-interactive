// ChemCore/Tests/ChemCoreTests/PolyatomicIonCompositionTests.swift
import XCTest
@testable import ChemCore

final class PolyatomicIonCompositionTests: XCTestCase {
    private func ion(_ symbol: String) -> PolyatomicIon {
        PolyatomicIon.polyatomicIons.first { $0.symbol == symbol }!
    }
    func test_hydroxide() { XCTAssertEqual(ion("OH").composition, ["O": 1, "H": 1]) }
    func test_sulfate()   { XCTAssertEqual(ion("SO₄").composition, ["S": 1, "O": 4]) }
    func test_nitrate()   { XCTAssertEqual(ion("NO₃").composition, ["N": 1, "O": 3]) }
    func test_carbonate() { XCTAssertEqual(ion("CO₃").composition, ["C": 1, "O": 3]) }
    func test_phosphate() { XCTAssertEqual(ion("PO₄").composition, ["P": 1, "O": 4]) }
    func test_ammonium()  { XCTAssertEqual(ion("NH₄").composition, ["N": 1, "H": 4]) }
    func test_zoneState_still_builds() {
        let z = ZoneState(polyatomic: ion("SO₄"))
        XCTAssertEqual(z.symbol, "SO₄")
    }
}
