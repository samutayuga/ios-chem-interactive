import XCTest
@testable import ChemCore

final class DataPresenceTests: XCTestCase {
    func test_rawDataBundlesAll118() throws {
        let all = try RawElement.loadAll()
        XCTAssertEqual(all.count, 118)
        let fe = try XCTUnwrap(all.first { $0.symbol == "Fe" })
        XCTAssertEqual(fe.atomicNumber, 26)
        XCTAssertEqual(fe.massNumber, 56)
    }
}
