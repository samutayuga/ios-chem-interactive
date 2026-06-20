import XCTest
@testable import ChemCore

final class CalcTests: XCTestCase {
    private let chlorine = [
        Isotope(massNumber: 35, relativeMass: 34.968853, abundance: 0.7576),
        Isotope(massNumber: 37, relativeMass: 36.965903, abundance: 0.2424),
    ]

    func test_weightedMassOfChlorine() {
        let mass = atomicMassFromIsotopes(chlorine)
        XCTAssertNotNil(mass)
        XCTAssertEqual(mass!, 35.45, accuracy: 0.01)
    }
    func test_noIsotopesYieldsNil() {
        XCTAssertNil(atomicMassFromIsotopes([]))
    }
    func test_zeroAbundanceYieldsNil() {
        XCTAssertNil(atomicMassFromIsotopes([Isotope(massNumber: 1, relativeMass: 1.0, abundance: 0.0)]))
    }
    func test_isotopeMatch() {
        XCTAssertTrue(isotopeMassMatches(storedMass: 35.45, isotopes: chlorine, tolerance: 0.01))
        XCTAssertFalse(isotopeMassMatches(storedMass: 35.45, isotopes: [], tolerance: 0.01))
    }
    func test_stateTransitions() {
        // Iron: mp 1811 K, bp 3134 K.
        XCTAssertEqual(stateAt(meltingPoint: 1811, boilingPoint: 3134, temperatureK: 300), .solid)
        XCTAssertEqual(stateAt(meltingPoint: 1811, boilingPoint: 3134, temperatureK: 2000), .liquid)
        XCTAssertEqual(stateAt(meltingPoint: 1811, boilingPoint: 3134, temperatureK: 4000), .gas)
        XCTAssertNil(stateAt(meltingPoint: nil, boilingPoint: nil, temperatureK: 300))
    }
}
