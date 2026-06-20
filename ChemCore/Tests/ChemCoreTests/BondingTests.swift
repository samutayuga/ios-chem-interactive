import XCTest
@testable import ChemCore

final class BondingTests: XCTestCase {
    func test_determineBonding() {
        XCTAssertEqual(determineBonding(.metal, .metal), .metallic)
        XCTAssertEqual(determineBonding(.nonMetal, .nonMetal), .covalent)
        XCTAssertEqual(determineBonding(.metalloid, .nonMetal), .covalent)
        XCTAssertEqual(determineBonding(.metalloid, .metalloid), .covalent)
        XCTAssertEqual(determineBonding(.metal, .nonMetal), .ionic)
        XCTAssertEqual(determineBonding(.metal, .metalloid), .ionic)
    }
    func test_polyatomicAlwaysIonic() {
        XCTAssertEqual(bondingType(aClass: .nonMetal, bClass: .nonMetal,
                                   aPolyatomic: true, bPolyatomic: false), .ionic)
        XCTAssertEqual(bondingType(aClass: .metal, bClass: .metal,
                                   aPolyatomic: false, bPolyatomic: true), .ionic)
        XCTAssertEqual(bondingType(aClass: .metal, bClass: .metal,
                                   aPolyatomic: false, bPolyatomic: false), .metallic)
    }
}
