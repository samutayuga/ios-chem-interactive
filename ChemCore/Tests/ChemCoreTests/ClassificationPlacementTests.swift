import XCTest
@testable import ChemCore

final class ClassificationPlacementTests: XCTestCase {
    func test_blocks() throws {
        XCTAssertEqual(try block(2), .s)   // He: naive last orbital is 1s
        XCTAssertEqual(try block(11), .s)  // Na
        XCTAssertEqual(try block(26), .d)  // Fe
        XCTAssertEqual(try block(9), .p)   // F
        XCTAssertEqual(try block(60), .f)  // Nd
    }
    func test_periods() throws {
        XCTAssertEqual(try period(1), 1)
        XCTAssertEqual(try period(11), 3)
        XCTAssertEqual(try period(26), 4)
        XCTAssertEqual(try period(46), 5)  // Pd keeps 5s in naive fill
        XCTAssertEqual(try period(60), 6)
    }
    func test_groups_mainBlock() throws {
        XCTAssertEqual(try group(1), 1)    // H
        XCTAssertEqual(try group(2), 18)   // He
        XCTAssertEqual(try group(3), 1)    // Li
        XCTAssertEqual(try group(4), 2)    // Be
        XCTAssertEqual(try group(8), 16)   // O
        XCTAssertEqual(try group(9), 17)   // F
        XCTAssertEqual(try group(10), 18)  // Ne
        XCTAssertEqual(try group(5), 13)   // B
    }
    func test_groups_transitionBlock() throws {
        XCTAssertEqual(try group(21), 3)   // Sc
        XCTAssertEqual(try group(26), 8)   // Fe
        XCTAssertEqual(try group(30), 12)  // Zn
        XCTAssertEqual(try group(24), 6)   // Cr (anomaly)
        XCTAssertEqual(try group(29), 11)  // Cu (anomaly)
        XCTAssertEqual(try group(46), 10)  // Pd (anomaly, 5s dropped)
    }
    func test_groups_fBlockConvention() throws {
        XCTAssertEqual(try group(60), 3)   // Nd
        XCTAssertEqual(try group(92), 3)   // U
    }
}
