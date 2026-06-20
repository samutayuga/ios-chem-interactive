import XCTest
@testable import ChemCore

final class ElectronConfigurationTests: XCTestCase {
    private func config(_ z: Int) throws -> String { try electronConfiguration(z).description }

    func test_hydrogenAndHelium() throws {
        XCTAssertEqual(try config(1), "1s1")
        XCTAssertEqual(try config(2), "1s2")
    }
    func test_ironStandardOrder() throws {
        XCTAssertEqual(try config(26), "1s2 2s2 2p6 3s2 3p6 3d6 4s2")
    }
    func test_neonFilled() throws {
        XCTAssertEqual(try config(10), "1s2 2s2 2p6")
    }
    func test_chromiumAnomaly() throws {
        XCTAssertEqual(try config(24), "1s2 2s2 2p6 3s2 3p6 3d5 4s1")
    }
    func test_copperAnomaly() throws {
        XCTAssertEqual(try config(29), "1s2 2s2 2p6 3s2 3p6 3d10 4s1")
    }
    func test_palladiumDrops5s() throws {
        XCTAssertEqual(try config(46), "1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10")
    }
    func test_lanthanumAnomaly() throws {
        XCTAssertEqual(try config(57), "1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 5d1 6s2")
    }
    func test_lawrenciumNaiveFill() throws {
        XCTAssertEqual(try config(103),
            "1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 4f14 5s2 5p6 5d10 5f14 6s2 6p6 6d1 7s2")
    }
    func test_oganessonFillsTo118() throws {
        let c = try electronConfiguration(118)
        XCTAssertEqual(c.orbitals.reduce(0) { $0 + $1.electrons }, 118)
        XCTAssertEqual(c.electrons(in: 7, .p), 6)
    }
    func test_unpairedElectrons_hundsRule() throws {
        XCTAssertEqual(try electronConfiguration(7).unpairedElectrons, 3)  // N: 2p3
        XCTAssertEqual(try electronConfiguration(10).unpairedElectrons, 0) // Ne
        XCTAssertEqual(try electronConfiguration(8).unpairedElectrons, 2)  // O
        XCTAssertEqual(try electronConfiguration(26).unpairedElectrons, 4) // Fe: 3d6
    }
    func test_invalidZ() {
        XCTAssertThrowsError(try electronConfiguration(0))
        XCTAssertThrowsError(try electronConfiguration(119))
    }
}
