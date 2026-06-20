import XCTest
import ChemCore
@testable import ChemInteractive

final class SmokeTests: XCTestCase {
    func test_chemCoreIsLinked() throws {
        // ChemCore is reachable from the test target and its bundled data loads.
        let pt = try PeriodicTable.load()
        XCTAssertEqual(pt.elements.count, 118)
    }
}
