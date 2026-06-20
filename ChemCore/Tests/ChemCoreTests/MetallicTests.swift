import XCTest
@testable import ChemCore

final class MetallicTests: XCTestCase {
    func test_electronCount() {
        XCTAssertEqual(metallicElectronCount(veA: 1, veB: 1), 6)   // 3 + 3
        XCTAssertEqual(metallicElectronCount(veA: 2, veB: 2), 12)  // 6 + 6
        XCTAssertEqual(metallicElectronCount(veA: 3, veB: 3), 12)  // 18 capped to 12
        XCTAssertEqual(metallicElectronCount(veA: 1, veB: 0), 3)
    }
}
