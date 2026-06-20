import XCTest
@testable import ChemCore

final class RawElementTests: XCTestCase {
    let json = """
    [{
      "atomic_number": 26, "name": "Iron", "symbol": "Fe",
      "atomic_mass": 55.845, "mass_number": 56,
      "melting_point": 1811.0, "boiling_point": 3134.0,
      "density": 7.874, "electronegativity": 1.83, "state": "Solid",
      "isotopes": [
        { "mass_number": 56, "relative_mass": 55.934936, "abundance": 0.91754 }
      ]
    }]
    """.data(using: .utf8)!

    func test_decodesRawElement() throws {
        let all = try RawElement.decodeAll(from: json)
        XCTAssertEqual(all.count, 1)
        let fe = all[0]
        XCTAssertEqual(fe.atomicNumber, 26)
        XCTAssertEqual(fe.symbol, "Fe")
        XCTAssertEqual(fe.atomicMass, 55.845, accuracy: 1e-6)
        XCTAssertEqual(fe.state, .solid)
        XCTAssertNil(fe.discoverer)
        XCTAssertEqual(fe.isotopes.first?.massNumber, 56)
    }
}
