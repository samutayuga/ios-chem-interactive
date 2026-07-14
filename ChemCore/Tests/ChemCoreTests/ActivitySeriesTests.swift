// ChemCore/Tests/ChemCoreTests/ActivitySeriesTests.swift
import XCTest
@testable import ChemCore

final class ActivitySeriesTests: XCTestCase {
    func test_metal_ordering() {
        XCTAssertLessThan(metalActivitySeries.firstIndex(of: "Zn")!,
                          metalActivitySeries.firstIndex(of: "Cu")!)
    }
    func test_zn_displaces_cu() {
        XCTAssertEqual(displaces("Zn", over: "Cu"), true)
    }
    func test_cu_does_not_displace_zn() {
        XCTAssertEqual(displaces("Cu", over: "Zn"), false)
    }
    func test_halogen_ordering() {
        XCTAssertEqual(displaces("Cl", over: "Br"), true)
        XCTAssertEqual(displaces("I", over: "Cl"), false)
    }
    func test_unrelated_pair_nil() {
        XCTAssertNil(displaces("Zn", over: "Cl"))
    }
    func test_same_element_false() {
        XCTAssertEqual(displaces("Zn", over: "Zn"), false)
    }
}
