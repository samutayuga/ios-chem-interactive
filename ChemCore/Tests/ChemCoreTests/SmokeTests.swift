import XCTest
@testable import ChemCore

final class SmokeTests: XCTestCase {
    func test_packageLoads() {
        XCTAssertEqual(chemCoreVersion, "0.1.0")
    }
}
