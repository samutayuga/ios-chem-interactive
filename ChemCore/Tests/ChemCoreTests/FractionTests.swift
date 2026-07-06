// ChemCore/Tests/ChemCoreTests/FractionTests.swift
import XCTest
@testable import ChemCore

final class FractionTests: XCTestCase {
    func test_reduces_on_init() {
        let f = Fraction(4, 8)
        XCTAssertEqual(f.num, 1)
        XCTAssertEqual(f.den, 2)
    }
    func test_normalizes_sign_to_numerator() {
        let f = Fraction(1, -2)
        XCTAssertEqual(f.num, -1)
        XCTAssertEqual(f.den, 2)
    }
    func test_addition() {
        XCTAssertEqual(Fraction(1, 2) + Fraction(1, 3), Fraction(5, 6))
    }
    func test_multiplication() {
        XCTAssertEqual(Fraction(2, 3) * Fraction(3, 4), Fraction(1, 2))
    }
    func test_isZero() {
        XCTAssertTrue(Fraction(0, 5).isZero)
        XCTAssertFalse(Fraction(1, 5).isZero)
    }
}
