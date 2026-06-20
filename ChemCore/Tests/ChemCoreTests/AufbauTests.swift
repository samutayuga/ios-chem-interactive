import XCTest
@testable import ChemCore

final class AufbauTests: XCTestCase {
    func test_subshellProperties() {
        XCTAssertEqual(Subshell.p.azimuthal, 1)
        XCTAssertEqual(Subshell.d.capacity, 10)
        XCTAssertEqual(Subshell.p.orbitalCount, 3)   // 2*1 + 1
        XCTAssertEqual(Subshell.f.label, "f")
    }

    func test_aufbauFill_hydrogenAndIron() {
        XCTAssertEqual(aufbauFill(1), [Orbital(n: 1, subshell: .s, electrons: 1)])
        // Fe (26) naive fill, in fill order: 1s2 2s2 2p6 3s2 3p6 4s2 3d6
        XCTAssertEqual(aufbauFill(26), [
            Orbital(n: 1, subshell: .s, electrons: 2),
            Orbital(n: 2, subshell: .s, electrons: 2),
            Orbital(n: 2, subshell: .p, electrons: 6),
            Orbital(n: 3, subshell: .s, electrons: 2),
            Orbital(n: 3, subshell: .p, electrons: 6),
            Orbital(n: 4, subshell: .s, electrons: 2),
            Orbital(n: 3, subshell: .d, electrons: 6),
        ])
    }

    func test_aufbauFill_total_oganesson() {
        XCTAssertEqual(aufbauFill(118).reduce(0) { $0 + $1.electrons }, 118)
    }

    func test_validate() {
        XCTAssertThrowsError(try validate(0)) { XCTAssertEqual($0 as? DomainError, .invalidAtomicNumber(0)) }
        XCTAssertThrowsError(try validate(119)) { XCTAssertEqual($0 as? DomainError, .invalidAtomicNumber(119)) }
        XCTAssertNoThrow(try validate(1))
        XCTAssertNoThrow(try validate(118))
    }
}
