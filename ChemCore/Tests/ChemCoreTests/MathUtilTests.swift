import XCTest
@testable import ChemCore

final class MathUtilTests: XCTestCase {
    func test_gcd() {
        XCTAssertEqual(gcd(12, 8), 4)
        XCTAssertEqual(gcd(2, 2), 2)
        XCTAssertEqual(gcd(3, 1), 1)
        XCTAssertEqual(gcd(5, 0), 5)
        XCTAssertEqual(gcd(6, 4), 2)
    }
}
